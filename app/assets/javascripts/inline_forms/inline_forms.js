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
// Turbo is loaded separately by `app/views/layouts/inline_forms.html.erb`
// (and `application.html.erb`) as `<script type="module">`, with
// `Turbo.session.drive = false` so existing UJS-driven links/forms keep
// working unchanged. `<turbo-frame>` and `format.turbo_stream` are
// available for the per-view conversions that follow.

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

// Re-bind jQuery UI widgets and Trix after Turbo Frame swaps (Step 3).
document.addEventListener("turbo:frame-load", function(event) {
  var root = event.target;
  if (!root || !root.querySelectorAll) { return; }

  $(root).find("input.datepicker").each(function() {
    var $el = $(this);
    if (!$el.hasClass("hasDatepicker")) { $el.datepicker(); }
  });

  $(root).find("input.timepicker").each(function() {
    var $el = $(this);
    if (!$el.data("timepicker")) { $el.timepicker(); }
  });

  $(root).find("trix-editor").each(function() {
    if (window.Trix && this.editor) { return; }
    if (window.Trix && typeof Trix.Editor === "function") {
      new Trix.Editor(this);
    }
  });
});
