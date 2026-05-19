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
  $.datepicker.setDefaults({
    changeMonth : true,
    changeYear : true,
    yearRange: '-100:+100',
    dateFormat: 'dd-mm-yy'
  });
  $(document).foundation();
  initInlineFormsWidgets(document);
});

document.addEventListener("turbo:load", function() {
  initInlineFormsWidgets(document);
});

// jQuery UI date/time pickers: one init path for first paint and turbo:frame-load
// (form element helpers emit class hooks only — no inline <script> tags).
function initInlineFormsWidgets(root) {
  var $root = root instanceof jQuery ? root : $(root);

  initValidationHintTooltips(root);

  $root.find("input.datepicker-month-year").each(function() {
    var $el = $(this);
    if ($el.hasClass("hasDatepicker")) { return; }
    $el.datepicker({
      changeMonth: true,
      changeYear: true,
      showButtonPanel: true,
      dateFormat: "MM yy",
      onClose: function() {
        var month = $("#ui-datepicker-div .ui-datepicker-month :selected").val();
        var year = $("#ui-datepicker-div .ui-datepicker-year :selected").val();
        $(this).datepicker("setDate", new Date(year, month, 1));
      }
    });
  });

  $root.find("input.datepicker").not(".datepicker-month-year").each(function() {
    var $el = $(this);
    if (!$el.hasClass("hasDatepicker")) { $el.datepicker(); }
  });

  $root.find("input.timepicker").each(function() {
    var $el = $(this);
    if (!$el.data("timepicker")) { $el.timepicker(); }
  });

  $root.find("trix-editor").each(function() {
    if (window.Trix && this.editor) { return; }
    if (window.Trix && typeof Trix.Editor === "function") {
      new Trix.Editor(this);
    }
  });
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

// Re-bind jQuery UI widgets and Trix after Turbo Frame swaps (Step 3).
document.addEventListener("turbo:frame-load", function(event) {
  var root = event.target;
  if (!root || !root.querySelectorAll) { return; }
  initInlineFormsWidgets(root);
});
