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

# runtime "constants"
IMAGE_SOURCE_DIR = PathConstants.inputDir
IMAGE_DATA_DIR = PathConstants.dataDir
HITS_DIR = path.resolve IMAGE_SOURCE_DIR, 'hit'
RANKINGS_DIR = path.resolve IMAGE_SOURCE_DIR, 'ranking'
FONTS_DIR = path.resolve IMAGE_SOURCE_DIR, 'fonts'
FONTS = {}

# read fonts
FONTFILE_REGEX = /^Exo2\-(.+)\.ttf$/
for file in fs.readdirSync FONTS_DIR
    result = FONTFILE_REGEX.exec file
    if result
        FONTS[result[1]] = path.resolve FONTS_DIR, file

addThousandSeparators = (number, character) ->
    # make sure its a string
    number = number.toString()

    # introduce spaces
    return number.replace(/\B(?=(\d{3})+(?!\d))/g, character)

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

drawAllTheText = (img, beatmap, mode, score, blurColor) ->
    img
        # draw hit-amounts
        .font(FONTS.ExtraBold)
        .fill(if blurColor then COLOR_BLUR else COLOR1)
        .fontSize(27)
    drawHitCounts img, mode, score

    acc = OsuAcc.getAccStr mode, score

    # draw acc
    img.fontSize(48)
        .drawText(461, 136, addThousandSeparators(score.score, ' '))

        .font(FONTS.Regular)

        # draw acc
        .fontSize(60)
        .drawText(551, 201, acc + '%%')

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
        .drawText(150, 40, beatmap.title)
        .fontSize(16)
        .drawText(155, 60, beatmap.artist)

        .fontSize(16)
        .drawText(150, 240, 'Mapped by:')
        .drawText(415, 240, 'Played by:')
        .drawText(680, 240, 'at')
        .fill(if blurColor then COLOR_BLUR else COLOR2)
        .drawText(702, 240, score.dateUTC)
        .fontSize(20)
        .drawText(240, 240, beatmap.creator)
        .drawText(495, 240, score.username)

    if not blurColor
        img.stroke ''

    img.fill(if blurColor then COLOR_BLUR else COLOR1)
        .fontSize(22)
        .font(FONTS.Italic)
        .drawText(190, 85, beatmap.version)

    # draw some watermark thingy
    img.fill(if blurColor then COLOR_WATERMARK_BLUR else COLOR_WATERMARK)
        .fontSize 12
        .drawText 4, 14, config.get 'watermark.text'
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

        if acc is '100.00' # SS
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
    for mod, i in OsuMods.bitmarkToModArray mods
        drawMod img, mod, i, modsArr.length

drawMod = (img, mod, i, totalSize) ->
    x = (12.5*totalSize)+25 - (i * 20)
    if x < 0
        throw new Error 'Render error: too many mods to draw'
    img.draw "image Over #{x},195 0,0 #{OsuMods.getImagePath(mod)}"

SCORE_OBJ_REQ_PROPS = ['date', 'enabled_mods', 'rank', 'count50', 'count100', 'count300', 'countmiss', 'countkatu', 'countgeki', 'score', 'maxcombo', 'username']
isValidScoreObj = (obj) -> SCORE_OBJ_REQ_PROPS.every (x) -> x of obj

BEATMAP_OBJ_REQ_PROPS = ['beatmapset_id', 'max_combo', 'title', 'artist', 'creator', 'version']
isValidBeatmapObj = (obj) -> BEATMAP_OBJ_REQ_PROPS.every (x) -> x of obj

drawAllTheThings = (bgImg, beatmap, gameMode, score) ->
    # start
    img = gm bgImg

    # draw all text for background-blur
    drawAllTheText img, beatmap, gameMode, score, true

    # blur it
    img.blur(0,4.3)

    # add black
    img.fill('#0007').drawRectangle 0, 0, 900, 250

    # draw all the text again, but now for real
    drawAllTheText img, beatmap, gameMode, score, false

    # draw the rank
    enabled_mods = +score.enabled_mods
    rankingOffset = if enabled_mods is 0 then 40 else 20
    img.draw("image Over 0,#{rankingOffset} 0,0 #{RANKINGS_DIR}/#{score.rank}.png")

        # and draw the "hit-objects"
        .draw("image Over 0,0 0,0 #{HITS_DIR}/overlay-#{gameMode}.png")

        # and draw the game-mode icon
        .draw("image Over 155,65 0,0 #{HITS_DIR}/mode-#{gameMode}.png")

    # add mods
    drawMods img, enabled_mods

    return img

# input objects must be "correct"
# check with isValidScoreObj/isValidBeatmapObj
# otherwise shit will fail
createOsuScoreBadge = (bgImg, beatmap, gameMode, score, id, done) ->
    # make sure gameMode is a number
    gameMode = +gameMode

    try
        # crazy hacky stuff to transform the osu-api date (which is in +8 timesone) to an UTC date, with the string " UTC" added to it
        score.dateUTC = new Date(score.date.replace(' ', 'T')+'+08:00').toISOString().replace(/T/, ' ').replace(/\..+/, '') + ' UTC'
    catch dateParseError
        return done dateParseError

    try
        img = drawAllTheThings bgImg, beatmap, gameMode, score
    catch imgCreateError
        return done imgCreateError

    outputFileStart = path.resolve IMAGE_DATA_DIR, id

    # write png file
    await img.write outputFileStart+'.png', defer err
    return done err if err

    # also write a json-file with the meta-data
    outputData =
        date: new Date().toISOString()
        id: id
        mode: gameMode
        beatmap: beatmap
        score: score
    await fs.writeFile outputFileStart+'.json', JSON.stringify(outputData), defer err
    return done err if err

    # hype, we're done
    return done()

getGeneratedImagesAmount = (done) ->
    await RedisCache.get 'image-count', defer err, cachedResult
    return done err if err
    return done null, cachedResult if cachedResult # yay cache exists

    # ok, lets query that crap
    await fs.readdir IMAGE_DATA_DIR, defer err, files
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
