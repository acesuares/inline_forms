// Search suggestions with the browser's own <datalist>. No library.
//
//   <input type="text" name="search" list="search_suggestions" autocomplete="off"
//          data-suggest-url="/members/autocomplete_member_last_name">
//   <datalist id="search_suggestions"></datalist>
//
// While the user types, GET <url>?term=<text> and put the answers in the
// datalist. The answer is JSON: an array of strings, or of objects with
// "value" or "label". The browser shows the list and does the picking; a pick
// only fills the text, and the form is submitted as before.
//
// `data-suggest-min` on the input sets the number of characters before the
// first request (default 2).
(function () {
  "use strict";

  // A layout that loads this file in <body> runs it again on every Turbo visit.
  if (window.datalistSuggestLoaded) { return; }
  window.datalistSuggestLoaded = true;

  var DELAY = 200; // ms after the last keystroke

  function textOf(item) {
    if (typeof item === "string") { return item; }
    if (item && typeof item === "object") { return String(item.value || item.label || ""); }
    return "";
  }

  function fill(list, items) {
    var seen = {};
    list.textContent = "";
    items.forEach(function (item) {
      var text = textOf(item);
      if (text === "" || seen[text]) { return; }
      seen[text] = true;
      var option = document.createElement("option");
      option.value = text;
      list.appendChild(option);
    });
  }

  function isOption(list, text) {
    for (var i = 0; i < list.options.length; i++) {
      if (list.options[i].value === text) { return true; }
    }
    return false;
  }

  function suggest(input) {
    var list = document.getElementById(input.getAttribute("list"));
    var url = input.getAttribute("data-suggest-url");
    var min = parseInt(input.getAttribute("data-suggest-min"), 10);
    var term = input.value.trim();
    if (!list || !url) { return; }
    if (input.suggestRequest) { input.suggestRequest.abort(); }
    if (term.length < (isNaN(min) ? 2 : min)) { list.textContent = ""; return; }

    var request = new AbortController();
    var address = new URL(url, window.location.href);
    address.searchParams.set("term", term);
    input.suggestRequest = request;
    fetch(address, { headers: { "Accept": "application/json" }, credentials: "same-origin", signal: request.signal })
      .then(function (response) { return response.ok ? response.json() : []; })
      .then(function (items) {
        if (input.suggestRequest === request) { fill(list, Array.isArray(items) ? items : []); }
      })
      .catch(function () { /* aborted or offline: keep what is shown */ });
  }

  document.addEventListener("input", function (event) {
    var input = event.target;
    if (!input.matches || !input.matches("input[list][data-suggest-url]")) { return; }
    clearTimeout(input.suggestTimer);
    // Picking a suggestion fires "input" too. Nothing to ask then, and filling
    // the list again would open it again.
    var list = document.getElementById(input.getAttribute("list"));
    if (event.inputType === "insertReplacementText") { return; }
    if (event.inputType === undefined && list && isOption(list, input.value)) { return; }
    input.suggestTimer = setTimeout(function () { suggest(input); }, DELAY);
  });
})();
