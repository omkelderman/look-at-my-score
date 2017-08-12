config = require 'config'
path = require 'path'
mkdirp = require 'mkdirp'

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
mkdirp.sync PathConstants.dataDir
mkdirp.sync PathConstants.coverCacheDir
mkdirp.sync PathConstants.tmpDir
mkdirp.sync PathConstants.logDir

module.exports = PathConstants
