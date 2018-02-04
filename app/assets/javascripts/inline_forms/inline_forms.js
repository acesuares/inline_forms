//= require jquery
//= require jquery_ujs
//= require jquery.ui.all
//= require ckeditor/init
//= require jquery.timepicker.js
//= require foundation
//= require jquery.remotipart

$(function(){ $(document).foundation(); });
// initialize datepickers
  $(document).ready(function() {
    $.datepicker.setDefaults({
      changeMonth : true,
      changeYear : true,
      yearRange: '-100:+100'
    });
  });

// get rid of translation_missing tooltips
  $(document).ready(function() {
    $(this).on('mouseover', '.translation_missing', function() {
      $(this).attr('title', '');
    });
  });
