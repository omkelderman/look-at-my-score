config = require 'config'
gm = require 'gm'
fs = require 'fs'
path = require 'path'
RedisCache = require './RedisCache'
PathConstants = require './PathConstants'
OsuMods = require './OsuMods'
OsuAcc = require './OsuAcc'

# constants
COLOR1 = '#eee'
COLOR2 = '#f6a'
COLOR3 = '#EA609B'
COLOR_BLUR = '#000'
COLOR3_STROKE = '#fff'

COLOR_WATERMARK = '#ccc'
COLOR_WATERMARK_BLUR = '#000'

# read fonts
FONTFILE_REGEX = /^Exo2\-(.+)\.ttf$/
FONTS = {}
for file in fs.readdirSync path.resolve PathConstants.inputDir, 'fonts'
    result = FONTFILE_REGEX.exec file
    if result
        FONTS[result[1]] = path.resolve PathConstants.inputDir, 'fonts', file

# read overlays
OVERLAYS = {}
for file in fs.readdirSync path.resolve PathConstants.inputDir, 'overlay'
    if file.endsWith '.png'
        OVERLAYS[file[...-4]] = path.resolve PathConstants.inputDir, 'overlay', file

# read rankings
RANKINGS = {}
for file in fs.readdirSync path.resolve PathConstants.inputDir, 'ranking'
    if file.endsWith '.png'
        RANKINGS[file[...-4]] = path.resolve PathConstants.inputDir, 'ranking', file

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

drawAllTheText = (img, beatmap, mode, score, accStr, blurColor) ->
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

    img.fill(if blurColor then COLOR_BLUR else COLOR1)
        .fontSize(22)
        .font(FONTS.Italic)
        .drawText(190, 85, escapeText(beatmap.version))

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

        if accStr is '100.00' # SS
            ppTextX += 10

        # draw logic
        img.font FONTS.ExtraBold
            .fill(if blurColor then COLOR3_STROKE else COLOR3)
        if not blurColor
            img.stroke COLOR3_STROKE, 1
        img.fontSize 32
            .drawText ppValueX, 136, ppNumber.toFixed 2
            .font FONTS.ExtraBoldItalic
            .fontSize 62
        if not blurColor
            img.stroke COLOR3_STROKE, 4
        img.drawText ppTextX, 200, 'PP'
        if not blurColor
            img.stroke ''

drawMods = (img, mods) ->
    modsArr = OsuMods.bitmaskToModArray mods
    for mod, i in modsArr
        drawMod img, mod, i, modsArr.length

drawMod = (img, mod, i, totalSize) ->
    x = (12.5*totalSize)+25 - (i * 20)
    if x < 0
        throw new Error 'Render error: too many mods to draw'
    img.draw "image Over #{x},195 0,0 #{OsuMods.getImagePath(mod)}"

# pp is optional, if not provided it'll simply not be shown
# rank is optional, if not provided it'll be calculated
SCORE_OBJ_REQ_PROPS = ['date', 'enabled_mods', 'count50', 'count100', 'count300', 'countmiss', 'countkatu', 'countgeki', 'score', 'maxcombo', 'username']
isValidScoreObj = (obj) -> SCORE_OBJ_REQ_PROPS.every (x) -> x of obj

BEATMAP_OBJ_REQ_PROPS = ['max_combo', 'title', 'artist', 'creator', 'version']
isValidBeatmapObj = (obj) -> BEATMAP_OBJ_REQ_PROPS.every (x) -> x of obj

createGmDrawCommandChain = (bgImg, beatmap, gameMode, score) ->
    # calc some shit and fetch some additional details
    overlayImagePath = OVERLAYS[gameMode]
    throw new Error "Render error: unknown gamemode '#{gameMode}'" if not overlayImagePath
    enabled_mods = +score.enabled_mods
    acc = OsuAcc.getAcc gameMode, score
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
    drawAllTheText img, beatmap, gameMode, score, accStr, true

    # blur it
    img.blur(0,4.3)

    # add black
    img.fill('#0007').drawRectangle 0, 0, 900, 250

    # draw all the text again, but now for real
    drawAllTheText img, beatmap, gameMode, score, accStr, false

    # lets draw some additional bits
    rankingOffset = if enabled_mods is 0 then 40 else 20

    img
        # draw the rank
        .draw("image Over 0,#{rankingOffset} 0,0 #{rankingImagePath}")

        # and draw the "hit-objects" and mode-icon
        .draw("image Over 0,0 0,0 #{overlayImagePath}")

    # add mods
    drawMods img, enabled_mods

    return img

# input objects must be "correct"
# check with isValidScoreObj/isValidBeatmapObj
# otherwise shit will fail
createOsuScoreBadge = (bgImg, beatmap, gameMode, score, outputFile, done) ->
    # make sure gameMode is a number
    gameMode = +gameMode

    try
        img = createGmDrawCommandChain bgImg, beatmap, gameMode, score
    catch imgCreateError
        return done imgCreateError


    # write png file
    img.write outputFile, done

getGeneratedImagesAmount = (done) ->
    await RedisCache.get 'image-count', defer isInCache, cachedResult
    return done null, cachedResult if isInCache # yay cache exists

    # ok, lets query that crap
    await fs.readdir PathConstants.dataDir, defer err, files
    return done err if err
    imageCount = files.reduce ((n, file) -> n + (file[-4..] is '.png')), 0

    # yay, report back
    done null, imageCount

    # and lets cache that shit for like 10 sec
    RedisCache.storeInCache 10, 'image-count', imageCount

module.exports =
    create: createOsuScoreBadge
    getGeneratedImagesAmount: getGeneratedImagesAmount
    isValidScoreObj: isValidScoreObj
    isValidBeatmapObj: isValidBeatmapObj
