module.exports.notFound = (message) -> { detail: message, status: 404, message: 'Not Found' }
module.exports.badRequest = (message) -> { detail: message, status: 400, message: 'Bad Request' }
module.exports.badGateway = (message) -> { detail: message, status: 502, message: 'Bad Gateway' }
module.exports.internalServerError = (message) -> { detail: message, status: 500, message: 'Internal Server Error' }

module.exports.handleOsuApiServerError = (err, nextHandler) ->
    console.error 'Error while comunicating with osu server', err
    nextHandler @badGateway 'osu server superslow or unavailable'

module.exports.handleCoverError = (err, nextHandler) ->
    # TODO: proper error logging
    if err.path
        # its a file system error
        console.error 'Error while saving cover jpg to disk', err
        return nextHandler @internalServerError 'error while saving cover jpg to disk'

    # else its a network error, aka osu server (if mine then website wouldnt work lol)
    console.error 'Error while retrieving cover jpg from osu servers', err
    return nextHandler @badGateway 'error while retrieving cover jpg from osu servers'
