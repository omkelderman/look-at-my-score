request = require 'request'

class BunyanTelegramBotLogger
    constructor: (@botToken, @chatId) ->
        @url = "https://api.telegram.org/bot#{botToken}/sendMessage"

    sendMessage: (message) ->
        data =
            chat_id: @chatId
            text: message

        request.post {url: @url, json: data}, (err, res, body) ->
            if err
                console.error 'error while sending telegram message', err
            else if res.statusCode isnt 200
                console.error 'error while sending telegram message, unexpected status-code', res.statusCode

    write: (record) -> @sendMessage record

module.exports = BunyanTelegramBotLogger
