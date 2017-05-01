request = require 'request'
RedisCache = require './RedisCache'
config = require 'config'

CACHE_TIMES = config.get 'cacheTimes'
API_KEY = config.get 'osu-api-key'

buildCacheKey = (endpoint, params) -> 'api:' + endpoint + ':' + RedisCache.createCacheKeyFromObject params

doApiRequest = (endpoint, params, done, extraCacheAction) ->
    cacheKey = buildCacheKey endpoint, params
    await RedisCache.get cacheKey, defer err, cachedResult
    return done err if err
    return done null, cachedResult if cachedResult # yay cache exists

    # cache didnt exist, lets get it
    url = 'https://osu.ppy.sh/api/' + endpoint
    params.k = API_KEY
    await request {url:url, qs:params, json:true, gzip:true}, defer err, resp, body
    return done err if err
    if resp.statusCode != 200
        console.error 'error api call to', url
        return done new Error 'no 200 response'

    # all gud, lets give it back right now, no need to wait for redis right
    done null, body

    # also store it in cache
    RedisCache.storeInCache CACHE_TIMES[endpoint], cacheKey, body

    if extraCacheAction and body isnt null
        extraCacheAction body, (forgedParams, forgedValue) ->
            forgedKey = buildCacheKey endpoint, forgedParams
            RedisCache.storeInCache CACHE_TIMES[endpoint], forgedKey, forgedValue

doApiRequestAndGetFirst = (endpoint, params, done, extraCacheAction) ->
    doApiRequest endpoint, params
    , (err, result) ->
        return done err if err
        return done null, null if result is null
        done null, result[0]
    , extraCacheAction

module.exports.getBeatmap = getBeatmap = (id, mode, done) ->
    doApiRequestAndGetFirst 'get_beatmaps', {b:id, m:mode, a:1}, done, (value, saveCallback) ->
        return if value.length != 1
        # create forged cache entry with same value, but with the hash as param
        saveCallback {h:value[0].file_md5, m:mode, a:1}, value

module.exports.getBeatmapByHash = getBeatmap = (hash, mode, done) ->
    doApiRequestAndGetFirst 'get_beatmaps', {h:hash, m:mode, a:1}, done, (value, saveCallback) ->
        return if value.length != 1
        # create forged cache entry with same value, but with the beatmap-id as param
        saveCallback {b:value[0].beatmap_id, m:mode, a:1}, value

module.exports.getBeatmapSet = getBeatmapSet = (id, done) ->
    doApiRequest 'get_beatmaps', {s:id}, done, (value, saveCallback) ->
        # create forged cache entries for each diff as if a per-diff-api call was done
        # we have the data so why not, can potentially be less api calls made :D
        for b in value
            saveCallback {b:b.beatmap_id, m:b.mode, a:1}, [b]
            saveCallback {h:b.file_md5, m:b.mode, a:1}, [b]


module.exports.getScores = getScores = (beatmapId, mode, username, done) ->
    doApiRequest 'get_scores', {b:beatmapId, m:mode, u:username, type:'string'}, done
