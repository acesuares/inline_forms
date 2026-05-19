# jQuery widget migration (Phase 4)

UJS removal (7.8.0) is complete. These jQuery-based widgets remain in the Sprockets bundle:

| Widget | Asset | Status |
|--------|-------|--------|
| Datepicker | `jquery.ui.all` | **Centralized** — `initInlineFormsWidgets` in `inline_forms.js`; helpers use `class="datepicker"` only |
| Month/year picker | jQuery UI datepicker | **Centralized** — `class="datepicker datepicker-month-year"` |
| Timepicker | `jquery.timepicker.js` | **Centralized** — `class="timepicker"` |
| Autocomplete | `autocomplete-rails` + inline scripts in `dropdown_with_other` | Still inline / jQuery UI |
| Foundation | `foundation` jQuery plugin | Required for layout chrome |

## Central init (7.9.8+)

`initInlineFormsWidgets(root)` runs on:

- DOM ready (after `$.datepicker.setDefaults`)
- `turbo:load`
- `turbo:frame-load`

Form element `_edit` helpers must **not** emit per-field `<script>` tags; class hooks only.

## Future removal (not started)

Replace with Stimulus or vanilla + `turbo:frame-load` one widget at a time; keep example-app tests green after each.
