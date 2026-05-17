//= require jquery
//= require jquery.ui.all
//= require jquery.timepicker.js
//= require foundation
//= require autocomplete-rails

// Turbo / Hotwire is intentionally NOT required into this Sprockets bundle.
// `turbo-rails` ships only an ES-module build of turbo (`app/assets/javascripts/turbo.js`
// ends with `export { Turbo, cable }`). Concatenating that into a regular
// `<script>` bundle produces a parse error at the top-level `export`.
//
// Turbo is loaded separately by `app/views/layouts/inline_forms.html.erb`
// (and `application.html.erb`) as `<script type="module">`. Inline flows use
// `<turbo-frame>` + HTML responses; jquery-ujs / remotipart were removed in 7.8.0.

$(function(){
  $(document).foundation();
  initValidationHintTooltips(document);
});

// Foundation tooltips: HTML hint lists live in hidden source divs (not title).
function initValidationHintTooltips(root) {
  var $root = root instanceof jQuery ? root : $(root);
  $root.find(".validation-hint-trigger[data-validation-hints-source]").each(function () {
    var $trigger = $(this);
    var sourceId = $trigger.data("validation-hints-source");
    var sourceEl = document.getElementById(sourceId);
    if (!sourceEl) { return; }

    var html = sourceEl.innerHTML;
    if (!html || !html.trim()) { return; }

    var plugin = $trigger.data("zfPlugin");
    if (plugin && typeof plugin.destroy === "function") {
      plugin.destroy();
    }

    if (typeof Foundation !== "undefined" && Foundation.Tooltip) {
      new Foundation.Tooltip($trigger, {
        allowHtml: true,
        tipText: html,
        hover: true,
        clickOpen: false,
        tooltipClass: "validation-hints-tooltip"
      });
    }
  });
}

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

  initValidationHintTooltips(root);

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
