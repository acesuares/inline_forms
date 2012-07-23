$(document).ready(function() {
    // get rid of translation_missing tooltips
    $(this).on("mouseover", ".translation_missing",  function() {
        $(this).attr('title', '');
    })
    // qtips for validation hints
    $(this).on("mouseover", ".has_validations",  function() {
        $(this).qtip({
            content: {
                text: function(api) {
                    // Retrieve content from custom attribute of the $('.selector') elements.
                    return $(this).attr('validation-hint');
                }
            },
            show: {
                ready: true // this took a loooooong time to find out...
            },
            position: {
                my: 'left top',
                at: 'top right',
                adjust: {
                        y: +17
		}
            },
            style: {
                classes: 'ui-tooltip-jtools',
                tip: {
			corner: false
		}
            }
        })
    });
});

