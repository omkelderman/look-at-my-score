bunyan = require 'bunyan'
bunyanDebugStream = require 'bunyan-debug-stream'

config = require 'config'
PathConstants = require './PathConstants'
path = require 'path'

BunyanTelegramBotLogger = require './BunyanTelegramBotLogger'

logStreams = [
    {level: 0, type: 'raw', stream: bunyanDebugStream {basepath: __dirname}}
    {level: config.get('log.level'), path: path.resolve(PathConstants.logDir, 'app.log')}
]

if config.get('telegram.botToken')
    logStreams.push {level: 'error', stream: new BunyanTelegramBotLogger(config.get('telegram.botToken'), config.get('telegram.chatId'))}

logger = bunyan.createLogger
    name: 'app'
    serializers: bunyan.stdSerializers
    streams: logStreams

submitLogger = bunyan.createLogger
    name: 'submit'
    serializers: bunyan.stdSerializers
    streams: [
        {level: 0, path: path.resolve(PathConstants.logDir, 'submit.log')}
    ]

module.exports.logger = logger
module.exports.submitLogger = submitLogger
