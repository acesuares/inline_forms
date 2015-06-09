$(document).foundation();

$(document).ready(function() {
  // initialize datepickers
  $.datepicker.setDefaults({
    changeMonth : true,
    changeYear : true,
    yearRange: '-100:+100'
  });
  // get rid of translation_missing tooltips
  $(this).on('mouseover', ''.translation_missing', function() {
    $(this).attr('title', '');
  });
});
