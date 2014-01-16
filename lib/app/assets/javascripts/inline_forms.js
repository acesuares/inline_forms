$(document).foundation();

$(document).ready(function() {
  // initialize datepickers
    $.datepicker.setDefaults({ });
  // get rid of translation_missing tooltips
    $(this).on("mouseover", ".translation_missing",  function() {
      $(this).attr('title', '');
    });
});
