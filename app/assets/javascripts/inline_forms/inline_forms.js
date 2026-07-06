//= require jquery
//= require jquery.ui.all
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

// Date/time/month inputs are native (<input type="date|time|month">) since
// 8.1.25 — no jQuery UI datepicker/timepicker init. jQuery UI remains in the
// bundle only for the autocomplete widget (dropdown_with_other).
$(function(){
  $(document).foundation();
  initInlineFormsWidgets(document);
});

document.addEventListener("turbo:load", function() {
  initInlineFormsWidgets(document);
});

// Widget init: one path for first paint, turbo:load and turbo:frame-load.
// Form element helpers emit class hooks only — no inline <script> tags.
// Currently only the validation-hint tooltips need JS; date/time/month
// pickers are native inputs, and Trix 2's <trix-editor> is a custom element
// the browser upgrades automatically after Turbo frame swaps.
function initInlineFormsWidgets(root) {
  initValidationHintTooltips(root);
}

// Validation hint tooltips: HTML lists from hidden source divs, rendered via Tippy.js
// (Foundation Tooltip positioning breaks inside #outer_container position:absolute).
function initValidationHintTooltips(root) {
  var $root = root instanceof jQuery ? root : $(root);
  $root.find(".validation-hint-trigger[data-validation-hints-source]").each(function () {
    var trigger = this;
    var $trigger = $(trigger);
    var sourceId = $trigger.data("validation-hints-source");
    var sourceEl = document.getElementById(sourceId);
    if (!sourceEl) { return; }

    var html = sourceEl.innerHTML;
    if (!html || !html.trim()) { return; }

    if (trigger._tippy) {
      trigger._tippy.destroy();
    }

    if (typeof tippy !== "undefined") {
      tippy(trigger, {
        allowHTML: true,
        content: html,
        appendTo: function () { return document.body; },
        placement: "top-start",
        theme: "validation-hints",
        interactive: false,
        arrow: true,
        delay: [150, 0]
      });
    }
  });
}

// get rid of translation_missing tooltips
$(document).ready(function() {
  $(this).on('mouseover', '.translation_missing', function() {
    $(this).attr('title', '');
  });
});

// Re-bind widgets (tooltips) after Turbo Frame swaps.
document.addEventListener("turbo:frame-load", function(event) {
  var root = event.target;
  if (!root || !root.querySelectorAll) { return; }
  initInlineFormsWidgets(root);
});
