$(document).ready(function() {
  // foundation datepicker
    $('.datepicker').fdatepicker();
  // get rid of translation_missing tooltips
    $(this).on("mouseover", ".translation_missing",  function() {
      $(this).attr('title', '');
    });
});
