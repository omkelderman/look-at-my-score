bunyan = require 'bunyan'
bunyanDebugStream = require 'bunyan-debug-stream'

config = require 'config'
PathConstants = require './PathConstants'
path = require 'path'

logger = bunyan.createLogger
    name: 'app'
    serializers: bunyan.stdSerializers
    streams: [
        {level: 0, type: 'raw', stream: bunyanDebugStream {basepath: __dirname}}
        {level: config.get('log.level'), path: path.resolve(PathConstants.logDir, 'app.log')}
    ]

submitLogger = bunyan.createLogger
    name: 'submit'
    serializers: bunyan.stdSerializers
    streams: [
        {level: 0, path: path.resolve(PathConstants.logDir, 'submit.log')}
    ]

module.exports.logger = logger
module.exports.submitLogger = submitLogger
