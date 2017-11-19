request = require 'request'
RedisCache = require './RedisCache'
config = require 'config'

CACHE_TIMES = config.get 'cacheTimes'

buildCacheKey = (endpoint, params) -> 'api:' + endpoint + ':' + RedisCache.createCacheKeyFromObject params

doApiRequest = (endpoint, params, done, customCacheAction) -> doApiRequestModifyResult endpoint, params, null, done, customCacheAction
doApiRequestModifyResult = (endpoint, params, modifyResultHandler, done, customCacheAction) ->
    cacheKey = buildCacheKey endpoint, params
    await RedisCache.get cacheKey, defer isInCache, cachedResult
    if isInCache # yay cache exists
        modifyResultHandler cachedResult, true if modifyResultHandler
        return done null, cachedResult

    # cache didnt exist, lets get it
    url = 'https://osu.ppy.sh/api/' + endpoint
    params.k = config.get 'osu-api.key'
    await request {url:url, qs:params, json:true, gzip:true, timeout:config.get('osu-api.timeout')}, defer err, resp, body
    return done err if err
    if resp.statusCode != 200
        return done
            message: 'osu api error'
            detail: "osu api did not respond with http 200 OK response (was #{resp.statusCode})"
    if not body
        return done
            message: 'osu api error'
            detail: 'osu api response was invalid'

    modifyResultHandler body, false if modifyResultHandler

    # all gud, lets give it back right now, no need to wait for redis right
    done null, body

    # if customCacheAction, caller is responsible for storing the value in cache
    if customCacheAction
        delete params.k
        customCacheAction body, params, (forgedParams, forgedValue) ->
            forgedKey = buildCacheKey endpoint, forgedParams
            RedisCache.storeInCache CACHE_TIMES[endpoint], forgedKey, forgedValue
    else
        RedisCache.storeInCache CACHE_TIMES[endpoint], cacheKey, body

doApiRequestAndGetFirst = (endpoint, params, done, customCacheAction) ->
    doApiRequest endpoint, params
    , (err, result) ->
        return done err if err
        return done null, null if result is null
        done null, result[0]
    , customCacheAction

saveCustomCacheForBeatmapObject = (b, saveCallback) ->
    saveCallback {b:b.beatmap_id, m:b.mode, a:1}, [b]
    saveCallback {h:b.file_md5, m:b.mode, a:1}, [b]
    saveCallback {b:b.beatmap_id, a:1}, [b]
    saveCallback {h:b.file_md5, a:1}, [b]

customCacheActionForGetBeatmap = (value, originalParams, saveCallback) ->
    if value.length is 0
        # empty response, just store, nothing special to do
        return saveCallback originalParams, value

    b = value[0]
    if originalParams.hasOwnProperty 'm'
        # mode was supplied, store with supplied mode for hash and id
        saveCallback {b:b.beatmap_id, m:originalParams.m, a:1}, value
        saveCallback {h:b.file_md5, m:originalParams.m, a:1}, value

        # if not a convert, store also without mode supplied
        if `originalParams.m == b.mode`
            saveCallback {b:b.beatmap_id, a:1}, value
            saveCallback {h:b.file_md5, a:1}, value
    else
        # mode was not supplied, store all 4 variants (with and without mode, id and hash)
        saveCustomCacheForBeatmapObject b, saveCallback

module.exports.getBeatmap = (id, mode, done) ->
    options =
        b:id
        a:1
    if mode?
        options.m = mode
    doApiRequestAndGetFirst 'get_beatmaps', options, done, customCacheActionForGetBeatmap

module.exports.getBeatmapByHash = (hash, mode, done) ->
    options =
        h:hash
        a:1
    if mode?
        options.m = mode
    doApiRequestAndGetFirst 'get_beatmaps', options, done, customCacheActionForGetBeatmap

module.exports.getBeatmapSet = (id, done) ->
    doApiRequest 'get_beatmaps', {s:id}, done, (value, originalParams, saveCallback) ->
        # we are now responsible for storing the valuy in cache
        saveCallback originalParams, value

        # create forged cache entries for each diff as if a per-diff-api call was done
        saveCustomCacheForBeatmapObject b, saveCallback for b in value

setDateObjectInResultList = (resultList, isFromCache) ->
    for result in resultList
        if result.date
            if isFromCache
                # from cache, is stored as a ISO string
                result.date = new Date result.date
            else
                # from api, is a mysql date string in +8 timezone
                result.date = new Date result.date.replace(' ', 'T')+'+08:00'

module.exports.getScores = (beatmapId, mode, username, done) ->
    doApiRequestModifyResult 'get_scores', {b:beatmapId, m:mode, u:username, type:'string'}, setDateObjectInResultList, done

module.exports.getRecentScores = (mode, username, done) ->
    doApiRequestModifyResult 'get_user_recent', {m:mode, u:username, type:'string', limit:50}, setDateObjectInResultList, done
