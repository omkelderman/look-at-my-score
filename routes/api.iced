express = require 'express'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'
OsuApi = require '../OsuApi'
CoverCache = require '../CoverCache'

notFound = (message) -> { detail: message, status: 404, message: 'Not Found' }
badRequest = (message) -> { detail: message, status: 400, message: 'Bad Request' }

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
        return next badRequest 'Invalid request: missing parameters'

    gameMode = req.body.mode

    # get beatmap
    if req.body.beatmap_id?
        # get beatmap
        await OsuApi.getBeatmap req.body.beatmap_id, gameMode, defer err, beatmap
        return next err if err
        if not beatmap
            return next notFound 'no beatmap found with that id'
    else
        return next badRequest 'beatmap object not valid' if not OsuScoreBadgeCreator.isValidBeatmapObj req.body.score
        beatmap = req.body.beatmap

    # get score
    if req.body.username?
        await OsuApi.getScores beatmap.beatmap_id, gameMode, req.body.username, defer err, scores
        return next err if err
        if not scores or scores.length is 0
            return next notFound 'no score found for that user on that beatmap'

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
        return next badRequest 'score object not valid' if not OsuScoreBadgeCreator.isValidScoreObj req.body.score
        score = req.body.score

    # # grab the new.ppy.sh cover of the beatmap to start with
    await CoverCache.grab beatmap.beatmapset_id, defer err, coverJpg
    return next err if err

    # create the thing :D
    await OsuScoreBadgeCreator.create coverJpg, beatmap, gameMode, score, defer err, imageId
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

getDefaultFromSet = (set) ->
    prevMode = set[0].mode
    prevId = set[0].beatmap_id
    size = set.length
    index = 1
    while index < size
        map = set[index]
        if map.mode isnt prevMode
            break
        prevId = map.beatmap_id
        ++index
    return prevId

router.get '/diffs/:set_id([0-9]+)', (req, res, next) ->
    setId = req.params.set_id
    await OsuApi.getBeatmapSet setId, defer err, set
    return next err if err

    if not set or set.length is 0
        return next notFound setId
        # return res.json
        #     setId: setId
        #     set: null


    set.sort (a, b) -> a.mode - b.mode || a.difficultyrating - b.difficultyrating
    set = set.map (b) -> beatmap_id: b.beatmap_id, version: b.version, mode: b.mode
    res.json
        setId: setId
        stdOnlySet: set.every (b) -> +b.mode is 0
        defaultVersion: getDefaultFromSet set
        set: set

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
