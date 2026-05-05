//= require jquery
//= require jquery_ujs
//= require jquery.ui.all
//= require jquery.timepicker.js
//= require foundation
//= require jquery.remotipart
//= require autocomplete-rails

// Turbo / Hotwire is intentionally NOT required into this Sprockets bundle.
// `turbo-rails` ships only an ES-module build of turbo (`app/assets/javascripts/turbo.js`
// ends with `export { Turbo, cable }`). Concatenating that into a regular
// `<script>` bundle produces a parse error at the top-level `export`, which
// silently kills jquery-ujs initialization (forms then submit as plain
// HTML POST and inline_forms controllers respond with `format.js` only,
// raising `ActionController::UnknownFormat`).
//
// This foundation slice only relies on `turbo-rails` registering the
// `turbo_stream` Mime type and view format on the server. When the first
// view/flow is actually converted to a Turbo Frame or Stream (rollout
// step 2 in stuff/ujs-to-turbo.md), Turbo JS will be loaded as an ES module
// in the layout (`type="module"`) so the existing Sprockets bundle stays
// intact and UJS keeps working alongside it.

$(function(){ $(document).foundation(); });
// initialize datepickers
  $(document).ready(function() {
    $.datepicker.setDefaults({
      changeMonth : true,
      changeYear : true,
      yearRange: '-100:+100',
      dateFormat: 'dd-mm-yy'
    });
  });

// get rid of translation_missing tooltips
  $(document).ready(function() {
    $(this).on('mouseover', '.translation_missing', function() {
      $(this).attr('title', '');
    });
  });
