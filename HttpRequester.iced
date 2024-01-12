# this module is used in the logger logic, so we're not allowed to use the logger here

util = require 'util'
zlib = require 'zlib'
http = require 'http'
https = require 'https'
fs = require 'fs'

class HttpRequester
    constructor: (urlTemplate, @httpTimeout) ->
        if urlTemplate.startsWith 'http://'
            @thing = http
        else if urlTemplate.startsWith 'https://'
            @thing = https
        else
            throw new Error 'urlTemplate must start with http:// or https://'
        @urlTemplate = urlTemplate
        @defaultHeaders =
            'Accept-Encoding': 'br, gzip, deflate, identity'

    _do200Request: (method, urlParts, headers, allow404result, requestData, cb) ->
        reqOptions = 
            method: method
            headers: Object.assign {}, @defaultHeaders, headers
            timeout: @httpTimeout
        url = util.format @urlTemplate, urlParts...
        req = @thing.request url, reqOptions, (res) ->
            if res.statusCode is 404 and allow404result
                res.resume() # discard response
                return cb null, null, url
            if res.statusCode isnt 200
                res.resume() # discard response
                return cb new Error "Unexpected http response #{res.statusCode} #{res.statusMessage}"

            contentEncoding = res.headers['content-encoding']
            switch contentEncoding
                when 'identity', undefined
                    stream = res
                when 'gzip'
                    stream = res.pipe zlib.createGunzip()
                when 'br'
                    stream = res.pipe zlib.createBrotliDecompress()
                when 'deflate'
                    stream = res.pipe zlib.createInflate()
                else
                    return cb new Error "Unexpected content-encoding #{contentEncoding}"
            
            cb null, stream, url
        req.once 'error', (err) -> cb err
        req.write requestData if requestData
        req.end()
    
    saveFile: (urlParts, localPath, cb) ->
        @_do200Request 'GET', urlParts, {}, true, null, (err, stream, url) ->
            return cb err if err

            return cb null, false, url if stream is null

            stream.once 'error', (err) -> cb err

            file = fs.createWriteStream localPath
            file.once 'error', (err) -> cb err
            file.once 'finish', () -> cb null, true, url

            stream.pipe file
    
    _getOrPostJson: (method, urlParts, headers, requestData, cb) ->
        @_do200Request method, urlParts, headers, false, requestData, (err, stream, url) ->
            return cb err if err

            chunks = []
            totalDataLenght = 0
            stream.once 'error', (err) -> cb err
            stream.once 'end', () ->
                strData = Buffer.concat(chunks, totalDataLenght).toString()
                try
                    data = JSON.parse strData
                catch err
                    return cb err
                cb null, data, url
            stream.on 'data', (chunk) ->
                chunks.push chunk
                totalDataLenght += chunk.length
    
    postJson: (urlParts, postData, cb) ->
        requestData = Buffer.from JSON.stringify postData
        headers =
            'Content-Type': 'application/json'
            'Content-Length': requestData.length
        @_getOrPostJson 'POST', urlParts, headers, requestData, cb

    getJson: (urlParts, cb) -> @_getOrPostJson 'GET', urlParts, {}, null, cb

module.exports = HttpRequester;