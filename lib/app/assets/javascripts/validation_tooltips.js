$(document).ready(function() {
    $(document).delegate(".attribute_name", "mouseover", function() {
        if (!$(this).data("tooltip")) {
            $(this).tooltip({
                effect: "fade",
                predelay: 200
            });
            $(this).trigger("mouseover");
        }
    });
});