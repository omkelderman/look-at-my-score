gm = require 'gm'
fs = require 'fs'
path = require 'path'
RedisCache = require './RedisCache'
config = require 'config'
PathConstants = require './PathConstants'
{logger} = require './Logger'
{ v4: uuidV4 } = require 'uuid'
OsuScoreBadgeCreator = require './OsuScoreBadgeCreator'
Util = require './Util'
HttpRequester = require './HttpRequester'
COVER_REQUESTER = new HttpRequester 'https://assets.ppy.sh/beatmaps/%s/covers/cover.jpg', config.get('osu-api.timeout')

CACHE_TIME = config.get 'cacheTimes.get_beatmaps'
COVER_CACHE_DIR = PathConstants.coverCacheDir

DEFAULT_COVER = path.resolve PathConstants.inputDir, 'defaultCover.jpg'

# yay for useless micro-optimizations xD
downloadBusyLists = {}

grabCoverFromOsuServer = (beatmapSetId, done) ->
    # return default on falsy values
    return done null, DEFAULT_COVER if not beatmapSetId

    # if proccess is already started for same id, dont start again, but listen for result
    if downloadBusyLists[beatmapSetId]
        return downloadBusyLists[beatmapSetId].push done

    # start process for this id
    downloadBusyLists[beatmapSetId] = [done]

    # define new "done" handler, since it now has to handle all the entries in the list
    done = (err, result) ->
        # we done, remove it from the lists-object
        handles = downloadBusyLists[beatmapSetId]
        delete downloadBusyLists[beatmapSetId]
        # execute them all
        handle err, result for handle in handles

    cacheKey = 'coverCache:' + beatmapSetId
    await RedisCache.get cacheKey, defer isInCache, cachedResult
    if isInCache # yay cache exists
        if cachedResult
            return done null, cachedResult
        else
            return done null, DEFAULT_COVER

    # cache didnt exist, lets get it
    localLocation = path.resolve COVER_CACHE_DIR, beatmapSetId + '.jpg'
    await COVER_REQUESTER.saveFile [beatmapSetId], localLocation, defer err, success, url
    return done err if err

    if not success
        # not found, use default
        done null, DEFAULT_COVER

        # and store 'null' in cache, which causes default to be used
        RedisCache.storeInCache CACHE_TIME, cacheKey, null

        # also for statistics, notify me so I can build a list of missing cover.jpgs
        # lets abuse logger.error, its not really an error, app will just work fine
        # bug with logger.error I get a direct message :D
        logger.error {beatmapSetId: beatmapSetId, url: url}, 'beatmap cover.jpg does not exist on osu server'
        return

    await Util.checkImageSize localLocation, OsuScoreBadgeCreator.IMAGE_WIDTH, OsuScoreBadgeCreator.IMAGE_HEIGHT, defer err, sizeOk
    return cb err if err
    if not sizeOk
        return done new Error('The cover.jpg from osu! servers has an unexpected size')

    # all gud, lets give it back right now, no need to wait for redis right
    done null, localLocation

    # also store it in cache
    RedisCache.storeInCache CACHE_TIME, cacheKey, localLocation

saveCustomCoverImg = (base64str, cb) ->
    data = Buffer.from(base64str, 'base64')

    await gm(data).identify defer err, imageData
    return cb err if err

    if imageData.format isnt 'JPEG' or imageData.Geometry isnt '900x250'
        return cb null, null

    imageId = uuidV4()
    filepath = path.resolve COVER_CACHE_DIR, imageId
    await fs.writeFile filepath, data, defer err
    return cb err if err
    return cb null, filepath

module.exports =
    grabCoverFromOsuServer: grabCoverFromOsuServer
    saveCustomCoverImg: saveCustomCoverImg
