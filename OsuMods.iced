PathConstants = require './PathConstants'
path = require 'path'
fs = require 'fs'
PathConstants = require './PathConstants'

MODS_DIR = path.resolve PathConstants.inputDir, 'mods'

MODS_AVAILABLE = []
MOD_NAMES = {}
MOD_PATHS = {}

# read mods
MODFILE_REGEX = /^(\d+)\.png$/
for file in fs.readdirSync MODS_DIR
    result = MODFILE_REGEX.exec file
    if result
        modInt = parseInt result[1]
        modName = fs.readFileSync path.resolve(MODS_DIR, modInt+'.txt'), { encoding: 'utf8' }
        MODS_AVAILABLE.push modInt
        MOD_NAMES[modInt] = modName.trim()
        MOD_PATHS[modInt] = path.resolve MODS_DIR, file
MODS_AVAILABLE.sort (a,b) -> a-b

bitmarkToModArray = (mods) ->
    # if PF (Perfect = 16384) is there, dont show SD (SuddenDeath = 32)
    mods &= ~32 if (mods & 16384) is 16384
    # if NC (Nightcore = 512) is there, dont show DT (DoubleTime = 64)
    mods &= ~64 if (mods & 512) is 512

    return MODS_AVAILABLE.filter (mod) -> (mods & mod) is mod

module.exports =
    bitmarkToModArray: bitmarkToModArray
    allById: MOD_NAMES
    toModsStrLong: (mods) -> bitmarkToModArray(mods).map((m) -> '+' + MOD_NAMES[m]).join(' ')
    getImagePath: (m) -> MOD_PATHS[m]
