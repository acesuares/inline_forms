# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [7.2.3] - 2026-05-06

### Fixed

- **Pagination "Next" / page-N links inside the nested-list `<turbo-frame>` did a full-page navigation to `/photos?page=N&…` instead of swapping the frame**, even after the 7.2.2 `update=…_list` id-match fix. Repro: open an Apartment with > 5 photos, click "Next" -- the URL bar changes to `/photos?page=2&parent_class=Apartment&parent_id=1&ul_needed=true&update=apartment_1_photos_list` and the page renders the bare `_list` partial with no layout. Network log shows the request as `mainFrame` (full-page), not `xhr` (frame swap), and Turbo never gets a chance to log a frame-mismatch warning because it bowed out before issuing any fetch. Root cause is a bleed-through from 7.2.1's row-level `data-turbo="false"`: `_list.html.erb` was emitting that attribute on EVERY row, including the top-level apartment row in `apartments#index`. UJS swaps the inline edit (which contains the inner photos `<turbo-frame>`) into that row via `$('#apartment_<id>').html(<rendered _show>)`, leaving the new frame as a descendant of a `[data-turbo="false"]` ancestor. Turbo's `Session.elementIsNavigatable` resolves a clicked link by `findClosestRecursively(link, "[data-turbo]")`, which does NOT stop at the intervening `<turbo-frame>` and walks straight up to that outer row, reads `"false"`, and returns navigatable=false. With the link marked non-navigatable, `Session.willFollowLinkToLocation` returns false WITHOUT calling `event.preventDefault()`, so the browser keeps the click and does its default link navigation. The inner FrameController's `LinkInterceptor` is wired off the global `turbo:click` event, which is dispatched by `notifyApplicationAfterClickingLinkToLocation` -- only ever called when `willFollowLinkToLocation` returns true -- so the in-frame swap path never fires.
- **Fix in `app/views/inline_forms/_list.html.erb`: `data-turbo="false"` is now scoped to NESTED rows (`parent_class.present?`)**, not emitted unconditionally. Top-level rows have no surrounding `<turbo-frame>` of their own, so the opt-out was a no-op for the row's own click; the only effect it ever had at the top level was poisoning every descendant of a UJS-swapped inline edit. Nested rows still need the opt-out because the inline-edit `<form>` (multipart, image upload) is swapped into them by `edit.js.erb`'s `$('#<row_id>').html(<form>)` and is therefore inside both the row AND the surrounding `<turbo-frame>`; without the row-level opt-out the form submits via Turbo with `Accept: text/html` and the controller (which only declares `format.js` for `not_accessible_through_html?` models like Photo) raises `UnknownFormat` AFTER the DB write -- the exact 7.2.1 regression. Both flows now coexist.
- **Full-page GET `/photos?parent_class=…&update=…_list&…` returned an unstyled fragment** (bare `<turbo-frame>…</turbo-frame>` only) whenever navigation was not intercepted as a Turbo frame visit — e.g. after the top-row poisoning above, or opening the pagination URL in a new tab / pasting it into the address bar. From 7.2.0 through 7.2.2, `inline_forms_controller#index` used `layout: false` for that nested HTML path. **`index` now chooses `layout: 'turbo_rails/frame'` when `turbo_frame_request?`** (request header `Turbo-Frame`, set by the frame client) **and `layout: 'inline_forms'` otherwise**, so direct visits get the normal admin chrome and frame visits stay minimal. See `Turbo::Frames::FrameRequest` / `app/views/layouts/turbo_rails/frame.html.erb` in turbo-rails.

### Added

- **Test `top-level apartment rows do NOT carry data-turbo="false" (would poison nested frames)`** in `test/integration/example_app_apartment_photos_pagination_test.rb`: fetches `/apartments` and asserts no `<div class="… top-level …" data-turbo="false">` (in either attribute order) survives in the rendered list. This is the exact regression class 7.2.2 shipped with -- the existing nested-row `data-turbo="false"` assertion did not catch it because the bug was on the OTHER (top-level) branch of the same conditional.
- **Tests for nested `GET /photos` layout negotiation**: without `Turbo-Frame` header, response must include `id="outer_container"` (full `inline_forms` layout); with `Turbo-Frame: apartment_<id>_photos_list`, response must omit `outer_container` and still include the matching `<turbo-frame>` (minimal `turbo_rails/frame` layout).

### Notes

- Verified end-to-end against a running app via the cursor-ide-browser MCP: clicking `Konferensha` swaps the inline edit in (UJS, unchanged), clicking pagination `Next` keeps the URL at `/apartments` and re-renders the photos frame in place (page 2: dsc00087 - dsc00095), and clicking a photo to open its inline edit (which mounts the multipart replace-image form) still goes through UJS -- both paths cohabit on the same page without 406s.
- Console-instrumentation during the investigation confirmed Turbo loaded fine (`customElements.get('turbo-frame')` returned `FrameElement`) and the `<turbo-frame>` upgraded correctly after the UJS innerHTML swap; the symptom was strictly `elementIsNavigatable` ancestor-walk, not a custom-element timing race. Module-script loading and `Turbo.session.drive = false` interact cleanly with frames; this fix does not touch either.

## [7.2.2] - 2026-05-05

### Fixed

- **Pagination "Next" / "Previous" / page-N links inside the nested-list `<turbo-frame>` did nothing**. Repro: open an Apartment with > 5 photos, click "Next" (or "2") under the gallery -- network tab shows the GET completing 200, but the page does not change. Turbo logs `the response (200) did not contain the expected <turbo-frame id="apartment_<id>_photos_list"> and will be ignored`. Root cause is a long-standing legacy id mismatch: `_show.html.erb` wraps `_list` in `<div id="apartment_<id>_photos">` (outer), `_list.html.erb` wraps its rows in `<div id="apartment_<id>_photos_list">` (inner), and `will_paginate(..., :update => "...#{attribute}")` historically targeted the OUTER id because legacy `list.js.erb` did `$('#<outer>').html(<rendered _list partial>)`. Turbo Frames does its swap by frame-id match between the response and the DOM, so the URL's `update=apartment_<id>_photos` produced `<turbo-frame id="apartment_<id>_photos">` server-side while the live page held `<turbo-frame id="apartment_<id>_photos_list">`, and Turbo refused to swap.
- **`app/views/inline_forms/_list.html.erb`**: pagination's `:update` param on the nested branch now carries the same `_list` suffix the surrounding `<turbo-frame>` uses (`"#{parent_class.to_s.underscore}_#{parent_id}_#{attribute}_list"` instead of `"…#{attribute}"`). The URL is just metadata for the next render -- the partial recomputes `update_span` from `parent_class` / `parent_id` / `attribute` regardless -- so the only behavioural effect is that the `<turbo-frame id="…">` rendered server-side now matches the `Turbo-Frame:` header Turbo derives from the link's enclosing frame, the swap succeeds, and Next/Prev/page-N actually paginate in place.

### Added

- **Test `pagination links carry the same update= as the surrounding turbo-frame id`** in `test/integration/example_app_apartment_photos_pagination_test.rb`: scrapes every `?…update=…` value out of the rendered pagination block and asserts at least one equals the frame id (`apartment_<id>_photos_list`) AND none equal the legacy outer id (`apartment_<id>_photos`). This is the exact regression class 7.2.1 shipped with -- the existing `data-remote="true"` refute did not catch it because the bug was in the param value, not the data-remote attribute. The earlier "no data-remote" check is also tightened from `class="next"` to `class="next_page"` (the actual will_paginate CSS class).

### Notes

- `_show.html.erb`'s outer `<div id="apartment_<id>_photos">` wrapper is deliberately left in place. Removing it would simplify the markup but ripple into anything else still keyed off that id; the slice's contract is unchanged: pagination targets the frame, the frame holds the list, and the per-row UJS swap (`$('#<row_id>').html(...)`) is still gated by the row's `data-turbo="false"` ancestor opt-out from 7.2.1.

## [7.2.1] - 2026-05-05

### Fixed

- **Regression introduced by 7.2.0: replacing a Photo (and any other inline-edit / inline-update flow on a model whose `not_accessible_through_html?` returns true) raised `ActionController::UnknownFormat` (HTTP 406) AFTER the DB write, leaving a corrupted UI**. Repro: open an Apartment, click an existing Photo, click the image field, choose a new file, click OK -- the `UPDATE "photos" …` statement and the `PaperTrail::Version` insert both committed, then the response failed with `ActionController::UnknownFormat` from `inline_forms_controller.rb#update`. Root cause: 7.2.0 wrapped the nested has_many list in `<turbo-frame id="…">`. Inside that frame, `<turbo-frame>` intercepts every link click AND every form submission as in-frame navigation -- including the multipart `<form>` that `_edit.html.erb` renders for image replacement, which is swapped into the row by `edit.js.erb`'s `$('#<row_id>').html(<form>)` and is therefore a descendant of the frame. Turbo sent the request with `Accept: text/html, application/xhtml+xml`, but `InlineFormsController#update` only declares `format.html` when `Klass.not_accessible_through_html?` is false (Photo's is true), so `respond_to` ran out of registered formats and 406'd. The `data-turbo="false"` 7.2.0 added to the per-row inline-edit *link* did not cover this because it only opted out the link itself -- not the form that UJS later swaps into the same row.
- **Fix in `app/views/inline_forms/_list.html.erb`: `data-turbo="false"` is now on the row container `<div id="…">` itself**, not on the inline-edit link. Turbo walks ancestors to find `[data-turbo]`, so every link AND form swapped into that row by `show.js.erb` / `edit.js.erb` / `new.js.erb` (all of which call `$('#<row_id>').html(...)`, leaving the swapped HTML inside the row) inherits the opt-out. Pagination lives in its own row that does NOT carry the opt-out, so frame-pagination -- the actual point of the 7.2.0 slice -- still works. The previous per-link `data-turbo="false"` is gone (redundant with the inherited row-level setting).

### Changed

- **`test/integration/example_app_apartment_photos_pagination_test.rb`**: the assertion that used to look for `data-remote="true"` + `data-turbo="false"` on the per-row link now looks for `data-turbo="false"` on the row container `<div id="apartment_<id>_photo_<pid>">`. The new assertion explicitly documents (in a comment) that this is the safety net for the replace-photo / inline-edit form submission, since that's the regression class it was unable to catch in 7.2.0.

## [7.2.0] - 2026-05-05

Rollout step 2 of `stuff/ujs-to-turbo.md` (gitignored): "One vertical slice in the gem (e.g. list + pagination) expressed as a frame; use it as the pattern for the rest." Picks the nested has_many list (apartments -> photos) as that slice.

### Changed

- **`app/views/inline_forms/_list.html.erb` — nested has_many list now renders as a `<turbo-frame>` instead of a `remote: true` UJS `<div>`**. The container that used to be `<div class="list_container" id="…">` is now `<turbo-frame id="…" class="list_container">` whenever `parent_class` is set (i.e. lists shown inside a parent's edit page, e.g. an Apartment's Photos). Top-level lists (`apartments#index` etc.) keep the classic `<div>` and full-page navigation they already had.
- **Pagination on the nested list dropped `:remote => true`**. Inside the surrounding `<turbo-frame>` the page-link's same-URL GET returns a fresh frame and Turbo swaps just that region, so the `format.js { render :list }` + `list.js.erb` path is no longer the pagination transport (it stays in place for the `create` redirect, per the doc's "brief overlap" guidance).
- **Per-row inline-edit links now carry `data-turbo="false"`** (in addition to `data-remote="true"`). Without that, Turbo Frames would intercept inline-edit clicks as in-frame navigation before jQuery UJS could turn them into the existing `format.js` XHR + `show.js.erb` toggle. The `data-turbo="false"` opt-out lets the per-row inline-edit flow keep working unchanged until its own conversion in rollout step 3.
- **`app/controllers/inline_forms_controller.rb#index` now serves HTML for the nested case even when `Klass.not_accessible_through_html?` is true**. The flag exists to block direct top-level HTML CRUD on resources that should only be reachable through their parent (Photo is a typical example). Before this slice the flag short-circuited *all* HTML, which meant a `<turbo-frame>` GET from inside an Apartment edit page raised `ActionController::UnknownFormat`. The branch now reads: when the flag is set AND `parent_class` is supplied, render the partial with `layout: false` (a frame fragment is exactly what Turbo needs to swap); when the flag is set AND there is no parent, no HTML format is registered (existing security boundary preserved); when the flag is unset, behaviour is unchanged. cancan's `accessible_by` filter and the existing `load_and_authorize_resource` callback continue to gate the rows themselves.

### Added

- **Sample photo bundle for the example app**. The gem source ships a gitignored `pics/` directory (12 small jpgs). When `inline_forms create … --example` runs, the installer copies those into the generated app's `db/seed_images/` and emits a `SeedKonferenshaPhotos` migration that creates an Apartment named "Konferensha" and one Photo per file in `db/seed_images/`, attaching the jpg via the existing `image:image_field` CarrierWave mount. Because migrations run against both the development DB (`db:migrate`) and the test DB (`db:test:prepare`), `bundle exec rails test` sees the seeded gallery without any test-side fixture work.
- **`Photo.per_page = 5` override (installer-injected)**. The model template at `lib/generators/templates/model.erb` emits the long-standing `attr_reader :per_page; @per_page = 7` pair, which is a no-op for will_paginate (it reads `Klass.per_page` as a class method, but the template defines it on instances). The installer now `inject_into_class`-es a real `self.per_page = 5` into the example app's `app/models/photo.rb` so 12 seeded photos paginate 5 / 5 / 2 and the new pagination test has actual page links to assert against. The shared model template is left alone for now; a broader fix is a separate slice.
- **Integration test (`test/integration/example_app_apartment_photos_pagination_test.rb` in `--example` apps)** — new. Its `setup` block re-seeds the Konferensha gallery from `db/seed_images/` because `bundle exec rails test` loads the test DB from `db/schema.rb` (DDL-only), so the `SeedKonferenshaPhotos` migration's row inserts that landed in `db/development.sqlite3` never reach `db/test.sqlite3`. The test then asserts:
  - The seeded gallery has ≥ 6 photos under Konferensha.
  - `Photo.per_page` is the overridden 5.
  - `GET /photos?parent_class=Apartment&parent_id=…&update=…&ul_needed=1` renders a `<turbo-frame id="apartment_<id>_photos_list">`, NOT a legacy `<div class="list_container" id="…">`.
  - The same response includes a `.pagination` element (proving the gallery overflowed `per_page` and will_paginate emitted page links).
  - Per-row links carry both `data-remote="true"` AND `data-turbo="false"` so UJS keeps handling them.

### Notes

- Top-level lists (`/apartments`) intentionally stay on the legacy `<div>` for this slice. They already paginated full-page (no `:remote => true`), so wrapping them in a frame would not be a UJS conversion at all and would change pagination behavior to in-frame swap, which is a UX decision that belongs in a later slice rather than slipping in alongside the JS-transport conversion.
- `_tree.html.erb` and `_versions_list.html.erb` follow the same UJS+`js.erb` pattern as the nested branch of `_list.html.erb`. They are deliberately untouched in 7.2.0; this slice is meant as the pattern other lists copy.
- Drive remains globally disabled (`Turbo.session.drive = false` from 7.1.2). Frames work independently of Drive, so the nested list's frame swap is unaffected by that setting; full-page navigation in the rest of the app continues to be Rails defaults + UJS.

## [7.1.2] - 2026-05-05

### Added

- **Turbo (Hotwire) is now loaded in generated apps as an ES module**, completing rollout step 1 of `stuff/ujs-to-turbo.md` (gitignored): "Installer + reference app: Turbo wired end-to-end (layout, importmap, one smoke flow)". Both layouts (`app/views/layouts/inline_forms.html.erb`, `app/views/layouts/application.html.erb`) emit a `<script type="module">` immediately after the existing Sprockets `javascript_include_tag` that does `import { Turbo } from "<%= asset_path('turbo.min.js') %>"` and then `Turbo.session.drive = false`. `turbo.min.js` is already on the asset path (and on `config.assets.precompile`) via the `turbo-rails` gem (`Turbo::Engine`'s `turbo.assets` initializer adds `turbo.js`, `turbo.min.js`, `turbo.min.js.map` to `PRECOMPILE_ASSETS`), so no extra installer wiring is required.
- **Smoke test (`test/integration/example_app_turbo_layout_test.rb` in `--example` apps)**: signs in and `GET /apartments`, asserting the rendered HTML contains the `<script type="module">` import of `turbo.min.js` and the `Turbo.session.drive = false` line. Catches regressions where a layout edit drops the Turbo import (which would silently cause future `<turbo-frame>` conversions to fall back to full-page navigation).

### Changed

- **`app/assets/javascripts/inline_forms/inline_forms.js`**: updated the long Turbo comment to reflect that Turbo is now loaded by the layout as `<script type="module">` (with Drive disabled), instead of describing the `//= require turbo` regression as something deferred. The Sprockets bundle itself is unchanged: still `jquery`, `jquery_ujs`, `jquery.ui.all`, `jquery.timepicker`, `foundation`, `jquery.remotipart`, `autocomplete-rails`.
- **`lib/inline_forms/version.rb`**: `7.1.1` → `7.1.2`.

### Notes

- Drive is disabled (`Turbo.session.drive = false`) on purpose: every existing inline_forms link/form is still UJS (`remote: true` + `format.js` + `*.js.erb`) and Turbo Drive intercepting those requests (sending `Accept: text/html, application/xhtml+xml`) would re-trigger the same `ActionController::UnknownFormat` failure 7.1.1 fixed. With Drive off, Turbo is dormant for navigation; the `<turbo-frame>` custom element and `format.turbo_stream` rendering remain available, which is what the per-view conversions in rollout steps 2–5 will rely on.
- ESM `import { Turbo } from "/assets/turbo.min.js"` (instead of `import * as Turbo`) matches the named export of `turbo-rails` 2.x (`turbo.min.js` ends with `export { Turbo, cable }`). `window.Turbo = Turbo` is set so future inline scripts and Stimulus controllers can reach the same instance without re-importing.

## [7.1.1] - 2026-05-05

### Fixed

- **Generated apps from 7.1.0 raised `ActionController::UnknownFormat` on every form POST** (e.g. creating an Apartment). 7.1.0 added `//= require turbo` to the Sprockets bundle (`app/assets/javascripts/inline_forms/inline_forms.js`), but `turbo-rails` 2.x ships only an ES-module build (`turbo.js` / `turbo.min.js` end with `export { Turbo, cable }`). Sprockets concatenates that ESM source into a single `<script>` payload, where the top-level `export` is a syntax error; the browser stops parsing the bundle at that point, jquery-ujs never binds its `data-remote` handler, and the form submits as a plain HTML POST. Inline_forms controllers (`InlineFormsController#create`, `#update`, etc.) only declare `format.js`, so the request raises `UnknownFormat`. Removed the `//= require turbo` line and the related runtime `Turbo.session.drive = false` initializer from the bundle, with a comment in `inline_forms.js` explaining why and pointing at the rollout step that will load Turbo properly (as a `<script type="module">`) once the first view is actually converted to a Turbo Frame / Stream.
- **Reverted `data-turbo-track => "reload"`** on the main `javascript_include_tag` in both layouts (`app/views/layouts/inline_forms.html.erb`, `app/views/layouts/application.html.erb`) since Turbo is not loaded in this slice and the attribute is meaningless without it. (The previous `data-turbolinks-track` was likewise meaningless; both are dropped.)

### Notes

- `gem 'turbo-rails'` remains in the installer Gemfile (added in 7.1.0). That alone is what the foundation slice of `stuff/ujs-to-turbo.md` requires: server-side **Mime type / view format registration** so controllers can later return `format.turbo_stream` and views can use `<turbo-frame>`. Loading Turbo's JS into the page is deferred to the next slice (the first frame/stream conversion), which will inject Turbo as a `<script type="module">` so it does not collide with the Sprockets bundle.

## [7.1.0] - 2026-05-05 [YANKED]

Broken release: `//= require turbo` in the Sprockets bundle introduced a syntax error that disabled jquery-ujs and caused `ActionController::UnknownFormat` on every form submission. Superseded by 7.1.1.

### Added

- **Hotwire / Turbo foundation in generated apps**: installer Gemfile (`bin/inline_forms_installer_core.rb`) now adds `gem 'turbo-rails'`, which registers the `turbo_stream` Mime type and view format so controllers can opt in to `format.turbo_stream` and `<turbo-frame>` responses going forward.

## [7.0.4] - 2026-05-05

### Changed

- **Pin CarrierWave in generated apps (`bin/inline_forms_installer_core.rb`)**: `gem 'carrierwave'` → `gem 'carrierwave', '~> 3.1'`. CarrierWave 3.1 (released Dec 2024, latest 3.1.2 from Apr 2025) supports Rails 6.0–8.0, matches the gem's existing local-disk uploader pattern, and locks generated apps out of a hypothetical 4.x with breaking changes. No code/API change for uploaders themselves.

### Added

- **README section "File uploads (CarrierWave)"** documenting the upload story (CarrierWave 3.1, local filesystem under `public/uploads/`, default uploader from `rails generate uploader`), pointing at `carrierwave-aws` / fog for S3, and noting that generated apps also pull in ActiveStorage transitively to back ActionText embeds (`:rich_text` form element) — image uploads still use CarrierWave; ActiveStorage is only there for ActionText.

## [7.0.3] - 2026-05-05

### Fixed

- **PaperTrail did not record ActionText (`rich_text`) edits.** `has_rich_text :foo` stores its body in the polymorphic `action_text_rich_texts` table, not on the parent model, so `has_paper_trail` on (e.g.) `Apartment` could never see body edits. Recommended by paper_trail's maintainer in [stackoverflow #55544935](https://stackoverflow.com/questions/55544935/how-to-get-paper-trail-to-work-with-action-text); also applies to PaperTrail >= 13 and Rails 7.

### Added

- **`config/initializers/rich_text_paper_trail.rb` in generated apps (`bin/inline_forms_installer_core.rb`)**: declares `has_paper_trail` on `ActionText::RichText` via `ActiveSupport.on_load(:action_text_rich_text)`, so each rich-text save creates a `PaperTrail::Version` row whose `item_type` is `ActionText::RichText`.
- **`InlineFormsHelper#inline_forms_versions_for(object)` (`app/helpers/inline_forms_helper.rb`)**: returns the parent model's PaperTrail versions merged with versions of every associated `ActionText::RichText` record, sorted by `created_at`. Each entry carries its `:kind` (`:primary` or `:rich_text`) and, for rich-text entries, the attribute name (e.g. `"description"`).
- **Versions panel now surfaces rich-text edits (`app/views/inline_forms/_versions_list.html.erb`)**: iterates `inline_forms_versions_for(@object)` instead of `@object.versions`, labels rich-text rows as `update (rich text)`, renders body diffs under the rich-text attribute name (so a `description` edit shows up as `description`, not `body`), and omits noise columns (`record_id`, `record_type`, `name`) from the rich-text changeset display. Restore links remain on the parent rows only (the existing revert path doesn't know how to roll back a rich-text version).
- **Regression test extension** in `test/models/example_app_paper_trail_changeset_test.rb`: updates an `Apartment#description` (a `rich_text`) and asserts `inline_forms_versions_for` returns a rich-text entry whose `body` changeset moves between the old and new HTML.

## [7.0.2] - 2026-05-05

### Fixed

- **PaperTrail `version.changeset` was always empty in generated apps** (long-standing bug, predates the 7.0.1 PaperTrail upgrade). The inline_forms versions panel (`app/views/inline_forms/_versions_list.html.erb`) iterates `version.changeset`; under Rails 7 + PaperTrail >= 13 (and the older `acesuares/paper_trail` v12 fork) that call routes through `YAML.safe_load` with `ActiveRecord.yaml_column_permitted_classes` as the allow-list. Rails 7's default is `[Symbol]`, so the very first attribute in any update's `object_changes` (`updated_at`, an `ActiveSupport::TimeWithZone`) raised `Psych::DisallowedClass`; PaperTrail rescued that and returned `{}`, so every row in the versions list rendered as **`empty`**.

### Added

- **`config/initializers/paper_trail_yaml_safe_load.rb` in generated apps (`bin/inline_forms_installer_core.rb`)**: extends `ActiveRecord.yaml_column_permitted_classes` (and the matching `Rails.application.config.active_record.yaml_column_permitted_classes`) with `Symbol, Date, Time, BigDecimal, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, ActiveSupport::HashWithIndifferentAccess`. With this in place, `version.changeset` round-trips and the inline versions panel shows real diffs for `update` events.
- **Regression test** `test/models/example_app_paper_trail_changeset_test.rb` (added to the `--example` test bundle): creates and updates an `Apartment`, then asserts `version.changeset` is non-empty and contains the expected old/new tuples. Runs under `bundle exec rails test` in any new example app and would have caught this bug.

## [7.0.1] - 2026-05-05

### Changed

- **Generated app Gemfile (`bin/inline_forms_installer_core.rb`)**: depend on the canonical `paper_trail` gem from RubyGems (`gem 'paper_trail', '~> 16.0'`) instead of the long-frozen `acesuares/paper_trail` git fork. PaperTrail 16 supports ActiveRecord `>= 6.1, < 8.1` and Ruby `>= 3.0`, which matches this gem's Rails 7.0 / Ruby 3.2 target. Removes the "not compatible with ActiveRecord 7.0" boot warning that PaperTrail 12 (the fork's base) emitted.
- **Installer paper_trail step (`bin/inline_forms_installer_core.rb`)**: drop the `--with-mysql` flag. That option only exists on the `acesuares` fork (it is the fork's sole behavioral patch on top of upstream PaperTrail) and is not recognized by upstream PaperTrail. The generator now runs `paper_trail:install --with-changes` for both sqlite and mysql apps; PaperTrail detects MySQL via the live ActiveRecord connection, which is fine because the installer documents creating the mysql development database before this step (sqlite needs no pre-existing DB).

## [7.0.0] - 2026-05-05

### Changed

- **Target Rails 7.0.x**. `inline_forms.gemspec` now requires `rails >= 7.0.0, < 7.1`. Upgrades the gem from the Rails 6.1 / Webpacker era to the Rails 7.0 / importmap era.
- **Generated app Gemfile (`bin/inline_forms_installer_core.rb`)**: `gem 'rails', '~> 7.0.0'` (was `'6.1.3.1'`); add explicit `gem 'sprockets-rails'` (no longer in the default Rails 7 Gemfile but required by the gem's own `app/assets`); add `gem 'importmap-rails'` for the new default JS pipeline; drop `gem 'coffee-rails'` (unused by the gem itself, dead default in Rails 7).
- **`bin/inline_forms`**: `rails new` invocation drops `--skip-gemfile` (Rails 7 removed it) and `--skip-test-unit` (renamed in Rails 5; we let the default test scaffolding run in Rails 7 so `test/test_helper.rb` exists for the example app's regression tests). Adds `--javascript=importmap` so the generated app explicitly opts into Hotwire/importmap-rails (default in Rails 7, made explicit for clarity).
- **Generator migration template (`lib/generators/templates/migration.erb`)**: emits `ActiveRecord::Migration[7.0]`.
- **Installer migrations (`bin/inline_forms_installer_core.rb`)**: `DeviseCreateUsers`, `InlineFormsCreateJoinTableUserRole` and `InlineFormsCreateViewForTranslations` now use `ActiveRecord::Migration[7.0]`.
- **Generator unit tests (`test/inline_forms_generator_test.rb`)**: assert against `ActiveRecord::Migration[7.0]`.

### Fixed

- **Gemfile conflict on Rails 7 (`bin/inline_forms_installer_core.rb`)**: explicit `remove_file 'Gemfile'` before `create_file 'Gemfile'` so the installer template no longer prompts to overwrite the Gemfile that `rails new` (Rails 7) always creates.
- **Custom field types under Rails 7 (`lib/generators/inline_forms_generator.rb`)**: override `Rails::Generators::GeneratedAttribute.valid_type?` to always accept incoming types. Rails 7 removed the rescue around `ActiveRecord::Base.connection.valid_type?`, so the parser raised `NameError`/`Could not generate field` for our custom types (`:dropdown`, `:check_list`, `:image_field`, `:rich_text`, ...) and broke generator unit tests that don't load Active Record. Unknown-type detection still happens later via Thor::Error + `--allow-unknown`.

### Notes / known issues

- PaperTrail (currently sourced from the `acesuares/paper_trail` fork at v12.0.0) prints a "not compatible with ActiveRecord 7.0" warning on boot. Tests pass and the example app works end-to-end. A follow-up bump to PaperTrail 13+ is recommended but not required.

## [6.4.1] - 2026-05-05

### Fixed

- **`rich_text` form element (`app/helpers/form_elements/rich_text.rb`)**: `rich_text_edit` no longer relies on the non-existent `rich_text_area_tag` (Rails 6.1) which produced an empty cell on new and existing records. It now renders a hidden input + `<trix-editor>` pair tied by `input=` so the editor actually shows up inline.
- **`rich_text_show`**: more defensive handling of nil/blank ActionText values (uses `to_plain_text` when available) so the `+` placeholder shows on empty values and the rendered HTML shows on populated ones.

### Changed

- **Inline edit layout (`app/views/inline_forms/_edit.html.erb`)**: added `rich_text` to `@BUTTONS_UNDER` so the editor gets a full-width row with OK/Cancel below it (matching `text_area`).
- **Layouts (`app/views/layouts/{application,inline_forms}.html.erb`)**: include Trix 1.3.1 CSS+JS from unpkg so generated apps render the editor without bundling JS, and keep the existing CKEditor guard.

## [6.4.0] - 2026-05-05

### Added

- **New `rich_text` form element** (`app/helpers/form_elements/rich_text.rb`) for ActionText-backed attributes, including show/edit/update/info handlers compatible with inline editing.
- **Generator coverage** for ActionText declarations in `test/inline_forms_generator_test.rb` (`content:rich_text` emits `has_rich_text` and skips migration column generation).
- **Reusable workflow prompt docs** in `docs/prompt/test-the-example-app.md` with a local `docs/prompt/.gitignore`.

### Changed

- **Inline forms generator** now emits `has_rich_text :attribute` in generated models when the field type is `:rich_text` (`lib/generators/inline_forms_generator.rb`, `lib/generators/templates/model.erb`).
- **Installer template** moved generated apps from CKEditor setup to ActionText migrations (`active_storage:install` + `action_text:install:migrations`) and updates example resources to use `description:rich_text`.
- **Generated app Gemfile wiring** now points `inline_forms` to the local gem path during scaffold/install flow, so iteration testing uses current local code.

### Fixed

- **Layouts** no longer raise `uninitialized constant Ckeditor` when CKEditor is absent: CKEditor CDN script tags are now conditional in `app/views/layouts/application.html.erb` and `app/views/layouts/inline_forms.html.erb`.

## [6.3.4] - 2026-05-05

### Added

- **Generator regression harness** in `test/inline_forms_generator_test.rb` that runs `InlineForms::InlineFormsGenerator` against a temporary destination and asserts generated model/controller/route/migration output plus `_no_model` behavior.
- **Same:** coverage for unknown-type handling, including default strict mode and the explicit legacy opt-out via `--allow-unknown`.

### Changed

- **Generator hardening (`lib/generators/inline_forms_generator.rb`):** unknown field types now fail fast by default with a clear message listing the offending `name:type` pairs and how to opt into legacy behavior.

### Fixed

- **Same:** internal control attributes prefixed with `_` (such as `_no_model`, `_enabled`, `_no_migration`, `_id`) are excluded from unknown-type checks, so generator flags keep working under strict validation.
- **Generator tests (`test/inline_forms_generator_test.rb`):** require `logger` before `rails` so Bundler-based test runs are stable on Rails 6.1 / Ruby 3.2.

## [6.3.3] - 2026-05-03

### Added

- **`--example` installs regression tests** under `test/example_app/` and `test/integration/example_app_*_test.rb`, plus model coverage for the generated Photo/Apartment resources. Run them with **`bundle exec rails test`** in the new app.

### Changed

- **Example installer** no longer runs **`bundle exec rails s`** at the end (it blocked the shell). Start the server manually when you want to use the browser.

### Fixed

- **Sqlite `database.yml`** now includes a **`test`** database (`db/test.sqlite3`) so **`bundle exec rails test`** works in generated sqlite apps.
- Generated apps add a **`test`** Bundler group with **`minitest ~> 5.25`** so Rails 6.1’s test runner stays compatible (avoids Minitest 6 / **`railties`** **`line_filtering`** and parallelization API mismatches).

## [6.3.2] - 2026-05-03

### Fixed

- **Application template (`bin/inline_forms_installer_core.rb`):** generated apps use **`rails-i18n ~> 7.0`** from RubyGems instead of the **`svenfuchs/rails-i18n`** git default branch, which targets Rails 8+ and could not be resolved with pinned **`rails` 6.1.3.1**.
- **Same:** development **`sqlite3`** is pinned to **`~> 1.4`** so it matches ActiveRecord 6.1’s adapter expectation (avoids **`sqlite3` 2.x** activation errors during generators and boot).
- **Same:** **`sleep 1`** after **`paper_trail:install`** (two migrations in one second) and between translation **`inline_forms`** generators so migration version numbers stay unique.
- **Same:** when **`using_sqlite`** is true, run **`paper_trail:install --with-changes`** only (omit **`--with-mysql`**). The MySQL/InnoDB table options in the PaperTrail migration are invalid on SQLite and broke **`db:migrate`** for the sqlite example app.

## [6.3.1] - 2026-05-03

### Changed

- `**InlineFormsHelper#link_to_inline_edit**` uses `**edit_polymorphic_path**` instead of `**send('edit_' + object.class.to_s.underscore + '_path', …)**`.
- `**InlineFormsHelper#close_link**` and `**#link_to_destroy**` use `**polymorphic_path(object, …)**` instead of `**send(object.class.to_s.underscore + '_path', …)**`.
- Partial templates `**_close.html.erb**`, `**_edit.html.erb**`, and `**_new.html.erb**` use `**polymorphic_path**` for member and collection URLs instead of building helper names with `**send**`.
- `**_edit.html.erb**` form and cancel links now pass the record into `**polymorphic_path(@object, …)**` so the member path includes the resource id (required for conventional `**resources**` routes).

### Compatibility

- Intended to be **non-breaking** for typical ActiveRecord models with standard `**resources :model**` routing: URLs match Rails’ named helpers (`**edit_*_path**`, `**article_path**`, `**articles_path**`, etc.). Paths are derived from `**model_name**` / `**singular_route_key**` instead of `**class.name.underscore**`, which can differ only in unusual setups (e.g. a custom `**model_name**` that does not match the previous string).

### Development

- `**test/inline_edit_polymorphic_path_test.rb**` asserts parity between polymorphic helpers and named `**edit_article_path**`, `**article_path**`, and `**articles_path**` for a minimal `**resources :articles**` route set (no full app boot).

## [6.3.0] - 2026-05-03

### Removed

- Project-specific `absence_list` form element (`app/helpers/form_elements/absence_list.rb`). Applications that still need it should copy the old implementation into their own codebase.

### Changed

- `**InlineFormsHelper#link_to_inline_edit**` now requires keyword argument `**from_callee:**` (pass `**__callee__**` from the enclosing `*_show` method). The form element name for the edit request is derived with `String#delete_suffix('_show')` after stripping a leading `block in`  prefix when present. This replaces stack inspection via `Kernel#calling_method` / `caller` parsing.
- `**Kernel` patches** for `this_method` and `calling_method` were removed from `lib/inline_forms.rb` and `app/helpers/inline_forms_helper.rb`.

### Upgrade notes

- **Breaking:** Any custom code that called `link_to_inline_edit` with a fourth positional `form_element` argument must switch to `from_callee: __callee__` when the call is made from a `*_show` helper, or pass the appropriate callee symbol for your naming convention.
- **Breaking:** Models or apps that referenced the `absence_list` form element from this gem must drop that reference or vendor the removed helper.

### Development

- Run `bundle install` then `rake` (or `rake test`) to execute Minitest for `InlineForms.form_element_string_from_callee` (no Rails boot). The Rake task uses verbose mode so each test prints on its own line; failed assertions show the explanatory message from the test file.
- For end-to-end checks, generate a disposable app with `**bin/inline_forms create MyApp -d sqlite`** (uses RVM unless `--no-rvm`), or add the gem with `**gem "inline_forms", path: "/path/to/inline_forms"**` in a Rails app’s Gemfile, run `**rails g inline_forms …**`, migrate, and exercise the UI in the browser.