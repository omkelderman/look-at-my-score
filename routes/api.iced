{logger, submitLogger} = require '../Logger'

config = require 'config'
express = require 'express'
bodyParser = require 'body-parser'
multer = require 'multer'
MulterOsrMemoryStorage = require '../MulterOsrMemoryStorage'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'
OsuApi = require '../OsuApi'
CoverCache = require '../CoverCache'
OsuMods = require '../OsuMods'
OsuAcc = require '../OsuAcc'
crypto = require 'crypto'
path = require 'path'
fs = require 'fs'
PathConstants = require '../PathConstants'
_ = require './_shared'
DiscordWebhookShooter = require '../DiscordWebhookShooter'
Util = require '../Util'

if config.get('discord.webhook.id')
    webhookId = config.get('discord.webhook.id')
    webhookSecret = config.get('discord.webhook.secret')
    postDiscordWebhook = (artist, title, creator, diff, beatmapId, date, imageUrl, username, userId) ->
        webhook =
            username: 'Look At My Score'
            content: 'New image just got generated!'
            embeds: [{
                title: "#{artist} - #{title} (#{creator}) [#{diff}]"
                description: '_[LookAtMySco.re](https://lookatmysco.re/)_'
                timestamp: date
                image:
                    url: imageUrl
                footer:
                    text: 'Generated'
                author:
                    name: username
            }]

        if beatmapId
            webhook.embeds[0].url = 'https://osu.ppy.sh/b/' + beatmapId
        if userId
            webhook.embeds[0].author.url = 'https://osu.ppy.sh/u/' + userId
            webhook.embeds[0].author.icon_url = 'https://a.ppy.sh/' + userId

        DiscordWebhookShooter.shoot webhookId, webhookSecret, webhook, (err, body) ->
            if err
                logger.error {err: err}, 'Error while shooting discord new image webhook'
            else
                logger.info {id: body.id}, 'New image discord webhook success'
else
    postDiscordWebhook = () -> #no-op

router = express.Router()

router.use bodyParser.urlencoded extended:true
router.use bodyParser.json()

router.get '/test', (req, res, next) ->
    res.json
        a: 'OK'

handleSubmitError = (nextHandler, req, err) ->
    submitLogger.warn {req: req, ip: req.ip, body: req.body, file: req.file, err: err}, 'submit error'
    nextHandler err

handleSubmitSuccess = (req, res, data) ->
    submitLogger.info {req: req, ip: req.ip, body: req.body, file: req.file, data: data}, 'submit success'
    res.json data


renderImageResponse = (req, res, next, coverJpg, beatmap, gameMode, score, isFromOsrFile, isCustomCover, ppTextSuffix) ->
    # one last final check: mods
    return handleSubmitError next, req, _.badRequest 'too many mods enabled, if this is a legit score, please contact me!' if not OsuScoreBadgeCreator.isValidModAmount +score.enabled_mods

    # create the thing :D
    imageId = crypto.randomUUID()
    createdDate = new Date()
    tmpPngLocation = path.resolve PathConstants.tmpDir, imageId + '.png'

    await OsuScoreBadgeCreator.create coverJpg, beatmap, gameMode, score, tmpPngLocation, ppTextSuffix, defer err, stdout, stderr, gmCommand

    # remove the cover image if it was a custom one, even before we handle the error from OsuScoreBadgeCreator.create since we wanna delete it regardless if it failed or not
    if isCustomCover
        fs.unlink coverJpg, (unlinkErr) ->
            if unlinkErr
                logger.error {err:unlinkErr}, 'error removing custom cover from disk'

    # if img gen failed, lets imidiately return
    return handleSubmitError next, req, _.internalServerError 'error while generating image', err, {stdout: stdout, stderr: stderr, gmCommand: gmCommand} if err

    # img created, now move to correct location
    pngLocation = path.resolve PathConstants.dataDir, imageId + '.png'
    await fs.rename tmpPngLocation, pngLocation, defer err
    return handleSubmitError next, req, _.internalServerError 'error while moving png file', err if err

    # also write a json-file with the meta-data
    jsonLocation = path.resolve PathConstants.dataDir, imageId + '.json'
    outputData =
        date: createdDate
        id: imageId
        mode: gameMode
        beatmap: beatmap
        score: score
        fromOsrFile: isFromOsrFile
    await fs.writeFile jsonLocation, JSON.stringify(outputData), defer err
    return handleSubmitError next, req, _.internalServerError 'error while writing json file to disk', err if err

    resultUrl = config.get 'image-result-url'
        .replace '{protocol}', req.protocol
        .replace '{host}', req.get 'host'
        .replace '{image-id}', imageId

    logger.info 'CREATED:', imageId
    handleSubmitSuccess req, res,
        result: 'image'
        image:
            id: imageId
            url: resultUrl

    postDiscordWebhook beatmap.artist, beatmap.title, beatmap.creator, beatmap.version, beatmap.beatmap_id, createdDate, resultUrl, score.username, score.user_id
    OsuScoreBadgeCreator.tryEmitNewImageCountEvent()

parseBoolean = (text) ->
    return text if typeof text is 'boolean'
    return false if not text or text.length is 0
    return ['1', 'on', 'yes', 'true', 'y'].indexOf(text.toString().toLowerCase()) isnt -1

router.post '/submit', (req, res, next) ->
    # required:
    #  - beatmap_id  OR   beatmap
    #  - username    OR   score
    # only required if beatmap is supplied instead of beatmap_id, altho it is ofc always possible to override (for converts):
    #  - mode
    # optional:
    #  - include_recent (if supplied, fetch score data from user_recent instead of scores, will be ignored if beatmap_id is unknown)
    #  - bg: base64 encoded image to be used as background
    #  - pp_text_suffix: if there is a pp value, add this text below the PP text
    #
    # additional requirements:
    #  - if 'username' is supplied instead of 'score', it is required to use the 'beatmap_id' option instead of 'beatmap'
    if not(req.body.beatmap_id? or req.body.beatmap?)
        return handleSubmitError next, req, _.badRequest 'missing either beatmap_id or beatmap object'

    if not(req.body.username? or req.body.score?)
        return handleSubmitError next, req, _.badRequest 'missing either username or score object'

    if req.body.beatmap? and not req.body.mode?
        return handleSubmitError next, req, _.badRequest 'when using custom beatmap object, mode is required'

    gameMode = req.body.mode

    # get beatmap
    if req.body.beatmap_id?
        # get beatmap
        # we do not know the score info here yet, which has the selected mods, so for now just get nomod data. Later on we will refresh it with the actual mod data
        await OsuApi.getBeatmap req.body.beatmap_id, gameMode, 0, defer err, beatmap
        return handleSubmitError next, req, _.osuApiServerError err if err
        return handleSubmitError next, req, _.notFound 'beatmap does not exist' if not beatmap

        if not gameMode?
            # mode was not supplied, get it from beatmap object
            gameMode = beatmap.mode
        beatmapObjectIsCustom = false
    else
        # no beatmap_id, so beatmap object must be supplied
        return handleSubmitError next, req, _.badRequest 'beatmap parameters not valid' if not OsuScoreBadgeCreator.isValidBeatmapObj req.body.beatmap
        beatmap = req.body.beatmap
        beatmapObjectIsCustom = true

    gameMode = +gameMode
    if isNaN(gameMode) or (gameMode < 0) or (gameMode > 3) or (Math.round(gameMode) isnt gameMode)
        return handleSubmitError next, req, _.badRequest 'invalid gamemode'

    # get score
    if req.body.username?
        return handleSubmitError next, req, _.badRequest 'beatmap_id is required when using username instead of score-object' if not req.body.beatmap_id?
        beatmapId = +req.body.beatmap_id

        await OsuApi.getScores beatmapId, gameMode, req.body.username, defer err, scores
        return handleSubmitError next, req, _.osuApiServerError err if err

        if parseBoolean(req.body.include_recent) and scores.length > 0
            # we should include recent and
            # also the scores-array is non-empty, since if it was, there wont be any recent entries of that map anyway
            # if we have a recent score on a map, so its in the system, we should have at least that one, or an earlier one of the same map, in the top-scores list
            await OsuApi.getRecentScores gameMode, req.body.username, defer err, recentScores
            return handleSubmitError next, req, _.osuApiServerError err if err
            recentScores = recentScores.filter (score) -> score.rank isnt 'F' and +score.beatmap_id is beatmapId
        else
            recentScores = []

        if not scores or not recentScores or (recentScores.length + scores.length) is 0
            return handleSubmitError next, req, _.notFound 'user does not exist, or does not have a score on the selected beatmap'

        if scores.length > 0 and recentScores.length > 0
            scoresUsername = scores[0].username
            for r in recentScores
                matchingIndex = scores.findIndex (s) -> s.score is r.score and s.maxcombo is r.maxcombo and s.count50 is r.count50 and s.count100 is r.count100 and s.count300 is r.count300 and s.countmiss is r.countmiss and s.countkatu is r.countkatu and s.countgeki is r.countgeki and s.perfect is r.perfect and s.enabled_mods is r.enabled_mods
                # if its a recent score thats not already in the top-scores list, lets add it
                if matchingIndex is -1
                    # username is missing from recent score objects ¯\_(ツ)_/¯
                    r.username = scoresUsername
                    scores.push r

        if scores.length > 1
            # oh no, multiple scores, dunno what to do, ask user
            scores.sort (a, b) -> b.date - a.date
            logger.info 'MULTIPLE SCORES'

            # fetch beatmap values per mod to have star values for each mod combination
            beatmaps = []
            textData = []
            for score,i in scores
                if score.enabled_mods > 0
                    await OsuApi.getBeatmap beatmapId, gameMode, score.enabled_mods, defer err, beatmapForScore
                    return handleSubmitError next, req, _.osuApiServerError err if err
                    return handleSubmitError next, req, _.notFound 'beatmap does not exist' if not beatmapForScore
                else
                    # we are in the flow of handling username, aka server provided scores
                    # in this flow it is forbidden to provide your own custom beatmap object
                    # which means we are guaranteed that the beatmap variable comes from the server
                    # and its nomod
                    beatmapForScore = beatmap

                beatmaps[i] = beatmapForScore
                textData[i] = [
                    score.date.toISOString().replace(/T/, ' ').replace(/\..+/, '') + ' UTC'
                    (+beatmapForScore.difficultyrating).toFixed(2)
                    score.score
                    OsuAcc.getAccStr(gameMode, score) + '%'
                    score.maxcombo
                    if score.pp then (+score.pp).toFixed(2) + ' pp' else ''
                    OsuMods.toModsStrLong(score.enabled_mods)
                ]
            return handleSubmitSuccess req, res,
                result: 'multiple-scores'
                data:
                    beatmaps: beatmaps
                    mode: gameMode
                    scores: scores
                    textData: textData

        score = scores[0]
    else
        # no username, so score object must be supplied
        return handleSubmitError next, req, _.badRequest 'score parameters not valid' if not OsuScoreBadgeCreator.isValidScoreObj req.body.score
        score = req.body.score
        score.date = Util.convertDateStringToDateObject score.date
        return handleSubmitError next, req, _.badRequest 'date value is invalid' if not score.date
        return handleSubmitError next, req, _.badRequest 'rank value is invalid' if not Util.checkOsuRankValueValid score.rank
    
    if not(beatmapObjectIsCustom) and (score.enabled_mods > 0)
        # refetch the beatmap to incorporate score mods so we have correct star values
        # if its a custom object we cannot refresh, if its nomod no need to refresh
        await OsuApi.getBeatmap beatmap.beatmap_id, gameMode, score.enabled_mods, defer err, beatmap
        return handleSubmitError next, req, _.osuApiServerError err if err
        return handleSubmitError next, req, _.notFound 'beatmap does not exist' if not beatmap

    # if body.bg exists, save it to disk, dont do the CoverCache stuff, and delete it after the render is done
    if req.body.bg?
        await CoverCache.saveCustomCoverImg req.body.bg, defer err, coverJpg
        return handleSubmitError next, req, _.internalServerError 'error saving custom cover to disk', err if err
        return handleSubmitError next, req, _.badRequest 'custom background image is not jpg or not 900x250' if not coverJpg
        isCustomCover = true
    else
        # grab the new.ppy.sh cover of the beatmap to start with
        await CoverCache.grabCoverFromOsuServer beatmap.beatmapset_id, defer err, coverJpg
        return handleSubmitError next, req, _.coverError err if err
        isCustomCover = false

    renderImageResponse req, res, next, coverJpg, beatmap, gameMode, score, false, isCustomCover, req.body.pp_text_suffix

createScoreObjFromOsrData = (data) ->
    return {
        date: data.date
        enabled_mods: data.modsBitmask
        count50: data.count50
        count100: data.count100
        count300: data.count300
        countmiss: data.countmiss
        countkatu: data.countkatu
        countgeki: data.countgeki
        score: data.score
        maxcombo: data.maxCombo
        username: data.username
    }

osrFileUploadMiddleware = multer({
    storage: new MulterOsrMemoryStorage()
    limits:
        fileSize: 512000 # 500KB
    fileFilter: (req, file, cb) -> cb null, file.originalname.endsWith('.osr')
}).single('osr_file')
router.post '/submit-osr', (req, res, next) ->
    await osrFileUploadMiddleware req, res, defer uploadErr
    if uploadErr
        return handleSubmitError next, req, _.badRequestWithError 'invalid osr file', 'failed to read .osr-file', uploadErr, file:uploadErr.file

    if not req.file
        return handleSubmitError next, req, _.badRequest 'no .osr file was supplied'

    gameMode = req.file.osrData.gameMode
    beatmapHash = req.file.osrData.beatmapMd5
    score = createScoreObjFromOsrData req.file.osrData
    pp = +req.body.score_pp

    # get beatmap
    await OsuApi.getBeatmapByHash beatmapHash, gameMode, score.enabled_mods, defer err, beatmap
    return handleSubmitError next, req, _.osuApiServerError err if err
    return handleSubmitError next, req, _.notFound 'beatmap does not exist' if not beatmap

    # grab the new.ppy.sh cover of the beatmap to start with
    await CoverCache.grabCoverFromOsuServer beatmap.beatmapset_id, defer err, coverJpg
    return handleSubmitError next, req, _.coverError err if err

    if pp
        score.pp = pp
    renderImageResponse req, res, next, coverJpg, beatmap, gameMode, score, true, false, null

router.get '/image-count', (req, res, next) ->
    await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, imagesAmount
    return next _.internalServerError 'error while retrieving image count', err if err
    res.json imagesAmount

router.get '/image-count-stream', (req, res, next) ->
    await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, imagesAmount
    return next _.internalServerError 'error while retrieving image count', err if err

    res.set 'Content-Type', 'text/event-stream'
    res.set 'Cache-Control', 'no-cache'
    res.set 'X-Accel-Buffering', 'no' # disable nginx reverse proxy buffering
    res.set 'Connection', 'keep-alive'
    res.flushHeaders()

    id = 0
    sendImageCountEvent = (newImagesAmount) -> res.write "id: #{id++}\nevent: image-count\ndata: #{newImagesAmount}\n\n"
    sendHeartbeatEvent = () -> res.write ": heartbeat\n\n"    
    sendImageCountEvent imagesAmount
    heartbeatInterval = setInterval sendHeartbeatEvent, config.get 'eventStreamHeartbeatMs'
    OsuScoreBadgeCreator.registerImageCountEventHandler sendImageCountEvent
    req.on 'close', () ->
        clearInterval heartbeatInterval
        OsuScoreBadgeCreator.unregisterImageCountEventHandler sendImageCountEvent

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
    return next _.osuApiServerError err if err

    if not set or set.length is 0
        return next _.notFound 'no beatmap-set found with that id'

    set.sort (a, b) -> a.mode - b.mode || a.difficultyrating - b.difficultyrating
    set = set.map (b) -> beatmap_id: b.beatmap_id, version: b.version, mode: b.mode
    res.json
        setId: setId
        stdOnlySet: set.every (b) -> +b.mode is 0
        defaultVersion: getDefaultFromSet set
        set: set

    preloadBeatmapCover setId

beatmapHandler = (req, res, next) ->
    beatmapId = req.params.beatmap_id
    mode = req.params.mode
    await OsuApi.getBeatmap beatmapId, mode, 0, defer err, beatmap
    return next _.osuApiServerError err if err
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

    preloadBeatmapCover beatmap.beatmapset_id

preloadBeatmapCover = (beatmapSetId) ->
    # lets already *start* loading beatmap-cover since we know it'll be requested after this anyway
    CoverCache.grabCoverFromOsuServer beatmapSetId, (err, coverJpg) ->
        if err
            logger.error {err: err}, 'preloading beatmap-cover failed'
        else
            logger.debug {coverJpg: coverJpg}, 'preloaded beatmap-cover'

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
