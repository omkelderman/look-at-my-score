express = require 'express'
OsuMods = require '../OsuMods'
CoverCache = require '../CoverCache'
config = require 'config'
_ = require './_shared'

router = express.Router()

router.use (req, res, next) ->
    res.locals.gaCode = config.get 'gaCode'
    next()

router.get '/', (req, res, next) ->
    res.render 'pages/home',
        mods: OsuMods.allById

router.get '/about', (req, res) ->
    res.render 'pages/about'

router.get '/how-it-works', (req, res) ->
    res.render 'pages/how-it-works'

router.get '/how-it-works/technical', (req, res) ->
    res.render 'pages/how-it-works/technical'

router.get '/history', (req, res) ->
    res.render 'pages/history'

router.get '/contact', (req, res) ->
    res.render 'pages/contact',
        info: req.query

router.get '/cover/:id([0-9]+).jpg', (req, res, next) ->
    await CoverCache.grabCoverFromOsuServer req.params.id, defer err, cover
    return next _.coverError err if err
    res.sendFile cover

module.exports = router
