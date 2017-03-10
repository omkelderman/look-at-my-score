express = require 'express'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'

router = express.Router()

router.get '/test', (req, res, next) ->
    res.json
        a: 'OK'

router.post '/submit', (req, res, next) ->
    console.log req.body
    # return next new Error 'welp'
    if not(req.body.beatmap_id and req.body.mode and (req.body.username or req.body.score))
        return next
            detail: 'Invalid request: missing parameters'
            status: 400
            message: 'Bad Request'
    await OsuScoreBadgeCreator.create req.body.beatmap_id, req.body.mode, req.body.username || req.body.score, defer err, id, multiScoreResult
    if err
        console.error 'ERROR:', err

        # # change to http-error
        if typeof err is 'string'
            err = detail: err
            if err.detail[0] is 'i'
                err.status = 400
                err.message = 'Bad Request'
            else if err.detail[0] is 'n'
                err.status = 404
                err.message = 'Not Found'
            else
                err.status = 500
                err.message = 'Internal Server Error'

        return next err

    if id
        console.log 'CREATED:', id
        res.json
            result: 'image'
            image:
                id: id
                url: req.protocol + '://' + req.get('host') + '/score/' + id + '.png'
        return

    if multiScoreResult
        console.log 'MULTIPLE SCORES'
        res.json
            result: 'multiple-scores'
            data: multiScoreResult
        return

    # welp, not implemented yet
    res.json
        result: 'WIP'

router.get '/image-count', (req, res, next) ->
    await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, imagesAmount
    return next err if err
    res.json imagesAmount

# not found? gen 404
router.use (req, res, next) ->
    err = new Error 'Not Found'
    err.status = 404
    next err

# on error
router.use (err, req, res, next) ->
    res.status err.status || 500
    res.json
        error: err.message
        status: err.status
        detailMessage: err.detail || err.stack

module.exports = router
