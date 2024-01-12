logWhyRunning = require 'why-is-node-running'
# NodeJS Version Check
semver = require 'semver'
NODE_VERSION_TO_RUN = '^20.11.0'
throw new Error("The current node version #{process.version} does not satisfy the required version #{NODE_VERSION_TO_RUN}.") if not semver.satisfies(process.version, NODE_VERSION_TO_RUN)

{logger} = require './Logger'

express = require 'express'
fs = require 'fs'
path = require 'path'
morgan = require 'morgan'
killable = require 'killable'
config = require 'config'
RedisCache = require './RedisCache'
PathConstants = require './PathConstants'
OsuScoreBadgeCreator = require './OsuScoreBadgeCreator'

await RedisCache.init defer err
if err
    logger.error {err: err}, 'Error initializing RedisCache'
    process.exit 1
    return

logger.info 'input files initializing...'
await OsuScoreBadgeCreator.init defer err
if err
    logger.error {err: err}, 'Error initializing input files'
    process.exit 1
    return
logger.info 'input files initialized'

# setup routes
ROUTE_MOUNTS =
    api: '/api'
    main: '/'

logger.info 'Loading routes...'
ROUTES = {}
for routeName, routeMount of ROUTE_MOUNTS
    logger.info "\tLoading route '#{routeName}'"
    ROUTES[routeName] = require path.resolve PathConstants.routesDir, "#{routeName}.iced"
logger.info 'Done loading routes'

app = express()
app.enable 'trust proxy'
app.set 'views', PathConstants.viewsDir
app.set 'view engine', 'pug'

app.use express.static PathConstants.staticDir
app.use '/score', express.static PathConstants.dataDir
app.use morgan 'dev'

app.use (req, res, next) ->
    res.locals.url = req.url
    next()

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
killable server

# set socket chmod if applicable
if PathConstants.socket
    socketChmod = config.get 'http.socketChmod'
    fs.chmodSync PathConstants.socket, socketChmod if socketChmod

logger.info {address: server.address()}, 'Server running'

# on both SIGINT and SIGTERM start shutting down gracefully
process.on 'SIGTERM', -> process.emit 'requestShutdown'
process.on 'SIGINT', -> process.emit 'requestShutdown'
await process.once 'requestShutdown', defer()
logger.info 'Shutting down...'
process.on 'requestShutdown', ->
    logger.warn "process #{process.pid} already shutting down..."
    logWhyRunning()

# stop http-server
await server.kill defer err
if err
    logger.error {err: err}, 'Error while closing HTTP server'
else
    logger.info 'HTTP server has been closed'

await RedisCache.close defer()

# cleanup OsuScoreBadgeCreator
OsuScoreBadgeCreator.cleanup()

# THE END :D
logger.info "process with pid #{process.pid} ended gracefully :D"
