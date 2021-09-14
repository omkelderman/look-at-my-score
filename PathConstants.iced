config = require 'config'
path = require 'path'
fs = require 'fs'

PathConstants =
    # from config
    dataDir: path.resolve __dirname, config.get 'dirs.data'
    coverCacheDir: path.resolve __dirname, config.get 'dirs.coverCache'
    tmpDir: path.resolve __dirname, config.get 'dirs.tmp'
    logDir: path.resolve __dirname, config.get 'log.dir'

    # hardcoded
    inputDir: path.resolve __dirname, 'input'
    routesDir: path.resolve __dirname, 'routes'
    viewsDir: path.resolve __dirname, 'views'
    staticDir: path.resolve __dirname, 'public'


httpListen = config.get 'http.listen'
if typeof httpListen is 'string'
    # httpListen is unix socket
    PathConstants.socket = path.resolve __dirname, httpListen

# ensure needed dirs exist
fs.mkdirSync PathConstants.dataDir, {recursive: true}
fs.mkdirSync PathConstants.coverCacheDir, {recursive: true}
fs.mkdirSync PathConstants.tmpDir, {recursive: true}
fs.mkdirSync PathConstants.logDir, {recursive: true}

module.exports = PathConstants
