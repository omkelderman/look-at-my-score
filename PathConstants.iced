config = require 'config'
path = require 'path'

module.exports =
    # from config
    dataDir: path.resolve __dirname, config.get 'dirs.data'
    coverCacheDir: path.resolve __dirname, config.get 'dirs.coverCache'
    tmpDir: path.resolve __dirname, config.get 'dirs.tmp'

    # hardcoded
    inputDir: path.resolve __dirname, 'input'
    routesDir: path.resolve __dirname, 'routes'
    viewsDir: path.resolve __dirname, 'views'
    staticDir: path.resolve __dirname, 'public'


httpListen = config.get 'http.listen'
if typeof httpListen is 'string'
    # httpListen is unix socket
    module.exports.socket = path.resolve __dirname, httpListen
