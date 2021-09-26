request = require 'request'
RedisCache = require './RedisCache'
config = require 'config'
Util = require './Util'
RateLimiter = require('limiter').RateLimiter
{logger} = require './Logger'

CACHE_TIMES = config.get 'cacheTimes'
LIMITER = new RateLimiter(config.get('osu-api.rateLimit'))

VALID_MODS_FOR_DIFF_VALUES = 2|16|64|256|32768|65536|131072|262144|524288|16777216 # EZ + HR + DT + HT + K4 + K5 + K6 + K7 + K8 + K9
filterModsForApi = (mods) -> mods & VALID_MODS_FOR_DIFF_VALUES

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
    logger.debug {url: url, params: params}, 'osu api request'
    params.k = config.get 'osu-api.key'
    await LIMITER.removeTokens(1).then(defer())
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

saveCustomCacheForBeatmapObject = (b, mods, saveCallback) ->
    saveCallback {b:b.beatmap_id, m:b.mode, a:1, mods:mods}, [b]
    saveCallback {h:b.file_md5, m:b.mode, a:1, mods:mods}, [b]
    saveCallback {b:b.beatmap_id, a:1, mods:mods}, [b]
    saveCallback {h:b.file_md5, a:1, mods:mods}, [b]

customCacheActionForGetBeatmap = (value, originalParams, saveCallback) ->
    if value.length is 0
        # empty response, just store, nothing special to do
        return saveCallback originalParams, value

    b = value[0]
    mods = originalParams.mods
    if originalParams.hasOwnProperty 'm'
        # mode was supplied, store with supplied mode for hash and id
        saveCallback {b:b.beatmap_id, m:originalParams.m, a:1, mods:mods}, value
        saveCallback {h:b.file_md5, m:originalParams.m, a:1, mods:mods}, value

        # if not a convert, store also without mode supplied
        if `originalParams.m == b.mode`
            saveCallback {b:b.beatmap_id, a:1, mods:mods}, value
            saveCallback {h:b.file_md5, a:1, mods:mods}, value
    else
        # mode was not supplied, store all 4 variants (with and without mode, id and hash)
        saveCustomCacheForBeatmapObject b, mods, saveCallback

module.exports.getBeatmap = (id, mode, mods, done) ->
    options =
        b:id
        a:1
        mods: filterModsForApi mods
    if mode?
        options.m = mode
    doApiRequestAndGetFirst 'get_beatmaps', options, done, customCacheActionForGetBeatmap

module.exports.getBeatmapByHash = (hash, mode, mods, done) ->
    options =
        h:hash
        a:1
        mods: filterModsForApi mods
    if mode?
        options.m = mode
    doApiRequestAndGetFirst 'get_beatmaps', options, done, customCacheActionForGetBeatmap

module.exports.getBeatmapSet = (id, done) ->
    doApiRequest 'get_beatmaps', {s:id, mods:0}, done, (value, originalParams, saveCallback) ->
        # we are now responsible for storing the valuy in cache
        saveCallback originalParams, value

        # create forged cache entries for each diff as if a per-diff-api call was done
        saveCustomCacheForBeatmapObject b, 0, saveCallback for b in value

setDateObjectInResultList = (resultList, isFromCache) ->
    for result in resultList
        if result.date
            result.date = Util.convertDateStringToDateObject result.date

module.exports.getScores = (beatmapId, mode, username, done) ->
    doApiRequestModifyResult 'get_scores', {b:beatmapId, m:mode, u:username, type:'string'}, setDateObjectInResultList, done

module.exports.getRecentScores = (mode, username, done) ->
    doApiRequestModifyResult 'get_user_recent', {m:mode, u:username, type:'string', limit:50}, setDateObjectInResultList, done
