//http://flowplayer.org/tools/forum/30/37281
$(document).ready(function() {
    $(document).delegate(".has_validations", "mouseover", function() {
        if (!$(this).data("tooltip")) {
            $(this).tooltip({
                effect: "fade",
                fadeInSpeed: 300,
                fadeOutSpeed: 150,
                opacity: 0.9,
                position: 'top right',
                offset: [ 25, 20 ],
//                positioning is NOT according to documentation! Should be relative to parent element but it is not.'
                relative: true
            });
            $(this).trigger("mouseover");
        }
    });
});
