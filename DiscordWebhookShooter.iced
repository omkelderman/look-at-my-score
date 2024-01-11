# this module is used in the logger logic, so we're not allowed to use the logger here

request = require 'request'
module.exports.shoot = (id, secret, hookData, cb) ->
    request.post {url: "https://discord.com/api/webhooks/#{id}/#{secret}", qs: {wait: true}, json: hookData}, (err, res, body) ->
        if err
            cb err, body
        else if res.statusCode isnt 200
            cb new Error("Unexpected response-code: #{res.statusCode}"), body
        else
            cb null, body