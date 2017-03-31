(function($) {

    $.fn.allInputUpdate = function(eventHandler) {
        var elem = $(this);

        // Save current value of element
        elem.data('oldVal', elem.val());

        // Look for changes in the value
        elem.bind('propertychange change keyup input paste customset', function(event){
            // If value has not changed...
            if (elem.data('oldVal') === elem.val()) return;

            // Value has changed, store updated value
            elem.data('oldVal', elem.val());

            // handle event
            if($.isFunction(eventHandler)) eventHandler(event);
        });

        return elem;
    };

    $.fn.customSet = function(val) {
        return $(this).val(val).trigger('customset');
    };

}(jQuery));


var $frm = $('#form');
var $submitBtn = $('#submit-btn');
var $result = $('#result');
var $resultImg = $('#resultImg');
var $progressBar = $('#progressBar');
var $resultText = $('#resultText');
var $goBackBtn = $('#go-back-btn');
var $sampleImg = $('#sample-img');
var $contactMe = $('#contact-me');
var $imageCount = $('#image-count');
var $chooseScoreBox = $('#choose-score');
var $chooseScoreBtnGroup = $('#choose-score-btn-group');
var $manualBeatmapSelect = $('#manual-beatmap-select');
var $autoBeatmapSelect = $('#auto-beatmap-select');

// inputs
var $inputUsername = $('#username');
var $inputBeatmapUrl = $('#beatmap_url');
var $inputBeatmapId = $('#beatmap_id');
var $inputMode = $('#mode');

var imageCounterUpdaterIntervalId = 0;

function incrementImageCounter() {
    $imageCount.text(+$imageCount.text()+1);
}

function updateImageCounter() {
    if(document.visibilityState !== 'visible') {
        // not visible? no need to update
        return;
    }
    $.getJSON('/api/image-count', function(data) {
        if(data > +$imageCount.text()) {
            console.log('new image count', data);
            $imageCount.text(data);
        }
    });
}

function startImageCounterUpdate() {
    imageCounterUpdaterIntervalId = setInterval(updateImageCounter, 10000); // 10 sec
}

function stopImageCounterUpdate() {
    clearInterval(imageCounterUpdaterIntervalId);
}

function fillScoresMenu(data) {
    console.log('multiScoreResult', data);
    $chooseScoreBtnGroup.empty();
    $chooseScoreBtnGroup.data('beatmap-id', data.beatmap_id);
    $chooseScoreBtnGroup.data('mode', data.mode);
    for(var i=0; i < data.scores.length; ++i) {
        $chooseScoreBtnGroup.append($('<div>')
            .addClass('btn-group')
            .append(
                $('<button>')
                    .data('score', data.scores[i])
                    .attr('type', 'button')
                    .addClass('btn btn-default')
                    .click(handleChooseScore)
                    //.text((+score.pp).toFixed(2) + ' pp')
                    .text(data.texts[i])
            )
        );
    }
}

$frm.submit(function(e) {
    e.preventDefault();
    $submitBtn.prop('disabled', true);
    $frm.slideUp();
    $sampleImg.slideUp();
    $result.slideDown();
    $resultImg.hide();
    $progressBar.show();
    $resultText.val('fetching data and generating image...');
    stopImageCounterUpdate();
    doThaThing($frm.serialize());
});

function handleChooseScore(e) {
    e.preventDefault();
    var $this = $(this);
    $this.parent().parent().find('button').prop('disabled', true);

    var data = {
        beatmap_id: $chooseScoreBtnGroup.data('beatmap-id'),
        mode: $chooseScoreBtnGroup.data('mode'),
        score: $this.data('score')
    };
    console.log('requesting score', data);

    // do request with custom score
    $chooseScoreBox.slideUp();
    $progressBar.show();
    $resultText.val('fetching data and generating image...');
    $submitBtn.prop('disabled', true);
    doThaThing(data);
}

function doThaThing(data) {
    $.ajax({
        type: $frm.attr('method'),
        url: $frm.attr('action'),
        data: data,
        success: function(data) {
            console.log('SUCCES!', data);
            if(data.result === 'image') {
                var imgSrc = data.image.url;
                $resultImg.attr('src', imgSrc).show();
                $resultText.val(imgSrc);
                $contactMe.attr('href', '/contact?img-id=' + data.image.id);
                incrementImageCounter();
            } else if (data.result === 'multiple-scores') {
                console.log('welp, multiple scores');
                $resultText.val('There are multiple scores, please choose one!');
                fillScoresMenu(data.data);
                $chooseScoreBox.slideDown();
            } else {
                console.log('ERROR: unexpected result:', data.result);
                $resultText.val('ERROR: If this message appears, I forgot to implement something.... ooops, please contact me, thanks :D');
                $contactMe.attr('href', '/contact?error=non-implemented-resulti&result=' + data.result);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            var error = jqXHR.responseJSON;
            console.error('ERROR', error)
            if(error) {
                $resultText.val('ERROR, im sorry, something went wrong... The server reported: \'' + error.detailMessage + '\'');
                $contactMe.attr('href', '/contact?error=' + error.status);
            } else {
                $resultText.val('ERROR, im sorry, something went wrong...');
                $contactMe.attr('href', '/contact?error=unknown');
            }
        },
        complete: function() {
            $progressBar.hide();
            $submitBtn.prop('disabled', false);
        },
    });
}

$goBackBtn.click(function(e) {
    console.log('hahaha')
    e.preventDefault();
    $frm.slideDown()
    $result.slideUp();
    $chooseScoreBox.slideUp();

    startImageCounterUpdate();
});

function validateInput(e) {
    e.preventDefault();
    var inputIsValid = true;

    if($inputUsername.val().length == 0) {
        // username cannot be empty
        inputIsValid = false;
    }

    if(!/^[0-9]+$/.test($inputBeatmapId.val())) {
        // beatmap id can only contain numbers
        inputIsValid = false;
    }

    if($inputMode.val() < 0 || $inputMode.val() > 4) {
        // invalid gamemode
        inputIsValid = false;
    }

    $submitBtn.prop('disabled', !inputIsValid);
}

// listen to a shitton of events to make sure we catch every change as early as possible
$inputUsername.allInputUpdate(validateInput);
$inputBeatmapId.allInputUpdate(validateInput);
$inputMode.allInputUpdate(validateInput);
$inputBeatmapUrl.allInputUpdate(function(e) {
    var value = parseBeatmapUrl($inputBeatmapUrl.val());
    if(value.isValid) {
        if(value.s) {
            alert('WIP: handle /s/-urls');
            // TODO: handle /s/-urls
            // reset for now
            $inputBeatmapId.customSet('');
            $inputMode.customSet('0');
        } else {
            // hype, URL is parsed!
            console.log('valid input:', value);
            $inputBeatmapId.customSet(value.b);
            $inputMode.customSet(value.m);
        }
    } else {
        // TODO: show error
        // set back to default values
        $inputBeatmapId.customSet('');
        $inputMode.customSet('0');
    }
});

function parseBeatmapUrl(string) {
    if(typeof string !== 'string' || string.length === 0) {
        // no string, or empty string
        return {
            isValid: false,
            error: 'empty'
        };
    }

    // [http[s]://]osu.ppy.sh/[b|s]/123456[[?|&]m=0]
    var oldSite1Result = /^(?:https?\:\/\/)?osu\.ppy\.sh\/(b|s)\/([0-9]+)(?:(?:\?|&)m=([0-3]))?$/.exec(string);
    if(oldSite1Result) {
        var obj = {
            isValid: true,
            m: oldSite1Result[3] || '0'
        };
        obj[oldSite1Result[1]] = oldSite1Result[2];
        return obj;
    }

    // [http[s]://]osu.ppy.sh/p/beatmap?b=123456[?m=0]
    var oldSite2Result = /^(?:https?\:\/\/)?osu\.ppy\.sh\/p\/beatmap\?b=([0-9]+)(?:&m=([0-3]))?$/.exec(string);
    if(oldSite2Result) {
        return {
            isValid: true,
            b: oldSite2Result[1],
            m: oldSite2Result[2] || '0'
        };
    }

    // [http[s]://]new.ppy.sh/beatmapsets/123456#[osu|taiko|fruits|mania]/123456
    var newSiteResult = /^(?:https?\:\/\/)?new\.ppy\.sh\/beatmapsets\/[0-9]+#(osu|taiko|fruits|mania)\/([0-9]+)$/.exec(string);
    if(newSiteResult) {
        return {
            isValid: true,
            b: newSiteResult[2],
            m: ['osu', 'taiko', 'fruits', 'mania'].indexOf(newSiteResult[1])
        }
    }

    return {
        isValid: false,
        error: 'invalid'
    };
}

$('.toggle-beatmap-selection-style').click(function(e){
    e.preventDefault();
    $manualBeatmapSelect.slideToggle();
    $autoBeatmapSelect.slideToggle();
});

$('#sample-img a.dismiss').click(function(e){
    e.preventDefault();
    $sampleImg.slideUp();
});

$(document).ready(function() {
    $result.hide();
    $chooseScoreBox.hide();
    $manualBeatmapSelect.hide();
    $submitBtn.prop('disabled', true);

    startImageCounterUpdate();
});
