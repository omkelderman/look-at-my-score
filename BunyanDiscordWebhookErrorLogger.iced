DiscordWebhookShooter = require './DiscordWebhookShooter'

class BunyanDiscordWebhookErrorLogger
    constructor: (@webhookId, @webhookSecret) ->

    tryPrettyFormatJson: (json) ->
        try
            "```json\n#{JSON.stringify JSON.parse(json), null, 4}\n```"
        catch
            return json

    sendMessage: (message) ->
        message = @tryPrettyFormatJson message
        DiscordWebhookShooter.shoot @webhookId, @webhookSecret, content: message, (err, body) ->
            if err
                console.error 'error while sending discord error-log webhook', err

    write: (record) -> @sendMessage record

module.exports = BunyanDiscordWebhookErrorLogger