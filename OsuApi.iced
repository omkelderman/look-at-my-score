request = require 'request'
RedisCache = require './RedisCache'

CACHE_TIMES =
    get_beatmaps: 60*60*24 # 24 hour
    get_scores:   60*5     # 5 min

API_KEY = require('config').get 'osu-api-key'

buildCacheKey = (endpoint, params) -> 'api:' + endpoint + ':' + RedisCache.createCacheKeyFromObject params

doApiRequest = (endpoint, params, done) ->
    cacheKey = buildCacheKey endpoint, params
    await RedisCache.get cacheKey, defer err, cachedResult
    return done err if err
    return done null, JSON.parse(cachedResult), true if cachedResult # yay cache exists

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
    RedisCache.storeInCache CACHE_TIMES[endpoint], cacheKey, JSON.stringify(body)

doApiRequestAndGetFirst = (endpoint, params, done) ->
    await doApiRequest endpoint, params, defer err, result
    return done err if err
    return done null, null if result is null
    done null, result[0]

module.exports.getBeatmap = getBeatmap = (id, mode, done) ->
    doApiRequestAndGetFirst 'get_beatmaps', {b:id, m:mode, a:1}, done

module.exports.getBeatmapSet = getBeatmapSet = (id, done) ->
    doApiRequest 'get_beatmaps', {s:id}, (err, result, isCached) ->
        done err, result

        if not isCached and not err and result isnt null
            # create forged cache entries for each diff as if a per-diff-api call was done
            # we have the data so why not, can potentially be less api calls made :D
            for b in result
                forgedCacheKey = buildCacheKey 'get_beatmaps', {b:b.beatmap_id, m:b.mode, a:1}
                RedisCache.storeInCache CACHE_TIMES['get_beatmaps'], forgedCacheKey, JSON.stringify([b])

module.exports.getScores = getScores = (beatmapId, mode, username, done) ->
    doApiRequest 'get_scores', {b:beatmapId, m:mode, u:username, type:'string'}, done
