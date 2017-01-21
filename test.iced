#!/usr/bin/env iced
OsuScoreBadgeCreator = require './OsuScoreBadgeCreator'
path = require 'path'
fs = require 'fs'

# constants
paths =
    dataDir : path.resolve 'data-test'
    inputDir : path.resolve 'input'

# init the thing
await OsuScoreBadgeCreator.init paths.inputDir, paths.dataDir, config.get('osu-api-key'), defer err
throw err if err


await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, amount
throw err if err
console.log amount


MODE = process.env.MODE || 0
USERNAME = process.env.USERNAME || 'oliebol'
BEATMAP_ID = process.env.BEATMAP_ID

return console.error 'no input' if not BEATMAP_ID

await OsuScoreBadgeCreator.create MODE, USERNAME, BEATMAP_ID, defer err, id
return console.error err.message if err

# hehehe
pngFile = path.resolve paths.dataDir, id + '.png'
outFile = path.resolve paths.dataDir, 'out.png'
jsonFile = path.resolve paths.dataDir, id + '.json'

fs.unlinkSync jsonFile
fs.rename pngFile, outFile

console.log 'success!', id
