//http://flowplayer.org/tools/forum/30/37281
$(document).ready(function() {
    $(document).delegate(".attribute_name", "mouseover", function() {
        if (!$(this).data("tooltip")) {
            $(this).tooltip({
                effect: "fade",
                fadeInSpeed: 200,
                fadeOutSpeed: 100,
                opacity: 0.8,
                position: 'top right',
                relative: true
            });
            $(this).trigger("mouseover");
        }
    });
});
