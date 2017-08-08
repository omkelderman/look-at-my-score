express = require 'express'
bodyParser = require 'body-parser'
fs = require 'fs'
path = require 'path'
logger = require 'morgan'
killable = require 'killable'
config = require 'config'
redis = require 'redis'
RedisCache = require './RedisCache'
PathConstants = require './PathConstants'

# ensure data-dir/coverCache-dir exists
fs.mkdirSync PathConstants.dataDir if not fs.existsSync PathConstants.dataDir
fs.mkdirSync PathConstants.coverCacheDir if not fs.existsSync PathConstants.coverCacheDir
fs.mkdirSync PathConstants.tmpDir if not fs.existsSync PathConstants.tmpDir

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

# setup routes
ROUTE_MOUNTS =
    api: '/api'
    main: '/'

console.log 'Loading routes...'
ROUTES = {}
for routeName, routeMount of ROUTE_MOUNTS
    console.log "\tLoading route '#{routeName}'"
    ROUTES[routeName] = require path.resolve PathConstants.routesDir, "#{routeName}.iced"
console.log 'Done loading routes'

app = express()
app.enable 'trust proxy'
app.set 'views', PathConstants.viewsDir
app.set 'view engine', 'pug'

app.use express.static PathConstants.staticDir
app.use '/score', express.static PathConstants.dataDir
app.use logger 'dev'

app.use bodyParser.urlencoded extended:true
app.use bodyParser.json()

# actual content
for routeName, routeMount of ROUTE_MOUNTS
    app.use routeMount, ROUTES[routeName]

app.use (req, res, next) ->
    next
        message: 'Not Found'
        status: 404
        detail: "Page \"#{req.originalUrl}\" could not be found on this server :("

app.use (err, req, res, next) ->
    res.status err.status || 500
    res.render 'error',
        message: err.message,
        status: err.status,
        detailMessage: err.detail || err.stack


# start the server
await
    if PathConstants.socket
        server = app.listen PathConstants.socket, defer()
    else
        server = app.listen config.get('http.listen'), config.get('http.host'), defer()
httpListen = server.address()
killable server

# set socket chmod if applicable
if PathConstants.socket
    socketChmod = config.get 'http.socketChmod'
    fs.chmodSync PathConstants.socket, socketChmod if socketChmod

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
