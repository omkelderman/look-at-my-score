request = require 'request'
RedisCache = require './RedisCache'

CACHE_TIMES =
    get_beatmaps: 60*60*24 # 24 hour
    get_scores:   60*5     # 5 min

API_KEY = null

initStuff = (key) ->
    API_KEY = key

doApiRequest = (endpoint, params, done) ->
    cacheKey = 'api:' + endpoint + ':' + RedisCache.createCacheKeyFromObject params
    await RedisCache.get cacheKey, defer err, cachedResult
    return done err if err
    return done null, JSON.parse cachedResult if cachedResult # yay cache exists

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

getBeatmap = (id, mode, done) ->
    doApiRequestAndGetFirst 'get_beatmaps', {b:id, m:mode, a:1}, done

getScores = (beatmapId, mode, username, done) ->
    doApiRequest 'get_scores', {b:beatmapId, m:mode, u:username, type:'string'}, done

module.exports =
    init: initStuff
    getBeatmap: getBeatmap
    getScores: getScores
