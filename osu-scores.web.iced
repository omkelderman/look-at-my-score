express = require 'express'
bodyParser = require 'body-parser'
fs = require 'fs'
path = require 'path'
logger = require 'morgan'
killable = require 'killable'
config = require 'config'
redis = require 'redis'
OsuScoreBadgeCreator = require './OsuScoreBadgeCreator'
OsuApi = require './OsuApi'
RedisCache = require './RedisCache'

# constants
paths =
    dataDir : path.resolve 'data'
    inputDir : path.resolve 'input'
    socket : path.resolve '../http.sock'
    routesDir : path.resolve 'routes'
    viewsDir : path.resolve 'views'
    staticDir : path.resolve 'public'

USE_UNIX_SOCKET = config.get('http.listen') is 'unix-socket'

# ensure data-dir exists
fs.mkdirSync paths.dataDir if not fs.existsSync paths.dataDir

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
await OsuScoreBadgeCreator.init paths.inputDir, paths.dataDir, defer err
return throw err if err
OsuApi.init config.get('osu-api-key')

# setup routes
ROUTE_MOUNTS =
    api: '/api'
    main: '/'

console.log 'Loading routes...'
ROUTES = {}
for routeName, routeMount of ROUTE_MOUNTS
    console.log "\tLoading route '#{routeName}'"
    ROUTES[routeName] = require path.resolve paths.routesDir, "#{routeName}.iced"
console.log 'Done loading routes'

app = express()
app.enable 'trust proxy'
app.set 'views', paths.viewsDir
app.set 'view engine', 'pug'

app.use express.static paths.staticDir
app.use '/score', express.static paths.dataDir
app.use logger 'dev'

app.use bodyParser.urlencoded extended:true
app.use bodyParser.json()

# actual content
for routeName, routeMount of ROUTE_MOUNTS
    app.use routeMount, ROUTES[routeName]

app.use (req, res, next) ->
    err = new Error 'Not Found'
    err.status = 404
    err.detail = "Page \"#{req.originalUrl}\" could not be found on this server :("
    next(err)

app.use (err, req, res, next) ->
    res.status err.status || 500
    res.render 'error',
        message: err.message,
        status: err.status,
        detailMessage: err.detail || err.stack


# start the server
await
    if USE_UNIX_SOCKET
        server = app.listen paths.socket, defer()
    else
        server = app.listen config.get('http.listen'), config.get('http.host'), defer()
httpListen = server.address()
if USE_UNIX_SOCKET
    # set socket perm, otherwise webserver cant do anything with it
    fs.chmodSync paths.socket, '666'
killable server
console.log 'Server running on ', httpListen

# on both SIGINT and SIGTERM start shutting down gracefully
process.on 'SIGTERM', -> process.emit 'requestShutdown'
process.on 'SIGINT', -> process.emit 'requestShutdown'
await process.once 'requestShutdown', defer()
console.log 'Shutting down...'
process.on 'requestShutdown', -> console.warn "process #{process.pid} already shutting down..."

# stop http-server
await server.kill defer err
if err
    console.error 'Error while closing HTTP server', err
else
    console.log 'HTTP server has been closed'

# close redis connection
await
    redisClient.once 'end', defer()
    redisClient.quit()

# THE END :D
console.log "process with pid #{process.pid} ended gracefully :D"
