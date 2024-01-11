bunyan = require 'bunyan'
bunyanDebugStream = require 'bunyan-debug-stream'

config = require 'config'
PathConstants = require './PathConstants'
path = require 'path'

BunyanDiscordWebhookErrorLogger = require './BunyanDiscordWebhookErrorLogger'

logStreams = [
    {level: 0, type: 'raw', stream: bunyanDebugStream.create {basepath: __dirname}}
    {level: config.get('log.level'), path: path.resolve(PathConstants.logDir, 'app.log')}
]

if config.get('discord.errorLogWebhook.id')
    logStreams.push {level: 'error', stream: new BunyanDiscordWebhookErrorLogger(config.get('discord.errorLogWebhook.id'), config.get('discord.errorLogWebhook.secret'))}

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
