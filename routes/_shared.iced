{logger} = require '../Logger'

crypto = require 'crypto'

# user errors
module.exports.notFound = (message) -> { detail: message, status: 404, message: 'Not Found' }
module.exports.badRequest = (message) -> { detail: message, status: 400, message: 'Bad Request' }
module.exports.badRequestWithError = (internalMessage, message, err, additionalLogFields) ->
    errorCode = _logErrorAndGenCode false, internalMessage, err, additionalLogFields
    message += " (error-code: #{errorCode})"
    return { detail: message, status: 400, message: 'Bad Request', errorCode: errorCode }

# errors about stuff the user has no control about
_logErrorAndGenCode = (iFuckedUp, internalMessage, err, additionalLogFields) ->
    errorCode = crypto.randomBytes(3).toString('hex')
    additionalLogFields = additionalLogFields || {}
    additionalLogFields.err = err
    additionalLogFields.errorCode = errorCode
    if iFuckedUp
        logger.error additionalLogFields, internalMessage
    else
        logger.warn additionalLogFields, internalMessage
    return errorCode

module.exports.badGateway = (internalMessage, message, err) ->
    internalMessage = message if not internalMessage
    errorCode = _logErrorAndGenCode false, internalMessage, err
    message += " (error-code: #{errorCode})"
    return { detail: message, status: 502, message: 'Bad Gateway', errorCode: errorCode }

module.exports.internalServerError = (internalMessage, err, additionalLogFields) ->
    errorCode = _logErrorAndGenCode true, internalMessage, err, additionalLogFields
    message = "Something on the server doesn\'t seem quite right... If this error persists, please contact me. Error-code: #{errorCode}"
    return { detail: message, status: 500, message: 'Internal Server Error', errorCode: errorCode }

# common errors
module.exports.osuApiServerError = (err) -> @badGateway 'error while comunicating with osu server', 'osu server superslow or unavailable, please try again!', err

module.exports.coverError = (err) ->
    if err.path
        # its a file system error
        return @internalServerError 'error while saving cover jpg to disk', err

    # else its a network error, aka osu server (if mine then website wouldnt work lol)
    return @badGateway null, 'error while retrieving cover jpg from osu servers', err
