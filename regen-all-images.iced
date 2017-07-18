config = require 'config'
redis = require 'redis'
fs = require 'fs'
path = require 'path'

OsuScoreBadgeCreator = require './OsuScoreBadgeCreator'
RedisCache = require './RedisCache'
CoverCache = require './CoverCache'

# TODO: keep these in a different file
# constants
paths =
    dataDir : path.resolve 'data'
    bakDir : path.resolve 'bak'
    coverCacheDir : path.resolve 'coverCache'
    inputDir : path.resolve 'input'
    socket : path.resolve '../http.sock'
    routesDir : path.resolve 'routes'
    viewsDir : path.resolve 'views'
    staticDir : path.resolve 'public'

# ensure data-dir/coverCache-dir exists
fs.mkdirSync paths.dataDir if not fs.existsSync paths.dataDir
fs.mkdirSync paths.coverCacheDir if not fs.existsSync paths.coverCacheDir
fs.mkdirSync paths.bakDir if not fs.existsSync paths.bakDir

# redis
redisConfig = config.get 'redis'
redisSettings =
    db: redisConfig.db
    prefix: redisConfig.prefix+':'
if redisConfig.path
    redisSettings.path = redisConfig.path
else
    redisSettings.host = redisConfig.host
    redisSettings.port = redisConfig.port
redisClient = redis.createClient redisSettings

# init the things
RedisCache.init redisClient
CoverCache.init paths.coverCacheDir
await OsuScoreBadgeCreator.init paths.inputDir, paths.dataDir, defer err
return throw err if err

console.log 'BOOM'
# DO THE things
await fs.readdir paths.dataDir, defer err, files
return done err if err
images = files
    .filter (file) -> file[-4..] is '.png'
    .map (file) -> file[..-5]

doOneImage = (id, cb) ->
    console.log "[#{id}] starting..."
    try
        json = require path.resolve paths.dataDir, id + '.json'
    catch err
        console.error '['+id+'] NOPE could not get json'
        return cb()

    # grab the new.ppy.sh cover of the beatmap to start with
    await CoverCache.grab json.beatmap.beatmapset_id, defer err, coverJpg
    if err
        console.error '['+id+'] NOPE could not get cover'
        return cb()

    oldPngPath = path.resolve paths.dataDir, id + '.png'
    bakPngPath = path.resolve paths.bakDir, id + '.png'
    await OsuScoreBadgeCreator.create coverJpg, json.beatmap, json.mode, json.score, defer err, imageId
    if err
        console.error '['+id+'] NOPE could not gen imgage'
        return cb()

    newPngPath = path.resolve paths.dataDir, imageId + '.png'
    newJsonPath = path.resolve paths.dataDir, imageId + '.json'
    await fs.unlink newJsonPath, defer err
    if err
        console.error '['+id+'] NOPE error while removing "new" json'
        cb()
    await fs.rename oldPngPath, bakPngPath, defer err
    if err
        console.error '['+id+'] NOPE error while renaming old to bak'
        cb()
    await fs.rename newPngPath, oldPngPath, defer err
    if err
        console.error '['+id+'] NOPE error while renaming new to old'
        cb()


    console.log "[#{id}] done!"
    cb()

console.log "found #{images.length} images"
for id in images
    await doOneImage id, defer err
    # console.log 'yay + ' + id if not err


console.log 'Shutting down...'
# close redis connection
await
    redisClient.once 'end', defer()
    redisClient.quit()

# THE END :D
console.log "process with pid #{process.pid} ended gracefully :D"
