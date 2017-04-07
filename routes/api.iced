express = require 'express'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'
OsuApi = require '../OsuApi'

router = express.Router()

router.get '/test', (req, res, next) ->
    res.json
        a: 'OK'

router.post '/submit', (req, res, next) ->
    # required:
    #  - mode
    #  - beatmap_id  OR   beatmap
    #  - username    OR   score
    if not((req.body.beatmap_id? or req.body.beatmap?) and req.body.mode? and (req.body.username? or req.body.score?))
        return next
            detail: 'Invalid request: missing parameters'
            status: 400
            message: 'Bad Request'

    gameMode = req.body.mode

    # get beatmap
    if req.body.beatmap_id?
        # get beatmap
        await OsuApi.getBeatmap req.body.beatmap_id, gameMode, defer err, beatmap
        return next err if err
        if not beatmap
            return next
                detail: 'no beatmap found with that id'
                status: 404
                message: 'Not Found'
    else
        beatmap = req.body.beatmap

    # get score
    if req.body.username?
        await OsuApi.getScores beatmap.beatmap_id, gameMode, req.body.username, defer err, scores
        return next err if err
        if not scores
            return next
                detail: 'no score found for that user on that beatmap'
                status: 404
                message: 'Not Found'

        if scores.length > 1
            # oh no, multiple scores, dunno what to do, ask user
            console.log 'MULTIPLE SCORES'
            return res.json
                result: 'multiple-scores'
                data:
                    beatmap_id: beatmap.beatmap_id
                    mode: gameMode
                    scores: scores
                    texts: scores.map (score) -> "#{score.score} score | #{OsuScoreBadgeCreator.getAcc(gameMode, score)}% | #{score.maxcombo}x | #{(+score.pp).toFixed(2)} pp | #{OsuScoreBadgeCreator.toModsStr(score.enabled_mods)}"

        score = scores[0]
    else
        score = req.body.score

    # create the thing :D
    await OsuScoreBadgeCreator.create beatmap, gameMode, score, defer err, imageId
    return next err if err
    console.log 'CREATED:', imageId
    res.json
        result: 'image'
        image:
            id: imageId
            url: "#{req.protocol}://#{req.get('host')}/score/#{imageId}.png"

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
