gm = require 'gm'
fs = require 'fs'
path = require 'path'
uuidV4 = require 'uuid/v4'
RedisCache = require './RedisCache'

# constants
COLOR1 = '#eee'
COLOR2 = '#f6a'
COLOR3 = '#EA609B'
COLOR_BLUR = '#000'
COLOR3_STROKE = '#fff'

# runtime "constants"
MODS_AVAILABLE = []
MOD_NAMES = {}
IMAGE_SOURCE_DIR = null
IMAGE_DATA_DIR = null
MODS_DIR = null
HITS_DIR = null
RANKINGS_DIR = null
FONTS = {}

initStuff = (src, dest, done) ->
    IMAGE_SOURCE_DIR = src
    IMAGE_DATA_DIR = dest

    # some dirs
    MODS_DIR = path.resolve IMAGE_SOURCE_DIR, 'mods'
    HITS_DIR = path.resolve IMAGE_SOURCE_DIR, 'hit'
    RANKINGS_DIR = path.resolve IMAGE_SOURCE_DIR, 'ranking'

    # read mods
    await fs.readdir MODS_DIR, defer err, files
    return done err if err

    MODFILE_REGEX = /^(\d+)\.png$/
    for file in files
        result = MODFILE_REGEX.exec file
        if result
            modInt = parseInt result[1]
            await fs.readFile path.resolve(MODS_DIR, modInt+'.txt'), { encoding: 'utf8' }, defer err, modName
            return done err if err
            MODS_AVAILABLE.push modInt
            MOD_NAMES[modInt] = modName.trim()
    MODS_AVAILABLE.sort (a,b) -> a-b

    # read fonts
    await fs.readdir(path.resolve(IMAGE_SOURCE_DIR, 'fonts'), defer err, files)
    return done err if err

    FONTFILE_REGEX = /^Exo2\-(.+)\.ttf$/
    for file in files
        result = FONTFILE_REGEX.exec file
        if result
            FONTS[result[1]] = path.resolve IMAGE_SOURCE_DIR, 'fonts', file

    return done()


zeroFillAndAddSpaces = (number, width) ->
    number = number.toString()
    width -= number.length
    while width > 0
        number = '0' + number
        --width
    return number.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')

getStdAcc = (score) ->
    total = +score.countmiss + +score.count50 + +score.count100 + +score.count300
    return 0 if total is 0
    points = score.count50*50 + score.count100*100 + score.count300*300
    return points / (total * 300)

getTaikoAcc = (score) ->
    total = +score.countmiss + +score.count100 + +score.count300
    return 0 if total is 0
    points = (+score.count100) + (score.count300*2)
    return points / (total * 2)

getCtbAcc = (score) ->
    points = +score.count50 + +score.count100 + +score.count300
    total = +score.countmiss + points + +score.countkatu
    return 0 if total is 0
    return points/total

getManiaAcc = (score) ->
    total = +score.countmiss + +score.count50 + +score.count100 + +score.countkatu + +score.count300 + +score.countgeki
    return 0 if total is 0
    points = score.count50*50 + score.count100*100 + score.countkatu*200 + score.count300*300 + score.countgeki*300
    return points / (total * 300)

GET_ACC_FUNCTIONS = [getStdAcc, getTaikoAcc, getCtbAcc, getManiaAcc]
getAcc = (mode, score) ->
    func = GET_ACC_FUNCTIONS[mode]
    acc = if func then func(score) else 0
    return (acc*100).toFixed 2


####################
# [A] xxx  [D] xxx #
# [B] xxx  [E] xxx #
# [C] xxx  [F] xxx #
####################

drawStdHitCounts = (img, score) ->
    img.drawText(215, 123, score.count300 + 'x')   # A - 300
        .drawText(215, 163, score.count100 + 'x')  # B - 100
        .drawText(215, 203, score.count50 + 'x')   # C - 50
        .drawText(365, 123, score.countgeki + 'x') # D - 300g
        .drawText(365, 163, score.countkatu + 'x') # E - 100k
        .drawText(365, 203, score.countmiss + 'x') # F - miss

drawTaikoHitCounts = (img, score) ->

    img.drawText(215, 123, (score.count300 - score.countgeki) + 'x')   # A - great part 1 (greats - geki)
        .drawText(215, 163, (score.count100 - score.countkatu) + 'x')  # B - good part 1 (goods - katu)
        .drawText(215, 203, score.countmiss + 'x') # C - miss
        .drawText(365, 123, score.countgeki + 'x') # D - great part 2 (geki)
        .drawText(365, 163, score.countkatu + 'x') # E - good part 2 (katu)
    # F - non existend

drawCtbHitCounts = (img, score) ->
    img.drawText(215, 123, score.count300 + 'x')   # A - 300
        .drawText(215, 163, score.count100 + 'x')  # B - 100
        .drawText(215, 203, score.count50 + 'x')   # C - 50 (droplets)
        .drawText(365, 123, score.countmiss + 'x') # D - miss
    # E - non existend
    # F - non existend

drawManiaHitCounts = (img, score) ->
    img.drawText(215, 123, score.count300 + 'x')   # A -
        .drawText(215, 163, score.countkatu + 'x') # B
        .drawText(215, 203, score.count50 + 'x')   # C
        .drawText(365, 123, score.countgeki + 'x') # D
        .drawText(365, 163, score.count100 + 'x')  # E
        .drawText(365, 203, score.countmiss + 'x') # F

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

    acc = getAcc mode, score

    # draw acc
    img.fontSize(48)
        .drawText(461, 136, zeroFillAndAddSpaces(score.score, 8))

        .font(FONTS.Regular)

        # draw acc
        .fontSize(60)
        .drawText(551, 201, acc + '%%')

    # beatmap.max_combo could be "null", in that case, dont draw it
    # and draw the actual combo a bit lower
    comboOffset = if beatmap.max_combo then 0 else 15
    # draw combo
    img.fontSize(32)
        .drawText(451, 176 + comboOffset, score.maxcombo + 'x')

    if beatmap.max_combo
        img.fontSize(22).drawText(456, 206, '/' + beatmap.max_combo + 'x')

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
    # if PF (Perfect = 16384) is there, dont show SD (SuddenDeath = 32)
    mods &= ~32 if (mods & 16384) is 16384
    # if NC (Nightcore = 512) is there, dont show DT (DoubleTime = 64)
    mods &= ~64 if (mods & 512) is 512

    modsArr = []
    for mod in MODS_AVAILABLE
        modsArr.push mod if (mods & mod) is mod

    for mod, i in modsArr
        drawMod img, mod, i, modsArr.length

drawMod = (img, mod, i, totalSize) ->
    x = (12.5*totalSize)+25 - (i * 20)
    if x < 0
        throw new Error 'Render error: too many mods to draw'
    img.draw "image Over #{x},195 0,0 #{MODS_DIR}/#{mod}.png"


SCORE_OBJ_REQ_PROPS = ['date', 'enabled_mods', 'rank', 'count50', 'count100', 'count300', 'countmiss', 'countkatu', 'countgeki', 'score', 'maxcombo', 'username']
isValidScoreObj = (obj) -> SCORE_OBJ_REQ_PROPS.every (x) -> x of obj

BEATMAP_OBJ_REQ_PROPS = ['beatmapset_id', 'max_combo', 'title', 'artist', 'creator', 'version']
isValidBeatmapObj = (obj) -> BEATMAP_OBJ_REQ_PROPS.every (x) -> x of obj

toModsStr = (mods) ->
    str = []
    for mod in MODS_AVAILABLE
        if (mods & mod) is mod
            str.push '+' + MOD_NAMES[mod]
    return str.join ' '

# input objects must be "correct"
# check with isValidScoreObj/isValidBeatmapObj
# otherwise shit will fail
createOsuScoreBadge = (bgImg, beatmap, gameMode, score, done) ->
    # make sure gameMode is a number
    gameMode = +gameMode

    # crazy hacky stuff to transform the osu-api date (which is in +8 timesone) to an UTC date, with the string " UTC" added to it
    score.dateUTC = new Date(score.date.replace(' ', 'T')+'+08:00').toISOString().replace(/T/, ' ').replace(/\..+/, '') + ' UTC'

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

    # generate an unique id
    id = uuidV4()
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

    # hype, we're done, return the id
    return done null, id

getGeneratedImagesAmount = (done) ->
    await RedisCache.get 'image-count', defer err, cachedResult
    return done err if err
    return done null, parseInt cachedResult if cachedResult # yay cache exists

    # ok, lets query that crap
    await fs.readdir IMAGE_DATA_DIR, defer err, files
    return done err if err
    imageCount = files.filter((n) -> n[-4..] is '.png').length

    # yay, report back
    done null, imageCount

    # and lets cache that shit for like 10 sec
    RedisCache.storeInCache 10, 'image-count', imageCount

module.exports =
    init: initStuff
    create: createOsuScoreBadge
    getGeneratedImagesAmount: getGeneratedImagesAmount
    toModsStr: toModsStr
    getAcc: getAcc
    isValidScoreObj: isValidScoreObj
    isValidBeatmapObj: isValidBeatmapObj
