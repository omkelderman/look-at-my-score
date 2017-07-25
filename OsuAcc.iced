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
    return if func then func(score) else 0

module.exports =
    getAcc: getAcc
    getAccStr: (mode, score) -> (getAcc(mode, score)*100).toFixed 2
