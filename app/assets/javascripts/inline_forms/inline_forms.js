//= require jquery
//= require foundation

// Turbo / Hotwire is intentionally NOT required into this Sprockets bundle.
// `turbo-rails` ships only an ES-module build of turbo (`app/assets/javascripts/turbo.js`
// ends with `export { Turbo, cable }`). Concatenating that into a regular
// `<script>` bundle produces a parse error at the top-level `export`.
//
// Turbo is loaded separately by `app/views/layouts/inline_forms.html.erb`
// (and `application.html.erb`) as `<script type="module">`. Inline flows use
// `<turbo-frame>` + HTML responses; jquery-ujs / remotipart were removed in 7.8.0.

// jQuery UI is gone (8.1.26): date/time/month inputs are native, the
// dropdown_with_other combobox is an <input list> + <datalist>, and
// slider_with_values is a native <input type="range">. jQuery itself stays
// only because Foundation 6's JS requires it.
// Listeners are added once per page load. The gem's layouts load this bundle
// in <head>, which Turbo Drive keeps across visits, but a host layout may
// still have it in <body>, which Turbo re-runs on every visit (each run with a
// fresh jQuery): without the guard every run would add another set.
if (!window.inlineFormsBooted) {
  window.inlineFormsBooted = true;

  // Foundation and the widgets, once per <body>. Turbo Drive replaces <body>
  // on a visit, and the new top bar's DropdownMenu needs initialising or its
  // submenus show as plain lists. The first page gets both the ready event
  // and turbo:load (and a layout without Turbo only the first), so the body
  // check keeps it to one init. jQuery is looked up at call time.
  var inlineFormsBootedBody = null;
  var bootInlineFormsPage = function() {
    if (!document.body || document.body === inlineFormsBootedBody) { return; }
    inlineFormsBootedBody = document.body;
    if (window.jQuery && window.jQuery.fn.foundation) {
      window.jQuery(document).foundation();
    }
    initInlineFormsWidgets(document);
  };
  $(bootInlineFormsPage);
  document.addEventListener("turbo:load", bootInlineFormsPage);

  // Re-bind widgets (tooltips) after Turbo Frame swaps.
  document.addEventListener("turbo:frame-load", function(event) {
    var root = event.target;
    if (!root || !root.querySelectorAll) { return; }
    initInlineFormsWidgets(root);
  });

  // get rid of translation_missing tooltips
  document.addEventListener("mouseover", function(event) {
    var el = event.target.closest && event.target.closest(".translation_missing");
    if (el) { el.setAttribute("title", ""); }
  });
}

// Widget init: one path for first paint, turbo:load and turbo:frame-load.
// Form element helpers emit class hooks only — no inline <script> tags.
// Native inputs (date/time/month/range/datalist) and Trix 2 custom elements
// need no re-init after frame swaps; only tooltips and the range-slider
// label sync are wired here.
function initInlineFormsWidgets(root) {
  initValidationHintTooltips(root);
  initSliderValueLabels(root);
}

// slider_with_values: keep the <output> label in sync with the range input.
// Labels array rides in data-slider-values; the <output> id in
// data-slider-output (both emitted by slider_with_values_edit).
function initSliderValueLabels(root) {
  var scope = (root && root.querySelectorAll) ? root : document;
  scope.querySelectorAll("input[type=range].slider_with_values").forEach(function (el) {
    if (el._ifSliderBound) { return; }
    el._ifSliderBound = true;

    var labels = [];
    try {
      labels = JSON.parse(el.getAttribute("data-slider-values") || "[]");
    } catch (e) { /* keep empty; label just won't update */ }
    var output = document.getElementById(el.getAttribute("data-slider-output"));
    if (!output || !labels.length) { return; }

    el.addEventListener("input", function () {
      var label = labels[parseInt(el.value, 10)];
      output.textContent = (label === undefined || label === null) ? "" : label;
    });
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
