var $frm = $('#form');
var $submitBtn = $('#submit-btn');
var $result = $('#result');
var $resultImg = $('#resultImg');
var $progressBar = $('#progressBar');
var $resultText = $('#resultText');
var $resultText = $('#resultText');
var $goBackBtn = $('#go-back-btn');
var $sampleImg = $('#sample-img');
var $contactMe = $('#contact-me');
var $imageCount = $('#image-count');
var $chooseScoreBox = $('#choose-score');
var $chooseScoreBtnGroup = $('#choose-score-btn-group');

var imageCounterUpdaterIntervalId = 0;

function incrementImageCounter() {
    $imageCount.text(+$imageCount.text()+1);
}

// Opera why???
//if(typeof document.hasFocus === 'undefined') { document.hasFocus = function () { return document.visibilityState == 'visible'; }}

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

    startImageCounterUpdate();
});

$(document).ready(function() {
    $result.hide();
    $chooseScoreBox.hide();

    startImageCounterUpdate();
});
