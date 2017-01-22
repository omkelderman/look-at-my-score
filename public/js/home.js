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

$frm.submit(function(e) {
    e.preventDefault();
    $submitBtn.prop('disabled', true);
    $frm.slideUp()
    $sampleImg.slideUp();
    $result.slideDown();
    $resultImg.hide();
    $progressBar.show();
    $resultText.val('generating...');
    stopImageCounterUpdate();
    $.ajax({
        type: $frm.attr('method'),
        url: $frm.attr('action'),
        data: $frm.serialize(),
        success: function(data) {
            console.log('SUCCES!', data);
            if(data.result === 'image') {
                var imgSrc = data.image.url;
                $resultImg.attr('src', imgSrc).show();
                $resultText.val(imgSrc);
                $contactMe.attr('href', '/contact?img-id=' + data.image.id);
                incrementImageCounter();
            } else {
                console.log('ERROR: unexpected result:', data.result);
                $resultText.val('ERROR: If this message appears, I forgot to implement something.... ooops, please contact me, thanks :D');
                $contactMe.attr('href', '/contact?error=non-implemented-resulti&result=' + data.result);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            var error = jqXHR.responseJSON;
            console.error('ERROR', error)
            $resultText.val('ERROR, im sorry, something went wrong... The server reported: \'' + error.detailMessage + '\'');
            $contactMe.attr('href', '/contact?error=' + error.status);
        },
        complete: function() {
            $progressBar.hide();
            $submitBtn.prop('disabled', false);
        },
    });
});

$goBackBtn.click(function(e) {
    console.log('hahaha')
    e.preventDefault();
    $frm.slideDown()
    $result.slideUp();

    startImageCounterUpdate();
});

$(document).ready(function() {
    $result.hide();

    startImageCounterUpdate();
});
