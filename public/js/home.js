/* global Clipboard */

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

var $inputContainer = $('#input');
var $frm = $('#form');
var $frmOsr = $('#form-osr');
var $submitBtn = $('#submit-btn');
var $sampleImg = $('#sample-img');
var $imageCount = $('#image-count');
var $chooseScoreBox = $('#choose-score');
var $chooseScoreItems = $('#choose-score-items');
var $beatmapVersionSelect = $('#beatmap-version-select');
var $includeRecentCheckbox = $('#include-recent-checkbox');
var $manualScoreSelect = $('#manual-score-select');
var $modsManualInput = $('#mods-manual-input');
var $modsCheckboxesInput = $('#mods-checkboxes-input');
var $allThemModCheckboxes = $('#mods-checkboxes-input :checkbox');
var $osrfileInputField = $('#osrfile-input-field');

// result
var $result = $('#result');
var $resultOk = $('#result-ok');
var $resultError = $('#result-error');
var $resultImg = $('#result-img');
var $progressBar = $('#progress-bar');
var $resultErrorText = $('#result-error-text');
var $goBackBtn = $('#go-back-btn');
var $contactMe = $('#contact-me');
// var $copyToClipboardButtons = $('.copy-to-clipboard-btn');

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

/** @type {EventSource|null} */
var IMAGE_COUNT_EVENT_SOURCE = null;

function startImageCounterUpdate() {
    stopImageCounterUpdate();
    IMAGE_COUNT_EVENT_SOURCE = new EventSource('/api/image-count-stream');
    IMAGE_COUNT_EVENT_SOURCE.addEventListener('image-count', function(e) {
        $imageCount.text(e.data);
    });
}

function stopImageCounterUpdate() {
    if(IMAGE_COUNT_EVENT_SOURCE) {
        IMAGE_COUNT_EVENT_SOURCE.close();
        IMAGE_COUNT_EVENT_SOURCE = null;
    }
}

function fillScoresMenu(data) {
    console.log('multiScoreResult', data);
    $chooseScoreItems.empty();
    for(var i=0; i < data.scores.length; ++i) {
        var $buttonTd = $('<td>').append($('<button>')
            .attr('type', 'button')
            .addClass('btn btn-default')
            .text('Pick')
            .click({beatmap: data.beatmaps[i], mode: data.mode, score: data.scores[i]}, handleChooseScore)
        );

        var $tds = data.textData[i].map(function(txt) {
            return $('<td>').text(txt);
        });

        $('<tr>').append($tds).append($buttonTd).appendTo($chooseScoreItems);
    }
}

function handleChooseScore(e) {
    e.preventDefault();
    var customScoreData = e.data;

    // disable all them buttons
    $chooseScoreItems.find('button').prop('disabled', true);

    // do request with custom score
    console.log('requesting score:', customScoreData);
    $chooseScoreBox.slideUp();
    toggleProgressBar(true);
    $submitBtn.prop('disabled', true);
    doThaThing(customScoreData, $frm);
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

function transitionFromInputToResultProgress() {
    // hide/stop all input things
    $submitBtn.prop('disabled', true);
    $inputContainer.slideUp();
    $sampleImg.slideUp();
    $resultImg.hide();
    stopImageCounterUpdate();

    // show result & progress bar
    $result.slideDown();
    toggleProgressBar(true);
}

$frm.submit(function(e) {
    e.preventDefault();

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

    transitionFromInputToResultProgress();
    doThaThing(data, $frm);
});

function fireGoogleAnalyticsEvent() {
    if(!$.isFunction(window.ga)) return; // google analytics hasnt loaded

    //window.ga('osu-picture', action, label);
    var args = ['send', 'event', 'osu-picture'];
    args.push.apply(args, arguments);
    window.ga.apply(undefined, args);
}

function doThaThing(data, frm) {
    var dataIsFormData = data instanceof FormData;
    var gaLabel = dataIsFormData ? 'osr-file' : 'form-data';
    var ajaxObj = {
        type: frm.attr('method'),
        url: frm.attr('action'),
        data: data,
        processData: !dataIsFormData,
        success: function(data) {
            console.log('SUCCES!', data);
            if(data.result === 'image') {
                displayResult(true);
                var imgSrc = data.image.url;
                $resultImg.attr('src', imgSrc).show();
                setImageResult(imgSrc);
                $contactMe.attr('href', '/contact?img-id=' + data.image.id);
                // incrementImageCounter();
                fireGoogleAnalyticsEvent('submit-success', gaLabel);
            } else if (data.result === 'multiple-scores') {
                hideResult();
                console.log('welp, multiple scores');
                fillScoresMenu(data.data);
                $chooseScoreBox.slideDown();
                fireGoogleAnalyticsEvent('submit-multiple-scores', gaLabel);
            } else {
                displayResult(false);
                console.log('ERROR: unexpected result:', data.result);
                $resultErrorText.text('If this message appears, I forgot to implement something.... ooops, please contact me, thanks :D');
                $contactMe.attr('href', '/contact?error=non-implemented-resulti&result=' + data.result);
                fireGoogleAnalyticsEvent('submit-unknown', gaLabel);
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
            if(error && error.status >= 400 && error.status < 500) {
                // 4xx error, aka it wasnt my fault
                fireGoogleAnalyticsEvent('submit-user-error', gaLabel);
            } else {
                // anything else, aka it was my fault
                fireGoogleAnalyticsEvent('submit-server-error', gaLabel);
            }
        },
        complete: function() {
            toggleProgressBar(false);
            $submitBtn.prop('disabled', false);
        },
    };
    if(dataIsFormData) {
        ajaxObj.contentType = false;
    }
    $.ajax(ajaxObj);
}

var WEBSITE_URL = window.location.protocol + '//' + window.location.host + '/';
function setImageResult(imgUrl) {
    $resultOk.find('input[data-result-template]').each(function() {
        var $this = $(this);
        var template = $this.data('result-template');
        if(!template) return;

        $this.val(template.replace('{imgage-url}', imgUrl).replace('{website-url}', WEBSITE_URL));
    });
}

function toggleProgressBar(show) {
    $progressBar.toggle(show);
    if(show) {
        hideResult();
    }
}

function displayResult(isOk) {
    $resultOk.toggle(isOk);
    $resultError.toggle(!isOk);
}

function hideResult() {
    $resultOk.hide();
    $resultError.hide();
}

$goBackBtn.click(function(e) {
    e.preventDefault();
    $inputContainer.slideDown();
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

var ONLY_ID_REGX = /^([0-9]+)(s)?$/;

// [http[s]://]osu.ppy.sh/[b|s]/123456[[?|&]m=0]
var OLD_SITE_REGEX1 = /^(?:https?:\/\/)?(?:osu|old)\.ppy\.sh\/(b|s)\/([0-9]+)(?:(?:\?|&)m=([0-3]))?$/;

// [http[s]://]osu.ppy.sh/p/beatmap?b=123456[?m=0]
var OLD_SITE_REGEX2 = /^(?:https?:\/\/)?(?:osu|old)\.ppy\.sh\/p\/beatmap\?b=([0-9]+)(?:&m=([0-3]))?$/;

// [http[s]://]osu.ppy.sh/beatmapsets/123456[/]#[osu|taiko|fruits|mania]/123456
var NEW_SITE_REGEX = /^(?:https?:\/\/)?osu\.ppy\.sh\/beatmapsets\/[0-9]+\/?#(osu|taiko|fruits|mania)\/([0-9]+)$/;

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
    var onlyIdResult = ONLY_ID_REGX.exec(string);
    if(onlyIdResult) {
        obj = {
            isValid: true,
            m: null
        };
        // $2 contains either an s or nothing :D
        obj[onlyIdResult[2] || 'b'] = onlyIdResult[1];
        return obj;
    }

    var oldSite1Result = OLD_SITE_REGEX1.exec(string);
    if(oldSite1Result) {
        obj = {
            isValid: true,
            m: oldSite1Result[3]
        };
        obj[oldSite1Result[1]] = oldSite1Result[2];
        return obj;
    }

    var oldSite2Result = OLD_SITE_REGEX2.exec(string);
    if(oldSite2Result) {
        return {
            isValid: true,
            b: oldSite2Result[1],
            m: oldSite2Result[2]
        };
    }

    var newSiteResult = NEW_SITE_REGEX.exec(string);
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

// toggle input-mode
$('.toggle-input-mode').click(function(e) {
    e.preventDefault();
    var isFileUploadAfterSlide = $frmOsr.is(':hidden');
    $frm.slideToggle();
    $frmOsr.slideToggle();

    if(isFileUploadAfterSlide) {
        validateOsrInput(e);
    } else {
        validateInput(e);
    }
});

$('.toggle-manual-input').click(function(e){
    e.preventDefault();
    $manualScoreSelect.slideToggle(updateManualSelectInputs);
    $includeRecentCheckbox.slideToggle();
});
$('#toggle-mods-input').click(function(e) {
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

$submitBtn.click(function(e) {
    e.preventDefault();
    if($frmOsr.is(':hidden')) {
        // data submit
        $frm.submit();
    } else {
        // file submit
        $frmOsr.submit();
    }
});

// file upload mode stuff
$frmOsr.submit(function(e) {
    e.preventDefault();

    var data = new FormData();
    $.each($frmOsr.serializeArray(), function(i, field) {
        data.append(field.name, field.value);
    });
    var fileEl = $osrfileInputField[0];
    data.append(fileEl.name, fileEl.files[0]);

    transitionFromInputToResultProgress();
    doThaThing(data, $frmOsr);
});

$osrfileInputField.on('fileselect', validateOsrInput);

function validateOsrInput(e) {
    var inputIsValid = true;

    var fileEl = $osrfileInputField[0];
    var fileInputInvalid = !validateOsrFile(fileEl.files);
    if(e.currentTarget == fileEl) {
        $osrfileInputField.parent().parent().parent().toggleClass('has-error', fileInputInvalid);
    }
    if(fileInputInvalid) {
        inputIsValid = false;
    }

    $submitBtn.prop('disabled', !inputIsValid);
}

function validateOsrFile(files) {
    if(!files || files.length != 1) return false;
    return files[0].name.slice(-4) == '.osr';
}

///////////////////////////////////////////////////
//////////// CLIPBOARD & TOOLTIP MAGIC ////////////
///////////////////////////////////////////////////
var $copyToClipboardButtons = $('.copy-to-clipboard-btn');
var clipboard = new Clipboard('.copy-to-clipboard-btn');
clipboard.on('success', function(e) {
    $(e.trigger).trigger('copied', ['Copied!']);
});
clipboard.on('error', function(e) {
    $(e.trigger).trigger('copied', ['Copy with Ctrl-c']);
});
$copyToClipboardButtons.tooltip().bind('copied', function(e, message) {
    $(this).attr('title', message)
        .tooltip('fixTitle')
        .tooltip('show')
        .attr('title', 'Copy to Clipboard')
        .tooltip('fixTitle');
});

///////////////////////////////////////////////////
/////////////// INIT ALL THE THINGS ///////////////
///////////////////////////////////////////////////
$frmOsr.hide();
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



///////////////////////////////////////////////////
///// some additional stuff for the fileinput /////
///////////////////////////////////////////////////
// thanks https://www.abeautifulsite.net/whipping-file-inputs-into-shape-with-bootstrap-3
$(document).on('change', ':file', function() {
    var input = $(this),
        numFiles = input.get(0).files ? input.get(0).files.length : 1,
        label = input.val().replace(/\\/g, '/').replace(/.*\//, '');
    input.trigger('fileselect', [numFiles, label]);
});
$(':file').on('fileselect', function(event, numFiles, label) {
    document.getElementById(this.dataset.feedbackElementId).value = label;
});
