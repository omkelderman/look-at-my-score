config = require 'config'
express = require 'express'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'
OsuApi = require '../OsuApi'
CoverCache = require '../CoverCache'
OsuMods = require '../OsuMods'
OsuAcc = require '../OsuAcc'
uuidV4 = require 'uuid/v4'
path = require 'path'
fs = require 'fs'
PathConstants = require '../PathConstants'
_ = require './_shared'

MYSQL_DATE_STRING_REGEX = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
ISO_UTC_DATE_STRING_REGEX = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/

convertDateStringToDateObject = (str) ->
    # lets trim cuz why not
    str = str.trim()

    # convert str into a date object.
    # two formats allowed:
    #   - a mysql-date-string (xxxx-xx-xx xx:xx:xx), asume +8 timezone like osu api
    #   - ISO UTC string (xxxx-xx-xxTxx:xx:xx[.xxx]Z)
    if MYSQL_DATE_STRING_REGEX.test str
        # is mysql-date, lets convert it to an ISO string
        str = str.replace(' ', 'T')+'+08:00'
    else if not ISO_UTC_DATE_STRING_REGEX.test str
        # both not mysql date or iso date string, abort
        return null

    # convert to date object
    date = new Date str

    # the original string had a sortof valid ISO date format, but no idea yet if it is an actual valid date, so lets do a final check on that
    if isNaN date.getTime()
        # invalid date!
        return null

    # valid date!
    return date

handleOsuApiServerError = (err, nextHandler) ->
    console.error 'Error while comunicating with osu server', err
    nextHandler _.badGateway 'osu server superslow or unavailable'

router = express.Router()

router.get '/test', (req, res, next) ->
    res.json
        a: 'OK'

router.post '/submit', (req, res, next) ->
    # required:
    #  - beatmap_id  OR   beatmap
    #  - username    OR   score
    # only required if beatmap is supplied instead of beatmap_id, altho it is ofc always possible to override (for converts):
    #  - mode
    if not(req.body.beatmap_id? or req.body.beatmap?)
        return next _.badRequest 'missing either beatmap_id or beatmap object'

    if not(req.body.username? or req.body.score?)
        return next _.badRequest 'missing either username or score object'

    if req.body.beatmap? and not req.body.mode
        return next _.badRequest 'when using custom beatmap object, mode is required'

    gameMode = req.body.mode

    # get beatmap
    if req.body.beatmap_id?
        # get beatmap
        await OsuApi.getBeatmap req.body.beatmap_id, gameMode, defer err, beatmap
        return handleOsuApiServerError err, next if err
        return next _.notFound 'beatmap does not exist' if not beatmap

        if not gameMode?
            # mode was not supplied, get it from beatmap object
            gameMode = beatmap.mode
    else
        # no beatmap_id, so beatmap object must be supplied
        return next _.badRequest 'beatmap parameters not valid' if not OsuScoreBadgeCreator.isValidBeatmapObj req.body.beatmap
        beatmap = req.body.beatmap

    # get score
    if req.body.username?
        await OsuApi.getScores beatmap.beatmap_id, gameMode, req.body.username, defer err, scores
        return handleOsuApiServerError err, next if err
        if not scores or scores.length is 0
            return next _.notFound 'user does not exist, or does not have a score on the selected beatmap'

        if scores.length > 1
            # oh no, multiple scores, dunno what to do, ask user
            console.log 'MULTIPLE SCORES'
            return res.json
                result: 'multiple-scores'
                data:
                    beatmap_id: beatmap.beatmap_id
                    mode: gameMode
                    scores: scores
                    texts: scores.map (score) -> "#{score.score} score | #{OsuAcc.getAcc(gameMode, score)}% | #{score.maxcombo}x | #{(+score.pp).toFixed(2)} pp | #{OsuMods.toModsStrLong(score.enabled_mods)}"

        score = scores[0]
    else
        # no username, so score object must be supplied
        return next _.badRequest 'score parameters not valid' if not OsuScoreBadgeCreator.isValidScoreObj req.body.score
        score = req.body.score
        score.date = convertDateStringToDateObject score.date
        return next _.badRequest 'date value is invalid' if not score.date

    # grab the new.ppy.sh cover of the beatmap to start with
    await CoverCache.grabCoverFromOsuServer beatmap.beatmapset_id, defer err, coverJpg
    return _.handleCoverError err, next if err

    # create the thing :D
    imageId = uuidV4()
    tmpPngLocation = path.resolve PathConstants.tmpDir, imageId + '.png'

    await OsuScoreBadgeCreator.create coverJpg, beatmap, gameMode, score, tmpPngLocation, defer err, stdout, stderr, gmCommand
    if err
        # img gen failed, lets imidiately return
        # TODO: proper error logging (and do something with err, stdout, stderr, gmCommand)
        console.error 'Error while generating image', err, stdout, stderr, gmCommand
        return next _.internalServerError 'error while generating image'

    console.log 'CREATED:', tmpPngLocation

    # img created, now move to correct location
    pngLocation = path.resolve PathConstants.dataDir, imageId + '.png'
    await fs.rename tmpPngLocation, pngLocation, defer err
    if err
        # TODO: proper error logging
        console.error 'Error while moving png file', err
        return done _.internalServerError 'error while moving png file'

    # also write a json-file with the meta-data
    jsonLocation = path.resolve PathConstants.dataDir, imageId + '.json'
    outputData =
        date: new Date().toISOString()
        id: imageId
        mode: gameMode
        beatmap: beatmap
        score: score
    await fs.writeFile jsonLocation, JSON.stringify(outputData), defer err
    if err
        # TODO: proper error logging
        console.error 'Error while writing json file to disk', err
        return done _.internalServerError 'error while writing json file to disk'

    resultUrl = config.get 'image-result-url'
        .replace '{protocol}', req.protocol
        .replace '{host}', req.get 'host'
        .replace '{image-id}', imageId

    res.json
        result: 'image'
        image:
            id: imageId
            url: resultUrl

router.get '/image-count', (req, res, next) ->
    await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, imagesAmount
    if err
        # TODO: proper error logging
        console.error 'Error while retrieving image count', err
        return next _.internalServerError 'error while retrieving image count'
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
    return handleOsuApiServerError err, next if err

    if not set or set.length is 0
        return next _.notFound 'no beatmap-set found with that id'

    set.sort (a, b) -> a.mode - b.mode || a.difficultyrating - b.difficultyrating
    set = set.map (b) -> beatmap_id: b.beatmap_id, version: b.version, mode: b.mode
    res.json
        setId: setId
        stdOnlySet: set.every (b) -> +b.mode is 0
        defaultVersion: getDefaultFromSet set
        set: set

beatmapHandler = (req, res, next) ->
    beatmapId = req.params.beatmap_id
    mode = req.params.mode
    await OsuApi.getBeatmap beatmapId, mode, defer err, beatmap
    return handleOsuApiServerError err, next if err
    return next _.notFound 'no beatmap found with that id' if not beatmap

    res.json
        beatmapId: beatmap.beatmap_id
        beatmapSetId: beatmap.beatmapset_id
        mode: mode || beatmap.mode
        converted: mode? and (beatmap.mode isnt mode)
        title: beatmap.title
        artist: beatmap.artist
        version: beatmap.version
        creator: beatmap.creator
router.get '/beatmap/:beatmap_id([0-9]+)/:mode([0-3])', beatmapHandler
router.get '/beatmap/:beatmap_id([0-9]+)', beatmapHandler

# not found? gen 404
router.use (req, res, next) ->
    next
        message: 'Not Found'
        status: 404

# on error
router.use (err, req, res, next) ->
    res.status err.status || 500
    res.json
        error: err.message
        status: err.status
        detailMessage: err.detail || err.stack

module.exports = router
