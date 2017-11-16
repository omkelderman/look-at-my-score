readBuffer = (stream, size) ->
    buf = stream.read size
    throw new Error 'unexpected file-end' if not buf or buf.length isnt size
    return buf
readUintX = (stream, size) -> readBuffer(stream, size).readUIntLE 0, size
readUInt8 = (stream) -> readUintX stream, 1
readUInt16 = (stream) -> readUintX stream, 2
readUInt32 = (stream) -> readUintX stream, 4
readULEB128 = (stream) ->
    result = 0
    shift = 0
    while true
        b = readUInt8 stream
        result |= (b & 0x7F) << shift
        break if (b & 0x80) isnt 0x80
        shift += 7
    return result
readOsuString = (stream) ->
    b = readUInt8 stream
    return null if b is 0
    throw new Error 'unexpected byte' if b isnt 0x0b
    len = readULEB128 stream
    return '' if len is 0
    # extra safety messure, error out on too long strings to avoid eating up memory on malicious input
    throw new Error 'too long string: ' + len if len > 25600
    bytes = readBuffer stream, len
    return bytes.toString()
readBoolean = (stream) -> readUInt8(stream) isnt 0

# alright, lots of weird crap ahead
# reason for that is that we have 8 bytes which together are a uint64
# that number represents the "windows tick" value of a c# date object
# javascript cannot acurately handle such a big number, it only can
# accurately display numbers up to ((2^53)-1), see https://stackoverflow.com/q/307179/1934465
# so what's happening here is lots of weird shit to calculate a javascript date object
# without any number during the calculation ever have the possibility of going over that number
WEIRD_CONSTANT = 429.4967296 # (2^32)/(10^7)
TICKS_PER_SECOND = 10000000 # (10^7)
SECONDS_ON_EPOCH_SINCE_TICKS_START = 62135596800
readDate = (stream) ->
    buf = readBuffer stream, 8
    low = buf.readUInt32LE 0
    high = buf.readUInt32LE 4

    # magic:
    epochSeconds = high * WEIRD_CONSTANT
    epochSeconds -= SECONDS_ON_EPOCH_SINCE_TICKS_START
    epochSeconds += low / TICKS_PER_SECOND

    return new Date(epochSeconds*1000)

parseOsrFileHeaderFromStream = (stream) ->
    osr = {}
    osr.gameMode = readUInt8 stream
    osr.gameVersion = readUInt32 stream
    osr.beatmapMd5 = readOsuString stream
    osr.username = readOsuString stream
    osr.replayMd5 = readOsuString stream
    osr.count300 = readUInt16 stream
    osr.count100 = readUInt16 stream
    osr.count50 = readUInt16 stream
    osr.countgeki = readUInt16 stream
    osr.countkatu = readUInt16 stream
    osr.countmiss = readUInt16 stream
    osr.score = readUInt32 stream
    osr.maxCombo = readUInt16 stream
    osr.isFullCombo = readBoolean stream
    osr.modsBitmask = readUInt32 stream
    osr.lifeBar = readOsuString stream
    osr.date = readDate stream
    osr.dataLenght = readUInt32 stream
    osr.dataPayload = null
    return osr

class MulterOsrMemoryStorage
    _handleFile: (req, file, cb) ->
        # handle errors
        file.stream.once 'error', (err) -> cb err

        # start reading bytes
        await file.stream.once 'readable', defer()
        try
            data = parseOsrFileHeaderFromStream file.stream
        catch err
            return cb err

        # we've read everything we need, let the thing drain further so the request can complete
        file.stream.resume()

        cb null, osrData: data

    # remove is a no-op
    _removeFile: (req, file, cb) -> cb()

module.exports = MulterOsrMemoryStorage
