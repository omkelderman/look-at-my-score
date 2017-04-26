request = require 'request'
gm = require 'gm'
fs = require 'fs'
RedisCache = require './RedisCache'
config = require 'config'

CACHE_TIME = config.get 'cacheTimes.get_beatmaps'
COVER_CACHE_DIR = null

initStuf = (coverCacheDir) ->
    COVER_CACHE_DIR = coverCacheDir

doThatThing = (beatmapSetId, done) ->
    cacheKey = 'coverCache:' + beatmapSetId
    await RedisCache.get cacheKey, defer err, cachedResult
    return done err if err
    return done null, cachedResult if cachedResult # yay cache exists

    # cache didnt exist, lets get it
    url = "https://assets.ppy.sh/beatmaps/#{beatmapSetId}/covers/cover.jpg"
    localLocation = "#{COVER_CACHE_DIR}/#{beatmapSetId}.jpg"

    req = request.get url
    await req.once 'response', defer res
    if res.statusCode is 200
        await req.pipe(fs.createWriteStream(localLocation)).once 'finish', defer()
    else
        await gm(900, 250, '#000').write localLocation, defer err
        return done err if err

    # all gud, lets give it back right now, no need to wait for redis right
    done null, localLocation

    # also store it in cache
    RedisCache.storeInCache CACHE_TIME, cacheKey, localLocation


module.exports =
    grab: doThatThing
    init: initStuf
