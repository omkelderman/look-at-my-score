///////////////////////////////////
// custom jQeury extenstion shit //
///////////////////////////////////
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

    $.fn.customSet = function(val, dontTiggerEvent) {
        if(dontTiggerEvent) {
            // dont trigger set event, but do update the 'oldVal' value
            return $(this).val(val).data('oldVal', val);
        } else {
            return $(this).val(val).trigger('customset');
        }
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
var $beatmapVersionSelect = $('#beatmap-version-select');

// inputs
var $inputUsername = $('#username');
var $inputBeatmapUrl = $('#beatmap_url');
var $beatmapVersion = $('#beatmap_version');
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
    var inputIsValid = true;

    $inputUsernameFormGroup = $inputUsername.parent().parent();
    $inputBeatmapIdFormGroup = $inputBeatmapId.parent().parent();
    $inputModeFormGroup = $inputMode.parent().parent();

    var usernameInvalid = $inputUsername.val().length == 0;
    if(e.currentTarget == $inputUsername[0]) {
        $inputUsernameFormGroup.toggleClass('has-error', usernameInvalid);
    }
    if(usernameInvalid) {
        // username cannot be empty
        inputIsValid = false;
    }

    var beatmapIdInvalid = !/^[0-9]+$/.test($inputBeatmapId.val())
    if(e.currentTarget == $inputBeatmapId[0]) {
        $inputBeatmapIdFormGroup.toggleClass('has-error', beatmapIdInvalid);
    }
    if(beatmapIdInvalid) {
        // beatmap id can only contain numbers
        inputIsValid = false;
    }

    var modeInvalid = $inputMode.val() < 0 || $inputMode.val() > 4
    if(e.currentTarget == $inputMode[0]) {
        $inputModeFormGroup.toggleClass('has-error', modeInvalid);
    }
    if(modeInvalid) {
        // invalid gamemode
        inputIsValid = false;
    }

    $submitBtn.prop('disabled', !inputIsValid);
}

function clearUrlInputAndValidateInput(e) {
    if($inputBeatmapUrl.is(':hidden')) {
        // we're doing manual input, clear the url input
        $inputBeatmapUrl.customSet('', true);
    }

    // and validate ofc
    validateInput(e);
}

// listen to a shitton of events to make sure we catch every change as early as possible
$inputUsername.allInputUpdate(validateInput);
$inputBeatmapId.allInputUpdate(clearUrlInputAndValidateInput);
$inputMode.allInputUpdate(clearUrlInputAndValidateInput);
$inputBeatmapUrl.allInputUpdate(function(e) {
    var value = parseBeatmapUrl($inputBeatmapUrl.val());
    $inputBeatmapUrl.parent().parent().toggleClass('has-error', !value.isValid);
    if(value.isValid) {
        if(value.s) {
            // TODO: handle /s/-urls
            console.log('s-url', value);
            // make it appear as error for now
            //$inputBeatmapUrl.parent().parent().toggleClass('has-error', true);
            $beatmapVersionSelect.slideDown();
            handleSetUrl(value.s);
        } else {
            // hype, URL is parsed!
            console.log('valid input:', value);
            $inputBeatmapId.customSet(value.b);
            $inputMode.customSet(value.m);
            $beatmapVersionSelect.slideUp();

            // done :D
            return;
        }
    } else {
        console.log('error', value);
        $beatmapVersionSelect.slideUp();
    }

    // if we reach this, means we dont have a final value
    // set back to default values
    $inputBeatmapId.customSet('');
    $inputMode.customSet('0');
});
$beatmapVersion.allInputUpdate(function(e) {
    var value = $beatmapVersion.val().split('|');
    if(value.length != 2) {
        // not found or error
        $inputBeatmapId.customSet('');
        $inputMode.customSet('0');
        return;
    }

    // found
    $inputBeatmapId.customSet(value[0]);
    $inputMode.customSet(value[1]);
});

handleSetUrlTimeout = -1
function handleSetUrl(s) {
    $beatmapVersion.empty();
    $beatmapVersion.append($('<option>').text('loading...'))
    $beatmapVersion.data('setId', s);
    clearTimeout(handleSetUrlTimeout);
    handleSetUrlTimeout = setTimeout(function() {
        handleSetUrlForReal(s);
    }, 250);
}

function handleSetUrlForReal(s) {
    console.log('DO IT', s);
    $.ajax({
        type: 'get',
        url: '/api/diffs/' + s,
        success: function(data) {
            if($beatmapVersion.data('setId') != s) return;
            $inputBeatmapUrl.parent().parent().toggleClass('has-error', false);
            $beatmapVersion.empty();
            for(var i=0, _len = data.set.length; i<_len; ++i) {
                var version = data.set[i];
                var $option = $('<option>')
                    .text(version.version)
                    .attr('value', version.beatmap_id + '|' + version.mode)
                    .attr('selected', version.beatmap_id == data.defaultVersion);
                $beatmapVersion.append($option);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            if($beatmapVersion.data('setId') != s) return;
            var error = jqXHR.responseJSON;
            $inputBeatmapUrl.parent().parent().toggleClass('has-error', true);
            $beatmapVersion.empty();
            var $option;
            if(error.status == 404) {
                $option = $('<option>').text('Beatmap not found...');
            } else {
                $option = $('<option>').text('Something went wrong...');
            }
            $option.attr('value', '');
            $beatmapVersion.append($option);
        },
        complete: function() {
            if($beatmapVersion.data('setId') != s) return;
            console.log('complete', s)
            $beatmapVersion.trigger('change');
        }
    });
}

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

$('.toggle-beatmap-selection-style > a').click(function(e){
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
    $beatmapVersionSelect.hide();
    $submitBtn.prop('disabled', true);

    startImageCounterUpdate();
});
