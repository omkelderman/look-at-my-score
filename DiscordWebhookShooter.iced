# this module is used in the logger logic, so we're not allowed to use the logger here

HttpRequester = require './HttpRequester'
DISCORD_WEBHOOK_REQUESTER = new HttpRequester 'https://discord.com/api/webhooks/%s/%s?wait=true', 5000
module.exports.shoot = (id, secret, hookData, cb) -> DISCORD_WEBHOOK_REQUESTER.postJson [id, secret], hookData, cb