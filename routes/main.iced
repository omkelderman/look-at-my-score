express = require 'express'
OsuScoreBadgeCreator = require '../OsuScoreBadgeCreator'
OsuMods = require '../OsuMods'
CoverCache = require '../CoverCache'
config = require 'config'
_ = require './_shared'

router = express.Router()

router.use (req, res, next) ->
    res.locals.gaCode = config.get 'gaCode'
    next()

router.get '/', (req, res, next) ->
    await OsuScoreBadgeCreator.getGeneratedImagesAmount defer err, imagesAmount
    return next err if err
    res.render 'pages/home',
        generatedImagesAmount: imagesAmount
        mods: OsuMods.allById

router.get '/contact', (req, res) ->
    res.render 'pages/contact',
        info: req.query

router.get '/cover/:id([0-9]+).jpg', (req, res, next) ->
    await CoverCache.grabCoverFromOsuServer req.params.id, defer err, cover
    return _.handleCoverError err, next if err
    res.sendFile cover

module.exports = router
