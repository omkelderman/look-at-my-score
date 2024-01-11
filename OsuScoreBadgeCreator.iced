{logger} = require './Logger'
config = require 'config'
gm = require 'gm'
fs = require 'fs'
path = require 'path'
RedisCache = require './RedisCache'
PathConstants = require './PathConstants'
OsuMods = require './OsuMods'
OsuAcc = require './OsuAcc'
Util = require './Util'
opentype = require 'opentype.js'
EventEmitter = require 'events'

# constants
COLOR1 = '#eee'
COLOR2 = '#f6a'
COLOR3 = '#EA609B'
COLOR_BLUR = '#000'
COLOR3_STROKE = '#fff'

COLOR_WATERMARK = '#ccc'
COLOR_WATERMARK_BLUR = '#000'

# font size of the beatmap version string, needed globally cuz we also need it for calculating the pixel width
VERSION_FONT_SIZE = 22

# constants
FONTFILE_REGEX = /^Exo2\-(.+)\.ttf$/
FONTS = {}
OVERLAYS = {}
RANKINGS = {}
STAR_ICON = path.resolve PathConstants.inputDir, 'star.png'
IMAGE_WIDTH = 900
IMAGE_HEIGHT = 250

RANK_IMAGE_WIDTH = 148
RANK_IMAGE_HEIGHT = 178

STAR_IMAGE_WIDTH = 24
STAR_IMAGE_HEIGHT = 24

OPENTYPE_CACHE = new Map()
getFont = (fontPath, cb) =>
    fromCache = OPENTYPE_CACHE.get fontPath
    return cb null, fromCache if fromCache
    opentype.load fontPath, (err, font) ->
        return cb err if err
        OPENTYPE_CACHE.set(fontPath, font)
        cb null, font

init = (cb) ->
    await OsuMods.init defer err
    return cb err if err

    # read fonts
    await fs.readdir path.resolve(PathConstants.inputDir, 'fonts'), defer err, fontList
    return cb err if err
    for file in fontList
        result = FONTFILE_REGEX.exec file
        if result
            FONTS[result[1]] = path.resolve PathConstants.inputDir, 'fonts', file
            

    # read overlays
    await fs.readdir path.resolve(PathConstants.inputDir, 'overlay'), defer err, overlayList
    return cb err if err
    for file in overlayList
        if file.endsWith '.png'
            overlayImagePath = path.resolve PathConstants.inputDir, 'overlay', file
            await Util.checkImageSize overlayImagePath, IMAGE_WIDTH, IMAGE_HEIGHT, defer err, sizeOk
            return cb err if err
            if not sizeOk
                return cb new Error("File '#{overlayImagePath}' does not have the correct size")
            OVERLAYS[file[...-4]] = overlayImagePath

    # read rankings
    await fs.readdir path.resolve(PathConstants.inputDir, 'ranking'), defer err, rankingsList
    return cb err if err
    for file in rankingsList
        if file.endsWith '.png'
            rankImagePath = path.resolve PathConstants.inputDir, 'ranking', file
            await Util.checkImageSize rankImagePath, RANK_IMAGE_WIDTH, RANK_IMAGE_HEIGHT, defer err, sizeOk
            return cb err if err
            if not sizeOk
                return cb new Error("File '#{rankImagePath}' does not have the correct size")
            RANKINGS[file[...-4]] = rankImagePath
    
    await Util.checkImageSize STAR_ICON, STAR_IMAGE_WIDTH, STAR_IMAGE_HEIGHT, defer err, sizeOk
    return cb err if err
    if not sizeOk
        return cb new Error("File '#{STAR_ICON}' does not have the correct size")

    cb null

addThousandSeparators = (number, character) ->
    # make sure its a string
    number = number.toString()

    # introduce character
    return number.replace(/\B(?=(\d{3})+(?!\d))/g, character)


calcStdRank = (acc, score) ->
    return 'X' if acc is 1
    hitCount = score.count300 + score.count100 + score.count50 + score.countmiss
    return 'D' if hitCount is 0 # wtf??
    hasNoMisses = score.countmiss is 0
    ratio300 = score.count300 / hitCount
    ratio50 = score.count50 / hitCount
    return 'S' if hasNoMisses and (ratio300 > 0.9) and (ratio50 <= 0.01)
    return 'A' if (hasNoMisses and (ratio300 > 0.8)) or (ratio300 > 0.9)
    return 'B' if (hasNoMisses and (ratio300 > 0.7)) or (ratio300 > 0.8)
    return 'C' if ratio300 > 0.6
    return 'D'

calcTaikoRank = calcStdRank # taiko re-uses std formula

calcCtbRank = (acc, score) ->
    return 'X' if acc is 1
    return 'S' if acc > 0.98
    return 'A' if acc > 0.94
    return 'B' if acc > 0.90
    return 'C' if acc > 0.85
    return 'D'

calcManiaRank = (acc, score) ->
    return 'X' if acc is 1
    return 'S' if acc > 0.95
    return 'A' if acc > 0.90
    return 'B' if acc > 0.80
    return 'C' if acc > 0.70
    return 'D'

CALC_RANK_FUNCTIONS = [calcStdRank, calcTaikoRank, calcCtbRank, calcManiaRank]
calcRank = (mode, acc, score, enabled_mods) ->
    func = CALC_RANK_FUNCTIONS[mode]
    return 'D' if not func # terrible default, but whatever, at least it wont crash eks dee
    rank = func acc, score

    # apply silver
    if (rank is 'S' or rank is 'X') and ((enabled_mods & (1049608)) > 0) # 1049608 = 1048576+8+1024 = hidden + flash light + fade in
        rank += 'H'
    return rank

####################
# [A] xxx  [D] xxx #
# [B] xxx  [E] xxx #
# [C] xxx  [F] xxx #
####################

drawStdHitCounts = (img, score) ->
    img.drawText(215, 123, 'x' + score.count300)   # A - 300
        .drawText(215, 163, 'x' + score.count100)  # B - 100
        .drawText(215, 203, 'x' + score.count50)   # C - 50
        .drawText(365, 123, 'x' + score.countgeki) # D - 300g
        .drawText(365, 163, 'x' + score.countkatu) # E - 100k
        .drawText(365, 203, 'x' + score.countmiss) # F - miss

drawTaikoHitCounts = (img, score) ->
    img.drawText(215, 123, 'x' + (score.count300 - score.countgeki))   # A - great part 1 (greats - geki)
        .drawText(215, 163, 'x' + (score.count100 - score.countkatu))  # B - good part 1 (goods - katu)
        .drawText(215, 203, 'x' + score.countmiss) # C - miss
        .drawText(365, 123, 'x' + score.countgeki)  # D - great part 2 (geki)
        .drawText(365, 163, 'x' + score.countkatu) # E - good part 2 (katu)
    # F - non existend

drawCtbHitCounts = (img, score) ->
    img.drawText(215, 123, 'x' + score.count300)   # A - 300
        .drawText(215, 163, 'x' + score.count100)  # B - 100
        .drawText(215, 203, 'x' + score.count50)   # C - 50 (droplets)
        .drawText(365, 123, 'x' + score.countmiss) # D - miss
    # E - non existend
    # F - non existend

drawManiaHitCounts = (img, score) ->
    img.drawText(215, 123, 'x' + score.count300)   # A -
        .drawText(215, 163, 'x' + score.countkatu) # B
        .drawText(215, 203, 'x' + score.count50)   # C
        .drawText(365, 123, 'x' + score.countgeki) # D
        .drawText(365, 163, 'x' + score.count100)  # E
        .drawText(365, 203, 'x' + score.countmiss) # F

DRAW_HIT_COUNT_FUNCTIONS = [drawStdHitCounts, drawTaikoHitCounts, drawCtbHitCounts, drawManiaHitCounts]
drawHitCounts = (img, mode, score) ->
    func = DRAW_HIT_COUNT_FUNCTIONS[mode]
    func img, score if func

formatDate = (d) -> d.toISOString().replace(/T/, ' ').replace(/\..+/, '') + ' UTC'

escapeText = (str) -> str.replace '%', '%%'

drawAllTheText = (img, beatmap, mode, score, accStr, blurColor, ppTextSuffix, beatmapVersionPxWidth) ->
    img
        # draw hit-amounts
        .font(FONTS.ExtraBold)
        .fill(if blurColor then COLOR_BLUR else COLOR1)
        .fontSize(27)
    drawHitCounts img, mode, score

    # draw acc
    img.fontSize(48)
        .drawText(461, 136, addThousandSeparators(score.score, ' '))

        .font(FONTS.Regular)

        # draw acc
        .fontSize(60)
        .drawText(551, 201, escapeText(accStr + '%'))

    # beatmap.max_combo could be "null", in that case, dont draw it
    # and draw the actual combo a bit lower
    comboOffset = if beatmap.max_combo then 0 else 15
    # draw combo
    img.fontSize(32)
        .drawText(451, 176 + comboOffset, 'x' + score.maxcombo)

    if beatmap.max_combo
        img.fontSize(22).drawText(456, 206, '/' + beatmap.max_combo)

    # draw other info crap
    img.fontSize(40)
        .drawText(150, 40, escapeText(beatmap.title))
        .fontSize(16)
        .drawText(155, 60, escapeText(beatmap.artist))

        .fontSize(16)
        .drawText(150, 240, 'Mapped by:')
        .drawText(415, 240, 'Played by:')
        .drawText(680, 240, 'at')
        .fill(if blurColor then COLOR_BLUR else COLOR2)
        .drawText(702, 240, formatDate(score.date))
        .fontSize(20)
        .drawText(240, 240, escapeText(beatmap.creator))
        .drawText(495, 240, escapeText(score.username))

    if not blurColor
        img.stroke ''

    VERSION_Y = 86
    img.fill(if blurColor then COLOR_BLUR else COLOR1)
        .fontSize(VERSION_FONT_SIZE)
        .font(FONTS.Italic)
        .drawText(190, VERSION_Y, escapeText(beatmap.version))

    # draw star value
    starValue = +beatmap.difficultyrating
    if starValue
        img
            .font(FONTS.Regular)
            .drawText(240 + beatmapVersionPxWidth, VERSION_Y, starValue.toFixed(2))

    # draw some watermark thingy
    img.fill(if blurColor then COLOR_WATERMARK_BLUR else COLOR_WATERMARK)
        .fontSize 12
        .drawText 4, 14, escapeText config.get 'watermark.text'
        .drawLine 4, 15, 4 + config.get('watermark.underline-length'), 15

    # TODO: maybe add logic to see if it is ranked or not, aka maybe pp is here but is not actually applied or something
    if score.pp
        # force number
        ppNumber = +score.pp

        # calculate position
        ppValueX = 765
        ppTextX = 790
        if ppNumber < 1000
            ppTextX -= 6
        if ppNumber < 100
            ppValueX += 15
        if ppNumber < 10
            ppValueX += 12

        # draw logic
        img.font FONTS.ExtraBold
            .fill(if blurColor then COLOR3_STROKE else COLOR3)
        if not blurColor
            img.stroke COLOR3_STROKE, 1
        img.fontSize 32
            .drawText ppValueX, 136, ppNumber.toFixed 2
            .font FONTS.ExtraBoldItalic
        if ppTextSuffix
            img.fontSize 54
        else
            img.fontSize 62
        if not blurColor
            img.stroke COLOR3_STROKE, 4
        img.drawText ppTextX, (if ppTextSuffix then 192 else 200), 'PP'
        if ppTextSuffix
            if not blurColor
                img.stroke COLOR3_STROKE, 1
            img.fontSize 24
            img.drawText ppTextX, 218, ppTextSuffix
        if not blurColor
            img.stroke ''

drawOverlayImage = (img, x, y, w, h, overlayImagePath) ->
    # lol replace is only needed on windows
    # it has backslahes in path and then if for whatever reason there was "\r" in the path (eg input\ranking\S.png)
    # it would interpret that as a carriage return, escaling the \ didnt help...
    # so I'll just convert all backslages to forward slashes cuz yolo
    overlayImagePath = '"' + overlayImagePath.trim().replace(/\\/g, '/') + '"'
    img.draw "image Over #{x},#{y} #{w},#{h} #{overlayImagePath}"

drawMods = (img, mods) ->
    modsArr = OsuMods.bitmaskToModArray mods
    for mod, i in modsArr
        drawMod img, mod, i, modsArr.length

calcModDrawOffset = (amountOfMods, modIndex) -> (12.5*amountOfMods)+25 - (modIndex * 20)
drawMod = (img, mod, i, totalSize) ->
    x = calcModDrawOffset totalSize, i
    if x < 0
        throw new Error 'Render error: too many mods to draw'
    drawOverlayImage img, x, 195, OsuMods.IMAGE_WIDTH, OsuMods.IMAGE_HEIGHT, OsuMods.getImagePath(mod)

isValidModAmount = (mods) ->
    amountOfMods = OsuMods.bitmaskToModArray(mods).length
    x = calcModDrawOffset amountOfMods, amountOfMods-1
    return x >= 0

isValidObj = (obj, requiredKeys) -> (obj isnt null) and (typeof obj is 'object') and (requiredKeys.every (x) -> x of obj)

# pp is optional, if not provided it'll simply not be shown
# rank is optional, if not provided it'll be calculated
SCORE_OBJ_REQ_PROPS = ['date', 'enabled_mods', 'count50', 'count100', 'count300', 'countmiss', 'countkatu', 'countgeki', 'score', 'maxcombo', 'username']
isValidScoreObj = (obj) -> isValidObj obj, SCORE_OBJ_REQ_PROPS

BEATMAP_OBJ_REQ_PROPS = ['title', 'artist', 'creator', 'version']
isValidBeatmapObj = (obj) -> isValidObj obj, BEATMAP_OBJ_REQ_PROPS

createGmDrawCommandChain = (bgImg, beatmap, gameMode, score, ppTextSuffix, beatmapVersionPxWidth) ->
    # calc some shit and fetch some additional details
    overlayImagePath = OVERLAYS[gameMode]
    throw new Error "Render error: unknown gamemode '#{gameMode}'" if not overlayImagePath
    enabled_mods = +score.enabled_mods
    acc = OsuAcc.getAcc gameMode, score
    if acc is 1
        accStr = '100'
    else
        accStr = (acc*100).toFixed(2)
    if score.rank
        rank = score.rank
    else
        rank = calcRank gameMode, acc, score, enabled_mods
    rankingImagePath = RANKINGS[rank]
    throw new Error "Render error: unknown rank '#{score.rank}'" if not rankingImagePath

    # start
    img = gm bgImg

    # draw all text for background-blur
    drawAllTheText img, beatmap, gameMode, score, accStr, true, ppTextSuffix, beatmapVersionPxWidth

    # blur it
    img.blur(0,4.3)

    # add black
    img.fill('#0007').drawRectangle 0, 0, IMAGE_WIDTH, IMAGE_HEIGHT

    # draw all the text again, but now for real
    drawAllTheText img, beatmap, gameMode, score, accStr, false, ppTextSuffix, beatmapVersionPxWidth

    # lets draw some additional bits
    rankingOffset = if enabled_mods is 0 then 40 else 20

    # draw the rank
    drawOverlayImage img, 0, rankingOffset, RANK_IMAGE_WIDTH, RANK_IMAGE_HEIGHT, rankingImagePath

    # and draw the "hit-objects" and mode-icon
    drawOverlayImage img, 0, 0, IMAGE_WIDTH, IMAGE_HEIGHT, overlayImagePath

    if +beatmap.difficultyrating
        # and draw the star icon for beatmap star value
        drawOverlayImage img, 210 + beatmapVersionPxWidth, 65, STAR_IMAGE_WIDTH, STAR_IMAGE_HEIGHT, STAR_ICON

    # add mods
    drawMods img, enabled_mods

    return img

# input objects must be "correct"
# check with isValidScoreObj/isValidBeatmapObj
# otherwise shit will fail
createOsuScoreBadge = (bgImg, beatmap, gameMode, score, outputFile, ppTextSuffix, done) ->
    # make sure gameMode is a number
    gameMode = +gameMode

    await getFont FONTS.Italic, defer err, fontItalic
    return done err if err

    beatmapVersionPxWidth = fontItalic.getAdvanceWidth(beatmap.version, VERSION_FONT_SIZE)

    try
        img = createGmDrawCommandChain bgImg, beatmap, gameMode, score, ppTextSuffix, beatmapVersionPxWidth
    catch imgCreateError
        return done imgCreateError


    # write png file
    img.write outputFile, done

getGeneratedImagesAmount = (cb) ->
    await RedisCache.get 'image-count', defer isInCache, cachedResult
    return cb null, cachedResult if isInCache # yay cache exists
    getGeneratedImagesAmountUncached cb

getGeneratedImagesAmountUncached = (cb) ->
    # ok, lets query that crap
    await fs.readdir PathConstants.dataDir, defer err, files
    return cb err if err
    imageCount = files.reduce ((n, file) -> n + (file[-4..] is '.png')), 0

    # yay, report back
    cb null, imageCount

    # and lets cache that shit for like 10 sec
    RedisCache.storeInCache 10, 'image-count', imageCount

ImageCountEventEmitter = new EventEmitter()
tryEmitNewImageCountEvent = () ->
    await getGeneratedImagesAmountUncached defer err, newImageCount
    return logger.err {err: err}, 'failed to fetch image count from disk' if err
    ImageCountEventEmitter.emit('image-count', newImageCount)
registerImageCountEventHandler = (handler) -> ImageCountEventEmitter.on('image-count', handler)
unregisterImageCountEventHandler = (handler) -> ImageCountEventEmitter.off('image-count', handler)

module.exports =
    create: createOsuScoreBadge
    getGeneratedImagesAmount: getGeneratedImagesAmount
    isValidScoreObj: isValidScoreObj
    isValidBeatmapObj: isValidBeatmapObj
    isValidModAmount: isValidModAmount
    init: init
    IMAGE_WIDTH: IMAGE_WIDTH
    IMAGE_HEIGHT: IMAGE_HEIGHT
    tryEmitNewImageCountEvent: tryEmitNewImageCountEvent
    registerImageCountEventHandler: registerImageCountEventHandler
    unregisterImageCountEventHandler: unregisterImageCountEventHandler
