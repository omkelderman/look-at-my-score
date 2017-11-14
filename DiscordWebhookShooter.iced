{logger} = require './Logger'

request = require 'request'
config = require 'config'

WEBHOOK_URL = "https://discordapp.com/api/webhooks/#{config.get('discord.webhook.id')}/#{config.get('discord.webhook.secret')}"

shootWebhook = (hookData) ->
    request.post {url: WEBHOOK_URL, qs: {wait: true}, json: hookData}, (err, res, body) ->
        if err
            logger.error {err: err}, 'Error while shooting discord webhook'
        else if res.statusCode isnt 200
            logger.error {res: res, body: body}, 'Error while shooting discord webhook: unexpected response-code: ' + res.statusCode
        else
            logger.info {id: body.id}, 'Hook success'

module.exports.shoot = shootWebhook
