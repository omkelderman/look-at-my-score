{logger} = require './Logger'

config = require 'config'
redis = require 'redis'

REDIS_CLIENT = null
REDIS_PREFIX = null

init = (cb) ->
    redisConfig = config.get 'redis'
    if not redisConfig
        logger.warn 'No redis config found, so not using redis'
        return cb null
    
    redisSettings =
        legacyMode: true
        database: redisConfig.db
        socket:
            if redisConfig.path
                path: redisConfig.path
            else
                host: redisConfig.host
                port: redisConfig.port
    
    # welp since v4 redis client doesnt support prefixing anymore, so we have to do it ourselves
    # or at least I havent found out how
    REDIS_PREFIX = redisConfig.prefix

    logger.info 'Connecting to redis...'
    client = redis.createClient redisSettings
    await connectRedisClient client, defer err
    return cb err if err

    logger.info 'Redis connection established'
    REDIS_CLIENT = client
    cb null

connectRedisClient = (client, cb) ->
    yep = () -> cb null
    nope = (err) -> cb err
    client.connect().then yep, nope

close = (cb) ->
    return cb null if not REDIS_CLIENT

    if REDIS_CLIENT.isOpen
        logger.info 'Closing redis connection...'
        await
            REDIS_CLIENT.once 'end', defer()
            REDIS_CLIENT.disconnect()
        logger.info 'Redis connection closed'
    else
        logger.info 'Redis connection already closed'
    cb null

logStoreInCacheError = (key, result, err) ->
    logger.error {err: err, key: key, result: result}, 'Error while storing value'

logGetFromCacheError = (err) ->
    logger.error {err: err}, 'Error while retrieving value'

storeInCache = (expire, key, value) ->
    return if not REDIS_CLIENT
    if expire and expire > 0 # discard negative and non-existing expire values
        logger.debug {expire: expire, key: key}, 'SETEX'
        value = JSON.stringify value
        REDIS_CLIENT.setex prefixKey(key), expire, value, (err, result) ->
            logStoreInCacheError key, result, err if err or result isnt 'OK'

    # else dont store anything, its a cache, so dont want to have things that stay forever

# redis shouldnt be throwing errors, so on error, never pass it on, just log it and return as if value wasnt in cache
# return a boolean if value was from cache or not, to differentiate between null-values in cache and non-existing cache values
get = (key, done) ->
    return done false, null if not REDIS_CLIENT
    REDIS_CLIENT.get prefixKey(key), (err, result) ->
        if err
            logGetFromCacheError err
            return done false # error, so not in cache

        return done false, null if result is null # value not in cache

        try
            return done true, JSON.parse result # value in cache
        catch ex
            logGetFromCacheError ex
            return done false # error, so not in cache

prefixKey = (key) -> if REDIS_PREFIX then "#{REDIS_PREFIX}:#{key}" else key

createCacheKeyFromObject = (obj) ->
    Object.keys obj
        .sort()
        .map (key) -> encodeURIComponent(key) + '=' + encodeURIComponent(obj[key])
        .join '&'

module.exports =
    init: init
    storeInCache: storeInCache
    get: get
    createCacheKeyFromObject: createCacheKeyFromObject
    close: close