REDIS_CLIENT = null

initStuff = (redisClient) ->
    REDIS_CLIENT = redisClient

generalStoreInCacheResultHandler = (key) ->
    return (err, result) -> console.error 'welp, error while setting redis key', key if err or result isnt 'OK'

storeInCache = (expire, key, value, done) ->
    done = generalStoreInCacheResultHandler(key) if not done
    if expire and expire > 0 # discard negative and non-existing expire values
        console.log 'SETEX', expire, key
        value = JSON.stringify value
        REDIS_CLIENT.setex key, expire, value, done

    # else dont store anything, its a cache, so dont want to have things that stay forever

get = (key, done) -> REDIS_CLIENT.get key, (err, result) ->
    return done err if err
    return done null, null if result is null
    try
        return done null, JSON.parse result
    catch ex
        return done ex

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
