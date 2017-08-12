{logger} = require '../Logger'

module.exports.notFound = (message) -> { detail: message, status: 404, message: 'Not Found' }
module.exports.badRequest = (message) -> { detail: message, status: 400, message: 'Bad Request' }
module.exports.badGateway = (message) -> { detail: message, status: 502, message: 'Bad Gateway' }
module.exports.internalServerError = (message) -> { detail: message, status: 500, message: 'Internal Server Error' }

module.exports.osuApiServerError = (err) ->
    logger.warn {err: err}, 'Error while comunicating with osu server'
    return @badGateway 'osu server superslow or unavailable'

module.exports.coverError = (err) ->
    if err.path
        # its a file system error
        logger.error {err: err}, 'Error while saving cover jpg to disk'
        return @internalServerError 'error while saving cover jpg to disk'

    # else its a network error, aka osu server (if mine then website wouldnt work lol)
    logger.warn {err: err}, 'Error while retrieving cover jpg from osu servers'
    return @badGateway 'error while retrieving cover jpg from osu servers'
