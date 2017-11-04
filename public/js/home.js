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
var $sampleImg = $('#sample-img');
var $imageCount = $('#image-count');
var $chooseScoreBox = $('#choose-score');
var $chooseScoreBtnGroup = $('#choose-score-btn-group');
var $beatmapVersionSelect = $('#beatmap-version-select');
var $manualScoreSelect = $('#manual-score-select');
var $modsManualInput = $('#mods-manual-input');
var $modsCheckboxesInput = $('#mods-checkboxes-input');
var $allThemModCheckboxes = $('#mods-checkboxes-input :checkbox');

// result
var $result = $('#result');
var $resultOk = $('#result-ok');
var $resultError = $('#result-error');
var $resultImg = $('#result-img');
var $progressBar = $('#progress-bar');
var $resultText = $('#result-text');
var $resultErrorText = $('#result-error-text');
var $goBackBtn = $('#go-back-btn');
var $contactMe = $('#contact-me');

// map display
var $mapDisplayComment = $('#map-display-comment');
var $mapDisplayImage = $('#map-display-image');
var $mapDisplay = $('#map-display');
var $mapDisplayMode = $('#map-mode');
var $mapDisplayModeComment = $('#map-mode-comment');
var $mapDisplayArtist = $('#map-artist');
var $mapDisplayTitle = $('#map-title');
var $mapDisplayVersion = $('#map-version');
var $mapDisplayCreator = $('#map-creator');

// inputs
var $inputUsername = $('#username');
var $inputBeatmapUrl = $('#beatmap_url');
var $beatmapVersion = $('#beatmap_version');
var $beatmapVersionMessage = $('#beatmap_version_message');
var $inputBeatmapId = $('#beatmap_id');
var $inputMode = $('#mode');
var $checkboxOverrideMode = $('#override-mode');

var $inputScoreEnabledMods = $('#score_enabled_mods');


var MODES = ['osu!', 'osu!taiko', 'osu!catch', 'osu!mania'];

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
                    .addClass('btn btn-default score-btn')
                    .click(handleChooseScore)
                    .text(data.texts[i])
            )
        );
    }
}

function setOverrideGamemode(override) {
    console.log('setOverrideGamemode', override);
    $inputMode.prop('disabled', !override);
    $inputMode.css('visibility', override ? 'visible' : 'hidden');

    $checkboxOverrideMode.prop('checked', override);

    if(override && $inputMode.val() == null) {
        // go into override mode, but the selectbox has nothing selected, select previous value, or default to std
        $inputMode.customSet($inputMode.data('prevValue') || '0');
    }
    if(!override) {
        // go out of override mode, clear inputbox
        $inputMode.data('prevValue', $inputMode.val());
        $inputMode.customSet(null);
    }
}

function getCurrentlySelectedGamemode() {
    if($inputMode.prop('disabled')) {
        return null;
    } else {
        return $inputMode.val();
    }
}

$frm.submit(function(e) {
    e.preventDefault();
    $submitBtn.prop('disabled', true);
    $frm.slideUp();
    $sampleImg.slideUp();
    $resultImg.hide();
    stopImageCounterUpdate();

    var data;
    if($manualScoreSelect.is(':hidden')) {
        data = $frm.serialize();
    } else {
        data = {score: {}};
        $.each($frm.serializeArray(), function(i, field) {
            if(field.name === 'username') {
                data.score.username = field.value;
            } else if (field.name.lastIndexOf('score_', 0) === 0) {
                // starts with 'score_'
                data.score[field.name.substr(6)] = field.value;
            } else {
                data[field.name] = field.value || null;
            }
        });
    }


    $result.slideDown();
    toggleProgressBar(true);
    $resultText.val('fetching data and generating image...');
    console.log(data);
    doThaThing(data);
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
    toggleProgressBar(true);
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
                displayResult(true);
                var imgSrc = data.image.url;
                $resultImg.attr('src', imgSrc).show();
                $resultText.val(imgSrc);
                $contactMe.attr('href', '/contact?img-id=' + data.image.id);
                incrementImageCounter();
            } else if (data.result === 'multiple-scores') {
                displayResult(true);
                console.log('welp, multiple scores');
                $resultText.val('There are multiple scores, please choose one!');
                fillScoresMenu(data.data);
                $chooseScoreBox.slideDown();
            } else {
                displayResult(false);
                console.log('ERROR: unexpected result:', data.result);
                $resultErrorText.text('If this message appears, I forgot to implement something.... ooops, please contact me, thanks :D');
                $contactMe.attr('href', '/contact?error=non-implemented-resulti&result=' + data.result);
            }
        },
        error: function(jqXHR) {
            var error = jqXHR.responseJSON;
            console.error('ERROR', error);
            displayResult(false);
            if(error) {
                var errorText;
                switch(error.status) {
                case 404:
                    errorText = 'Data not found: ' + error.detailMessage;
                    break;
                case 400:
                    errorText = 'Invalid data: ' + error.detailMessage;
                    break;
                case 502:
                    errorText = 'Something didn\'t quite go as planned... The server reported: ' + error.detailMessage;
                    break;
                default:
                    errorText = 'I\'m sorry, something went wrong... The server reported: ' + error.detailMessage;
                    break;
                }
                $resultErrorText.text(errorText);
                $contactMe.attr('href', '/contact?error=' + error.status);
            } else {
                $resultErrorText.text('I\'m sorry, something went wrong...');
                $contactMe.attr('href', '/contact?error=unknown');
            }
        },
        complete: function() {
            toggleProgressBar(false);
            $submitBtn.prop('disabled', false);
        },
    });
}

function toggleProgressBar(show) {
    $progressBar.toggle(show);
    if(show) {
        $resultOk.hide();
        $resultError.hide();
    }
}

function displayResult(isOk) {
    $resultOk.toggle(isOk);
    $resultError.toggle(!isOk);
}

$goBackBtn.click(function(e) {
    e.preventDefault();
    $frm.slideDown();
    $result.slideUp();
    $chooseScoreBox.slideUp();

    startImageCounterUpdate();
});

// validate input but also update map display
function validateInput(e) {
    var inputIsValid = true;

    var $inputUsernameFormGroup = $inputUsername.parent().parent();
    var $inputModeFormGroup = $inputMode.parent().parent();

    var usernameInvalid = $inputUsername.val().length == 0;
    if(e.currentTarget == $inputUsername[0]) {
        $inputUsernameFormGroup.toggleClass('has-error', usernameInvalid);
    }
    if(usernameInvalid) {
        // username cannot be empty
        inputIsValid = false;
    }

    var beatmapIdInvalid = !/^[0-9]+$/.test($inputBeatmapId.val());
    if(beatmapIdInvalid) {
        // beatmap id can only contain numbers
        inputIsValid = false;
    }

    var mode = getCurrentlySelectedGamemode();
    var modeInvalid = (mode != null) && (mode < 0 || mode > 4);
    if(e.currentTarget == $inputMode[0]) {
        $inputModeFormGroup.toggleClass('has-error', modeInvalid);
    }
    if(modeInvalid) {
        // invalid gamemode
        inputIsValid = false;
    }

    if(!beatmapIdInvalid && !modeInvalid) {
        // beatmap id and mode are valid
        loadMapDisplay();
    } else {
        hideMapDisplay();
    }

    $submitBtn.prop('disabled', !inputIsValid);
}

// listen to a shitton of events to make sure we catch every change as early as possible
$inputUsername.allInputUpdate(validateInput);
$inputMode.allInputUpdate(validateInput);
$inputBeatmapUrl.allInputUpdate(function(e) {
    var value = parseBeatmapUrl($inputBeatmapUrl.val().trim());
    $inputBeatmapUrl.parent().parent().toggleClass('has-error', !value.isValid);
    if(value.isValid) {
        if(value.s) {
            // its a /s/ url, need extra info!
            console.log('input-result: s-url', value);
            $beatmapVersionSelect.slideDown();
            handleSetUrl(value.s);
        } else {
            // hype, URL is parsed!
            console.log('input-result: valid input:', value);
            setBeatmapAndModeInput(e, value.b, value.m);
            $beatmapVersionSelect.slideUp();

            // done :D
            return;
        }
    } else {
        console.log('input-result: error', value);
        $beatmapVersionSelect.slideUp();
    }

    // if we reach this, means we dont have a final value
    // set back to default values
    setBeatmapAndModeInput(e);
});
$beatmapVersion.allInputUpdate(function(e) {
    setBeatmapAndModeInput(e, $beatmapVersion.val(), null);
});

// custom detect change handler
// since we update both at the same time
// and we want to only fire *one* change event
// we cant use my custom change detect thingy
// it fires the event-handler manually, and we need an event to give it
// so this function requires *an* event :P
function setBeatmapAndModeInput(e, b, m) {
    var oldB = $inputBeatmapId.val();
    var oldM = $inputMode.val();
    if(oldB == b && oldM == m) {
        // nothing has changed
        return;
    }

    // change detected!
    $inputBeatmapId.customSet(b || '', true);
    $inputMode.customSet(m, true);
    // disable or enable override gamemode
    setOverrideGamemode(m != null);

    // manually fire the change event handler
    validateInput(e);
}

var handleSetUrlTimeout = -1;
function handleSetUrl(s) {
    $beatmapVersion.empty();
    $beatmapVersion.customSet(null);
    // $beatmapVersion.append($('<option>').text('loading...'));
    updateBeatmapVersionMessage('loading...');
    $beatmapVersion.data('setId', s);
    clearTimeout(handleSetUrlTimeout);
    handleSetUrlTimeout = setTimeout(function() {
        handleSetUrlForReal(s);
    }, 250);
}

function handleSetUrlForReal(s) {
    $.ajax({
        type: 'get',
        url: '/api/diffs/' + s,
        success: function(data) {
            if($beatmapVersion.data('setId') != s) return;
            $inputBeatmapUrl.parent().parent().toggleClass('has-error', false);
            $beatmapVersion.empty();
            $beatmapVersion.customSet(null);
            for(var i=0, _len = data.set.length; i<_len; ++i) {
                var version = data.set[i];
                var text = version.version;
                if(!data.stdOnlySet) {
                    text = '[' + MODES[version.mode] + '] ' + text;
                }
                var $option = $('<option>')
                    .text(text)
                    .attr('value', version.beatmap_id)
                    .attr('selected', version.beatmap_id == data.defaultVersion);
                $beatmapVersion.append($option);
            }
            updateBeatmapVersionMessage();
        },
        error: function(jqXHR) {
            if($beatmapVersion.data('setId') != s) return;
            var error = jqXHR.responseJSON;
            $inputBeatmapUrl.parent().parent().toggleClass('has-error', true);
            $beatmapVersion.empty();
            $beatmapVersion.customSet(null);
            var errorText;
            switch((error && error.status) || 0) {
            case 404:
                errorText = 'Beatmap not found...';
                break;
            case 502:
                errorText = 'Error while retrieving data: ' + error.detailMessage;
                break;
            default:
                errorText = 'Something went wrong...';
                break;
            }
            updateBeatmapVersionMessage(errorText, true);
        },
        complete: function() {
            if($beatmapVersion.data('setId') != s) return;
            console.log('loaded s result', s);
            $beatmapVersion.trigger('change');
        }
    });
}

function updateBeatmapVersionMessage(message, isError) {
    if(message) {
        $beatmapVersionMessage.text(message).toggleClass('is-error-message', isError || false).show();
        $beatmapVersion.hide();
    } else {
        $beatmapVersionMessage.text('').removeClass('is-error-message').hide();
        $beatmapVersion.show();
    }
}

function parseBeatmapUrl(string) {
    if(typeof string !== 'string' || string.length === 0) {
        // no string, or empty string
        return {
            isValid: false,
            error: 'empty'
        };
    }
    var obj;

    // lala
    var onlyIdResult = /^([0-9]+)(s)?$/.exec(string);
    if(onlyIdResult) {
        obj = {
            isValid: true,
            m: null
        };
        // $2 contains either an s or nothing :D
        obj[onlyIdResult[2] || 'b'] = onlyIdResult[1];
        return obj;
    }

    // [http[s]://]osu.ppy.sh/[b|s]/123456[[?|&]m=0]
    var oldSite1Result = /^(?:https?\:\/\/)?osu\.ppy\.sh\/(b|s)\/([0-9]+)(?:(?:\?|&)m=([0-3]))?$/.exec(string);
    if(oldSite1Result) {
        obj = {
            isValid: true,
            m: oldSite1Result[3]
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
            m: oldSite2Result[2]
        };
    }

    // [http[s]://]osu.ppy.sh/beatmapsets/123456#[osu|taiko|fruits|mania]/123456
    var newSiteResult = /^(?:https?\:\/\/)?osu\.ppy\.sh\/beatmapsets\/[0-9]+#(osu|taiko|fruits|mania)\/([0-9]+)$/.exec(string);
    if(newSiteResult) {
        return {
            isValid: true,
            b: newSiteResult[2],
            m: ['osu', 'taiko', 'fruits', 'mania'].indexOf(newSiteResult[1])
        };
    }

    return {
        isValid: false,
        error: 'invalid'
    };
}

$('#toggle-manual-score-select > a').click(function(e){
    e.preventDefault();
    $manualScoreSelect.slideToggle(updateManualSelectInputs);
});
$('#toggle-mods-input > a').click(function(e) {
    e.preventDefault();

    // if where going from manual to checkboxes update the checkboxes
    if($modsCheckboxesInput.is(':hidden')) {
        var val = +$inputScoreEnabledMods.val();
        $allThemModCheckboxes.each(function() {
            var localVal = +this.value;
            this.checked = (val&localVal)===localVal;
        });
    }

    // do the animation
    $modsManualInput.slideToggle();
    $modsCheckboxesInput.slideToggle();
});

$allThemModCheckboxes.change(function() {
    var value = 0;
    $allThemModCheckboxes.each(function() {
        if(this.checked) {
            value += +this.value;
        }
    });
    $inputScoreEnabledMods.val(value);
});

function updateManualSelectInputs() {
    var isHidden = $manualScoreSelect.is(':hidden');
    $manualScoreSelect.find(':input').each(function() {
        var $el = $(this);
        var val = $el.data('visible-required-status');
        $el.prop('required', isHidden ? false : val);
        $el.prop('disabled', isHidden);
    });
}

function initManualSelectInputs() {
    $manualScoreSelect.find(':input').each(function() {
        var $el = $(this);
        $el.data('visible-required-status', $el.prop('required'));
    });
}

$('#sample-img a.dismiss').click(function(e){
    e.preventDefault();
    $sampleImg.slideUp();
});

function hideMapDisplay() {
    $mapDisplayComment.hide();
    $mapDisplay.hide();
}

var handleLoadMapDisplayTimeout = -1;
function loadMapDisplay() {
    console.log('load map display requested');

    var b = $inputBeatmapId.val();
    var m = getCurrentlySelectedGamemode();
    var url = '/api/beatmap/' + b;
    if(m) {
        url += '/' + m;
    }
    if(url == $mapDisplay.data('loadedUrl')) {
        // display already contains correct data :D
        console.log('show already loaded mapdisplay', url);
        showMapDisplay();
        return;
    }

    // display does not contain correct data, needs update
    console.log('load mapdisplay', url);
    updateAndShowMapDisplayComment('loading...');
    $mapDisplay.data('toBeLoadedUrl', url);
    clearTimeout(handleLoadMapDisplayTimeout);
    handleLoadMapDisplayTimeout = setTimeout(function() {
        loadMapDisplayForReal(url);
    }, 250);
}

// only allowed to be called from within loadMapDisplay
function loadMapDisplayForReal(url) {
    $.ajax({
        type: 'get',
        url: url,
        success: function(data) {
            if($mapDisplay.data('toBeLoadedUrl') != url) {
                // state has changed, do not display data
                return;
            }
            updateMapDisplayData(url, data);
            showMapDisplay();
            // if gamemode input box is disabled (aka custom gamemode is off) set the gamemode
            if($inputMode.prop('disabled')) {
                $inputMode.customSet(data.mode, true);
            }
        },
        error: function(jqXHR) {
            if($mapDisplay.data('toBeLoadedUrl') != url) {
                // state has changed, do not display data
                return;
            }
            var error = jqXHR.responseJSON;
            switch((error && error.status) || 0) {
            case 404:
                updateAndShowMapDisplayComment('Beatmap not found!', true);
                break;
            case 502:
                updateAndShowMapDisplayComment('Error while retrieving data: ' + error.detailMessage, true);
                break;
            default:
                updateAndShowMapDisplayComment('Something went wrong...', true);
                break;
            }
        }
    });
}

// only allowed to be called from within loadMapDisplayForReal
function updateMapDisplayData(url, data) {
    $mapDisplay.data('loadedUrl', url);

    $mapDisplayMode.text(MODES[data.mode]);
    $mapDisplayModeComment.text(data.converted ? ' (converted)' : '');
    $mapDisplayArtist.text(data.artist);
    $mapDisplayTitle.text(data.title);
    $mapDisplayVersion.text(data.version);
    $mapDisplayCreator.text(data.creator);
    $mapDisplayImage.attr('src', '/cover/' + data.beatmapSetId + '.jpg').show();
}

// only allowed to be called from within loadMapDisplay/loadMapDisplayForReal
function showMapDisplay() {
    $mapDisplayComment.hide();
    $mapDisplay.show();
}

// only allowed to be called from within loadMapDisplay/loadMapDisplayForReal
function updateAndShowMapDisplayComment(message, isError) {
    $mapDisplay.hide();
    $mapDisplayComment.text(message).toggleClass('is-error-message', isError || false).show();
}

$checkboxOverrideMode.change(function() {
    setOverrideGamemode(this.checked);
});

$(document).ready(function() {
    $result.hide();
    $chooseScoreBox.hide();
    $beatmapVersionSelect.hide();
    $manualScoreSelect.hide();
    $modsManualInput.hide();
    hideMapDisplay();
    $submitBtn.prop('disabled', true);

    startImageCounterUpdate();
    initManualSelectInputs();
    updateManualSelectInputs();
    setOverrideGamemode(false);
    $inputMode.customSet(null);
});
