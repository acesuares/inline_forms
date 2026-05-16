# UJS → Turbo migration checklist

Track progress toward full Turbo integration and removal of jQuery UJS from inline_forms generated apps.

**Current gem version:** see `lib/inline_forms/version.rb` (Step 3 complete in **7.5.0** except tree-related `*.js.erb` — Step 4)

**Architecture today:** almost every inline interaction is `remote: true` → `format.js` → `*.js.erb` doing `$('#<update_span>').html(...)`. Turbo is loaded as an ES module with **`Turbo.session.drive = false`**. One vertical slice (nested has_many list pagination) uses **`<turbo-frame>`**.

**Target end state:** Turbo Frames/Streams for all swaps; **`format.html`** / **`format.turbo_stream`** responses; no `*.js.erb`; no `jquery_ujs` or `jquery.remotipart`; Drive enabled.

---

## Step 1 — Turbo wired (DONE)

- [x] `gem 'turbo-rails'` in installer Gemfile (`bin/inline_forms_installer_core.rb`)
- [x] Turbo loaded as `<script type="module">` in `layouts/inline_forms.html.erb` and `layouts/application.html.erb`
- [x] `Turbo.session.drive = false` (UJS still owns navigation)
- [x] Turbo **not** in Sprockets bundle (`app/assets/javascripts/inline_forms/inline_forms.js`) — ESM parse-error lesson from 7.1.1
- [x] Smoke test: `lib/installer_templates/example_app_tests/test/integration/example_app_turbo_layout_test.rb`

---

## Step 2 — Nested list + pagination as Turbo Frame (DONE)

- [x] `_list.html.erb`: nested has_many container is `<turbo-frame id="…_list">` when `parent_class` present
- [x] Nested pagination: no `:remote => true`; `update=` param matches frame id (`…_list` suffix)
- [x] `InlineFormsController#index`: HTML for nested frame requests; `turbo_rails/frame` vs `inline_forms` layout negotiation
- [x] **Nested rows (7.4.2):** per-row `<turbo-frame>` + Turbo presentation links; **`row_html_turbo_allowed?`** enables **`format.html`** row open/close for **`not_accessible_through_html?`** models when **`params[:update]`** is a nested associated row id (`apartment_<aid>_photo_<pid>`). Removed row-level **`data-turbo="false"`** (field cancel + pagination use Turbo inside nested frames).
- [x] Top-level rows must **not** carry `data-turbo="false"` (would poison inner frames — 7.2.3)
- [x] Smoke test: `example_app_apartment_photos_pagination_test.rb`
- [x] Example seed data (Konferensha + photos) for pagination assertions

**Explicitly deferred in this step:** top-level index lists (`/apartments`) stay full-page + UJS row open.

---

## Step 3 — Per-row / per-field inline-edit lifecycle

Convert the **`show → edit → update → show_element → close`** cycle without UJS.

### DOM contract (unchanged)

- Every editable region needs a stable id: `{model}_{id}_{attribute}` (e.g. `apartment_5_name`)
- `params[:update]` must match that id (set by `link_to_inline_edit`, `_edit.html.erb`, etc.)

### Row-level (stock list → full `_show` panel)

- [x] Wrap each top-level list row in `<turbo-frame id="apartment_<id>">` (`_list.html.erb` when `parent_class` is nil)
- [x] Row title link: GET `show` → HTML `row_show` / `_show` inside frame (no `:remote`; `data-turbo` + `data-turbo-frame`)
- [x] `InlineFormsController#show` (full record, no `params[:attribute]`): `format.html` → `row_show` / `row_close` + `turbo_rails/frame` when `turbo_frame_request?`, else full `inline_forms` layout; `format.js` still renders `show.js.erb` / `close.js.erb` for legacy callers
- [x] `close_link` and `_close` presentation link: Turbo when `@inline_forms_turbo_row` (row HTML path)
- [x] `soft_delete`, `soft_restore`, `destroy`, `revert`: `format.html` → `row_close` / `row_destroyed` (+ Turbo toolbar links); `format.js` kept for non-frame callers only
- [x] Remove `edit.js.erb`, `update.js.erb`, `show_element.js.erb` (field lifecycle is Turbo HTML only)
- [x] Remove `show.js.erb`, `close.js.erb`, `record_destroyed.js.erb`, `show_undo.js.erb` (7.7.0; tree migrated)
- [x] Remove `:remote => true` from nested `_list` / `_close` / toolbar where migrated (row toolbar, versions, nested `+` use Turbo; top-level `new` was Step 4)
- [x] Remove `data-turbo="false"` from nested rows once nested inline-edit is Turbo-native (7.4.2)

### Nested associated lists (e.g. Apartment → Photo)

- [x] Each nested row is `<turbo-frame id="{parent}_{id}_{assoc}_{child_id}">` with Turbo presentation links (same contract as top-level).
- [x] **`row_html_turbo_allowed?`:** `format.html` row open/close for **`not_accessible_through_html?`** models when **`params[:update]`** matches a nested associated row id (≥4 underscore segments, trailing numeric id).
- [x] Scalar field edit/cancel inside nested **`_show`** uses existing **`format.html`** field templates (no **`UnknownFormat`** for Photo).

### Field-level (`link_to_inline_edit` / `*_show` helpers)

- [x] **Stock `_show` scalar fields**: wrapped in `<turbo-frame id="{model}_{id}_{attribute}">`; `@inline_forms_turbo_field = true` so `link_to_inline_edit` omits `:remote => true`
- [x] **`link_to_inline_edit`**: uses Turbo when `@inline_forms_turbo_field` or explicit `turbo_frame: true`
- [x] **`InlineFormsController#edit`, `#update`, `#show`** (single attribute): `format.html` + `field_edit` / `field_show` templates when `turbo_frame_request?`
- [x] **`_edit.html.erb`**: omits `:remote => true` when `@turbo_frame` (Turbo form submit inside frame)
- [x] Remove `edit.js.erb`, `update.js.erb`, `show_element.js.erb`
- [x] **`not_accessible_through_html?` models** (e.g. Photo): nested list row **`show` / `close`** use **`format.html`** when **`params[:update]`** is a nested row id (`row_html_turbo_allowed?`); field **`edit` / `update` / `show`** already always register **`format.html`**.

### Widget re-init after swap

- [x] ActionText/Trix: `turbo:frame-load` in `inline_forms.js` attaches Trix editors after frame replace
- [x] jQuery UI datepicker / timepicker: re-bound on `turbo:frame-load` (autocomplete widgets in field partials still use inline scripts until Step 5)

### Helpers (`app/helpers/inline_forms_helper.rb`)

- [x] `close_link`, `link_to_soft_delete`, `link_to_destroy`, `link_to_new_record`, `link_to_versions_list`, `close_versions_list_link`: Turbo when `turbo_row:` (default **true**); legacy `remote: true` only when `turbo_row: false`

### Tests

- [x] Integration: stock row open/close on `/apartments` (Turbo frame + HTML `show` / `close`): `example_app_apartment_row_turbo_test.rb`
- [x] Integration: open apartment row → edit text field → save → cancel (field flow: `example_app_apartment_field_turbo_test.rb`)
- [x] Integration: nested Photo row open/close + name field cancel (`example_app_apartment_photos_pagination_test.rb`)
- [x] Integration: replace photo image (multipart) inside nested frame (`example_app_apartment_photos_pagination_test.rb`)
- [x] Integration: custom field-only page (`ApartmentsController#name_list`) — Turbo edit/update/cancel without full `_show`
- [x] Assert no `406 UnknownFormat` on Turbo field update (name list test)
- [x] Integration: row destroy + PaperTrail revert via Turbo (`example_app_apartment_row_turbo_test.rb`)
- [x] Integration: versions panel open/close via Turbo (`example_app_apartment_versions_turbo_test.rb`)

---

## Step 4 — Remaining UJS surfaces

### Lists and create flow

- [x] Top-level index: wrap in `<turbo-frame id="apartments_list">`; in-frame pagination (7.7.0)
- [x] `new` / `create`: frame refresh replacing list container (7.7.0)
- [x] Remove `new.js.erb`, `list.js.erb` (7.7.0)
- [x] `_new.html.erb`: Turbo path when `@turbo_frame` (no `:remote` on cancel)

### Tree

- [x] ~~`:tree` / `_tree.html.erb`~~ — **archived in 7.7.0** (`archived/form_elements/tree/`); needs host tree gem/APIs. Turbo-ready partial kept in archive.

### Versions panel

- [ ] `VersionsConcern#list_versions`: HTML frame / stream
- [ ] Remove `versions.js.erb`, `versions_list.js.erb`
- [ ] `_versions_list.html.erb`: drop `:remote => true` on revert links (or stream revert)

### Geo / misc

- [x] ~~`geo_code_curacao`~~ — **archived in 7.6.0** (`archived/form_elements/geo_code_curacao/`). If restored, migrate `list_streets.js.erb` to frame or stream.

### Controller cleanup

- [ ] Every action in `InlineFormsController` + `VersionsConcern` has a non-JS response path
- [ ] Audit `respond_to` blocks: parallel `format.turbo_stream` where stream is cleaner than full frame

### Tests

- [x] Top-level list pagination in frame (`example_app_apartment_top_level_pagination_test.rb`)
- [x] Create apartment → list frame updates (`example_app_apartment_top_level_new_test.rb`)
- [ ] Versions panel open/close
- [ ] Assert zero `data-remote="true"` in rendered HTML for inline_forms flows

---

## Step 5 — Enable Drive, remove UJS

- [ ] Remove `Turbo.session.drive = false` from both layouts
- [ ] Delete `//= require jquery_ujs` from `inline_forms.js`
- [ ] Delete `//= require jquery.remotipart` from `inline_forms.js`
- [ ] Delete all `app/views/inline_forms/*.js.erb` (and geo `list_streets.js.erb`)
- [ ] Remove `format.js` branches from controllers (or empty stubs, then delete)
- [ ] Update `example_app_turbo_layout_test.rb`: Drive enabled (or line removed)
- [ ] Full `bundle exec rails test` in `--example` app

### jQuery (optional follow-up — not required to drop UJS)

These can remain while UJS is gone; separate migration if desired:

- [ ] `jquery.ui.all` (datepicker)
- [ ] `jquery.timepicker.js`
- [ ] `autocomplete-rails`
- [ ] `foundation` jQuery plugin → consider Foundation JS without jQuery or Stimulus

---

## Reference — UJS inventory

### `*.js.erb` (all to delete by Step 5)

| File | Effect |
|------|--------|
| `show.js.erb` | Replace row with `_show` |
| `edit.js.erb` | Replace `#update_span` with `_edit` form |
| `update.js.erb` | Replace with `{form_element}_show` |
| `show_element.js.erb` | Single-field show after update |
| `new.js.erb` | Replace with `_new` form |
| `list.js.erb` | Replace list container |
| `close.js.erb` | Fade + `_close` partial |
| `record_destroyed.js.erb` | Fade out row |
| `show_undo.js.erb` | Undo link after destroy |
| `versions.js.erb` | Fade + versions partial |
| `versions_list.js.erb` | Versions table |
| ~~`geo_code_curacao/list_streets.js.erb`~~ | Archived 7.6.0 — street autocomplete JSON |

### Controller actions still on `format.js`

`index`, `show`, `edit`, `update`, `new`, `create`, `soft_delete`, `soft_restore`, `destroy`, `revert`, `list_versions`

### Key files

- `app/controllers/inline_forms_controller.rb`
- `app/controllers/concerns/versions_concern.rb`
- `app/views/inline_forms/_list.html.erb`, `_show.html.erb`, `_edit.html.erb`, `_new.html.erb`
- `app/helpers/inline_forms_helper.rb`
- `app/helpers/form_elements/*.rb` (`*_show` → `link_to_inline_edit`)
- `app/assets/javascripts/inline_forms/inline_forms.js`
- `app/views/layouts/inline_forms.html.erb`

---

## Custom field-only pages (helper bypass)

Stock `_show` / `_list` are not required for inline edit. Any page can call form-element helpers (e.g. `text_field_show(apartment, :name)`) inside a container with id `apartment_<id>_name`. Edit/update still hit `ApartmentsController#edit` / `#update` via polymorphic paths.

Example app **`--example` name list** (`GET /apartments/name_list`): custom page using the **same** turbo-field contract as stock `_show` (not a separate code path). Linked from the **More** menu; regression-tested after stock field Turbo lands.
