$(document).foundation();

$(document).ready(function() {
  // initialize datepickers
  $.datepicker.setDefaults({
    changeMonth : true,
    changeYear : true,
    minDate: "-24Y", 
    maxDate: "-10Y"
  });
  // get rid of translation_missing tooltips
  $(this).on("mouseover", ".translation_missing", function() {
    $(this).attr('title', '');
  });
});
