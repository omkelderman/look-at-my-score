REDIS_CLIENT = null

initStuff = (redisClient) ->
    REDIS_CLIENT = redisClient

logStoreInCacheError = (key, result, err) ->
    console.error 'Error while storing value', key, result, err

logGetFromCacheError = (err) ->
    console.error 'Error while retrieving value', err

storeInCache = (expire, key, value) ->
    if expire and expire > 0 # discard negative and non-existing expire values
        console.log 'SETEX', expire, key
        value = JSON.stringify value
        REDIS_CLIENT.setex key, expire, value, (err, result) ->
            logStoreInCacheError key, result, err if err or result isnt 'OK'

    # else dont store anything, its a cache, so dont want to have things that stay forever

# redis shouldnt be throwing errors, so on error, never pass it on, just log it and return as if value wasnt in cache
# return a boolean if value was from cache or not, to differentiate between null-values in cache and non-existing cache values
get = (key, done) -> REDIS_CLIENT.get key, (err, result) ->
    if err
        logGetFromCacheError err
        return done false # error, so not in cache

    return done false, null if result is null # value not in cache

    try
        return done true, JSON.parse result # value in cache
    catch ex
        logGetFromCacheError ex
        return done false # error, so not in cache

createCacheKeyFromObject = (obj) ->
    Object.keys obj
        .sort()
        .map (key) -> key + '=' + obj[key]
        .join '&'

module.exports =
    init: initStuff
    storeInCache: storeInCache
    get: get
    createCacheKeyFromObject: createCacheKeyFromObject
