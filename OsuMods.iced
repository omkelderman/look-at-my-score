path = require 'path'
fs = require 'fs'
Util = require './Util'
PathConstants = require './PathConstants'

MODS_DIR = path.resolve PathConstants.inputDir, 'mods'

MODS_AVAILABLE = []
MOD_NAMES = {}
MOD_PATHS = {}

IMAGE_WIDTH = 48
IMAGE_HEIGHT = 47

init = (cb) ->
    # read mods
    MODFILE_REGEX = /^(\d+)\.png$/
    await fs.readdir MODS_DIR, defer err, fileList
    return cb err if err
    for file in fileList
        result = MODFILE_REGEX.exec file
        if result
            modInt = parseInt result[1]
            await fs.readFile path.resolve(MODS_DIR, modInt+'.txt'), { encoding: 'utf8' }, defer err, modName
            return cb err if err
            modFilePath = path.resolve MODS_DIR, file
            await Util.checkImageSize modFilePath, IMAGE_WIDTH, IMAGE_HEIGHT, defer err, sizeOk
            return cb err if err
            if not sizeOk
                return cb new Error("File '#{modFilePath}' does not have the correct size")
            MODS_AVAILABLE.push modInt
            MOD_NAMES[modInt] = modName.trim()
            MOD_PATHS[modInt] = modFilePath
    MODS_AVAILABLE.sort (a,b) -> a-b
    cb null

bitmaskToModArray = (mods) ->
    # if PF (Perfect = 16384) is there, dont show SD (SuddenDeath = 32)
    mods &= ~32 if (mods & 16384) is 16384
    # if NC (Nightcore = 512) is there, dont show DT (DoubleTime = 64)
    mods &= ~64 if (mods & 512) is 512

    return MODS_AVAILABLE.filter (mod) -> (mods & mod) is mod

module.exports =
    bitmaskToModArray: bitmaskToModArray
    allById: MOD_NAMES
    toModsStrLong: (mods) -> bitmaskToModArray(mods).map((m) -> '+' + MOD_NAMES[m]).join(' ')
    getImagePath: (m) -> MOD_PATHS[m]
    init: init
    IMAGE_WIDTH: IMAGE_WIDTH
    IMAGE_HEIGHT: IMAGE_HEIGHT