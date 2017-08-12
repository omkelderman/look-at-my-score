bunyan = require 'bunyan'
bunyanDebugStream = require 'bunyan-debug-stream'

config = require 'config'
PathConstants = require './PathConstants'

logger = bunyan.createLogger
    name: 'app'
    serializers: bunyan.stdSerializers
    streams: [
        {level: 0, type: 'raw', stream: bunyanDebugStream {basepath: __dirname}}
        {level: config.get('log.level'), path: PathConstants.logPath}
    ]

module.exports.logger = logger
