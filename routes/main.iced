express = require 'express'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'
OsuMods = require '../OsuMods'

router = express.Router()

router.get '/', (req, res, next) ->
    await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, imagesAmount
    return next err if err
    res.render 'pages/home',
        generatedImagesAmount: imagesAmount
        mods: OsuMods.allById

router.get '/contact', (req, res) ->
    res.render 'pages/contact',
        info: req.query

module.exports = router
