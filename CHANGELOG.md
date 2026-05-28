# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [8.1.18] - 2026-05-28

### Fixed

- **`Psych::DisallowedClass` (`ActiveRecord::Type::Time::Value`) in `FormElementShowcasesController#revert`.** A `:time` column (e.g. `FormElementShowcase#meeting_time`, a `:time_select` helper) stores its value as an `ActiveRecord::Type::Time::Value` — a `Time` subclass. PaperTrail serializes it under its real class name, so reverting (which calls `version.reify`, a path PaperTrail does *not* rescue) raised `Tried to load unspecified class: ActiveRecord::Type::Time::Value`. The generated `config/initializers/paper_trail_yaml_safe_load.rb` now also permits `ActiveRecord::Type::Time::Value`, `ActiveRecord::Type::Date::Value`, and `ActiveRecord::Type::DateTime::Value`, so revert and the versions panel round-trip date/time `_select` columns. (Previously-permitted `Time`/`Date` did not cover these subclasses — Psych matches the exact stored class name.)

### Changed

- **RVM is now optional, not required.** The `rvm` gem is no longer a runtime dependency of `inline_forms_installer`, and `inline_forms create` no longer hard-`require`s it. The CLI uses RVM (auto-creating a per-app gemset) only when the `rvm` gem is installed *and* the shell is inside an RVM environment; otherwise it installs without RVM (any version manager — rbenv/chruby/asdf/mise — or none, with Bundler isolating deps per app via `Gemfile.lock`). `--no-rvm` still forces the no-RVM path. To opt in to gemset integration, `gem install rvm` before creating the app.
- **Generated `.ruby-version` now matches the version manager in use.** Non-RVM installs get a *bare* `4.0.4` (honored by rbenv/chruby/asdf/mise); RVM installs keep `ruby-4.0.4` (RVM's `.ruby-version` reader rejects a bare version, which would break `rvm use .` and the per-app gemset). `InlineFormsInstaller::TARGET_RUBY_VERSION` is the canonical bare `"4.0.4"`; the Creator adds the `ruby-` prefix only when RVM is active. The installer also force-writes the file (Rails' `rails new` emits its own `.ruby-version`), avoiding an interactive overwrite prompt.
- **Generated app `Gemfile` no longer lists the runtime `gem 'rvm'`** (the app never used the RVM Ruby API at runtime). The RVM-based Capistrano deploy helpers remain in the `:development` group for the shipped `config/deploy.rb`.

### Added

- **Regression test:** a `FormElementShowcase` `meeting_time` (`:time_select`) PaperTrail version both reifies (revert path) and round-trips its `changeset` (versions-panel path) without raising `Psych::DisallowedClass`.

## [8.1.17] - 2026-05-28

### Fixed

- **`RecordNotUnique` on `photos.id` (and any primary record) when restoring a `destroy` version while the row still exists.** PaperTrail records a non-empty changeset for `destroy` events, so the versions panel shows a Restore link on `destroy` rows. Reverting a `destroy` reifies a record with the original primary key and `new_record? == true`; the normal undo (row currently deleted) path correctly INSERTs it, but once the row had already been restored a blind `save!` re-INSERTed the existing id and raised `SQLite3::ConstraintException: UNIQUE constraint failed: photos.id`. `revert` now upserts the primary record by PK (mirroring the 8.1.16 rich-text fix): when a row with that id already exists, the reified column values are copied onto it and saved in place, so restoring a `destroy` version is idempotent across repeated delete/undo cycles.

### Added

- **Regression test:** restore a Photo `destroy` version while the row still exists (panel Restore / replayed undo) must not raise `RecordNotUnique`.

## [8.1.16] - 2026-05-28

### Fixed

- **`RecordNotUnique` on `action_text_rich_texts.id` when undoing a delete more than once.** Restoring rich text after parent undo used `reify.save!`, which INSERTs the old primary key. A second delete/undo cycle (or an already-restored row) hit SQLite's unique constraint. Restoration now upserts by `(record_type, record_id, name)` and copies `body` only, and only the latest PaperTrail `destroy` version per attribute is applied.

### Added

- **Regression test:** nested Photo delete → undo → delete → undo.

## [8.1.15] - 2026-05-28

### Fixed

- **Post-delete undo on Apartment/Photo (and any model with `rich_text`) left `description` empty.** Undo only reified the parent row; ActionText bodies live in `action_text_rich_texts` and are removed on `destroy`, with separate PaperTrail `destroy` versions. `revert` now also reifies and saves each `ActionText::RichText` destroy snapshot that belonged to the restored parent (Apartment, nested Photo, `FormElementShowcase#description`, etc.).

### Added

- **Regression tests:** apartment row destroy+undo with `description` rich text; nested photo destroy+undo with `description` rich text.

## [8.1.14] - 2026-05-28

### Fixed

- **`example_app_showcase_row_turbo_test` broke `--example` installs.** The Empty-demo undo regression parsed the undo URL as `/revert/:id`, but member routes are `/form_element_showcases/:id/revert`. The installer gate failed (`131 runs, 1 failure`) and surfaced the misleading “Rails could not create the app 'MyApp', maybe because it is a reserved word…” message even though the app was generated. The test now matches the real path and loads the destroy version from PaperTrail.

## [8.1.13] - 2026-05-28

### Fixed

- **Post-delete undo restored the wrong PaperTrail version.** `destroy` stored `@undo_version = @object.versions.last` *before* `destroy`, so the undo link targeted the latest **update** (e.g. a `plain_text_area` edit). `revert` then reified that update — the state *before* the edit — so fields like `body_plain_area` on "Empty demo" came back blank. `@undo_version` is now taken after destroy so undo always targets the `destroy` event snapshot.

### Added

- **Regression test** on `FormElementShowcase` "Empty demo": edit `body_plain_area`, delete, undo, assert text and undo URL use the destroy version.

## [8.1.12] - 2026-05-28

### Fixed

- **`InlineFormsController#revert` and CanCan `check_authorization`.** `revert` is excluded from `load_and_authorize_resource`, but `authorize!` only ran on some branches — and after `return unless @parent`, so a nil PaperTrail `item` on a destroyed row (or any path that bailed out early) left `@_authorized` unset and raised `CanCan::AuthorizationNotPerformed`. Authorization now runs once at the top of the action via `revert_authorization_subject` (reified record, `ActionText::RichText` parent, live `item`, or an id-only stub for destroyed rows). The post-delete **undo** link in `row_destroyed.html.erb` now requests `turbo_stream` like the versions-panel Restore link, matching the `format.turbo_stream` response.

### Added

- **Regression test** `example_app_showcase_row_turbo_test.rb`: destroy + undo revert on `FormElementShowcase`.

## [8.1.11] - 2026-05-28

### Fixed

- **Installer's prerelease gem discovery now looks in `pkg/` too.** `Bundler::GemHelper.install_tasks` (the standard Rakefile boilerplate) puts `rake build` output in `pkg/`, not in the checkout root where `gem build` writes. 8.1.10's `dev_checkout_with_gems` + `install_prerelease_gems_from_roots!` only globbed the checkout root, so the moment a maintainer ran `rake build` the freshly-built gem was invisible — the installer fell back to whatever stale `<name>-*.gem` was still sitting in the root from a previous `gem build`. This is the exact shape that caused 8.1.10 to silently use 8.1.6 templates today (default RVM gemset had `inline_forms_installer 8.1.6` as its highest, the checkout root had only the stale `inline_forms-8.1.7.gem`, and the 8.1.8/8.1.9/8.1.10 builds were sitting in `/home/code/inline_forms/pkg/` where nothing was looking). Both helpers now glob `<root>/<name>-*.gem` and `<root>/pkg/<name>-*.gem`.

### Changed

- **Example-app gate caps test parallelism at `PARALLEL_WORKERS=2` by default.** Rails' minitest parallelizer defaults to `workers: number_of_processors`, which on a 20-core box forks 20 full Rails processes — each ~200-300 MB resident with the example app's gem stack (CarrierWave + Devise + PaperTrail + Foundation + tabs_on_rails + money-rails). On a memory-pressured host that's 4-6 GB of workers alone, on top of the parent installer/bundler state, and `systemd-oomd` can (and did, 2026-05-28 07:50:35) kill the whole terminal session before the gate finishes, with no useful signal back to the user. `PARALLEL_WORKERS=2` keeps the worker footprint to ~600 MB and roughly doubles wall-clock vs 20 workers — fine for a one-shot gate. The new `INLINE_FORMS_TEST_WORKERS` env override lets machines with RAM headroom crank it back up (`0` = Rails' default, any positive integer = pin to that count).

### Lockstep

- `inline_forms`, `inline_forms_installer`, and `validation_hints` bumped from 8.1.10 to 8.1.11 in lockstep, even though `inline_forms` (the engine) and `validation_hints` have no behavior change in this release — both are only here so the version trio stays in step.

## [8.1.10] - 2026-05-27

### Changed

- **`:decimal_field` is now a real `decimal(p, s)` column instead of a `varchar`.** The FormElementRegistry mapping moves from `:decimal_field => :string` to `:decimal_field => :decimal`, so `rails g inline_forms Foo price:decimal_field` now emits `t.decimal :price, precision: 10, scale: 2` (the sensible default — invoice/balance up to 99,999,999.99). This closes a long-standing inconsistency: `decimal_field` was the only "numeric" Tier 1 helper that stored its value as text, so `"ace"` would happily round-trip and `Foo.sum(:price)` was a runtime cast error. Existing apps generated before 8.1.10 keep their varchar columns until they migrate; only newly-generated tables get `:decimal`.
- **New CLI syntax: `name:decimal_field{p,s}` overrides precision/scale.** Mirrors Rails' built-in `name:decimal{p,s}` grammar. Examples: `latitude:decimal_field{9,6}` -> `decimal(9, 6)` (~11 cm GPS accuracy), `longitude:decimal_field{10,6}` -> `decimal(10, 6)`, `dose:decimal_field{6,3}` -> `decimal(6, 3)`. Rails' own `Rails::Generators::GeneratedAttribute.parse` only honors `{…}` on a hardcoded list of built-in types and glues the braces onto custom types as part of the type symbol; `inline_forms_attribute_overrides.rb` now pre-processes the suffix off `:decimal_field` and stores precision/scale in `attr_options` for the migration emitter to read.
- **`decimal_field_show` / `_edit` render `BigDecimal` as fixed-point.** Once the column became a real `:decimal`, `object[attribute]` started returning `BigDecimal`, whose `to_s` defaults to scientific notation (`"0.1234e2"`). Both helpers now call `value.to_s("F")` for BigDecimal and fall through to the generic `to_s` for legacy varchar values, so existing apps display correctly with either column shape.

### Added

- **`FormElementShowcase` demos the new `{p,s}` syntax.** Two new attributes (`latitude:decimal_field{9,6}`, `longitude:decimal_field{10,6}`) sit alongside `price:decimal_field` in the "Numbers" header, exercising both the default `(10, 2)` and explicit overrides. Seed values are Curaçao's Willemstad coordinates (`12.123456 / -68.987654`) — exactly representable in the chosen scale so the round-trip test is bit-identical rather than float-fuzzy.
- **`validates :price, latitude, longitude, numericality: …` in the showcase model.** Without an explicit validation, ActiveRecord silently casts `"ace"` to `BigDecimal("0")` on a `:decimal` column. The validation keeps the round-trip honest (the new integration test asserts a 422 on `"ace"`), and the `:latitude` / `:longitude` validations also pin the lat/lon ranges (±90, ±180).
- **Model + integration tests** cover the precision/scale schema (`columns_hash["latitude"].precision == 9`), the BigDecimal round-trip at full scale, the rejection of out-of-range GPS values, and the rejection of non-numeric input.

### Lockstep

- `inline_forms`, `inline_forms_installer`, and `validation_hints` bumped from 8.1.9 to 8.1.10 in lockstep, even though `validation_hints` has no behavior change in this release.

## [8.1.9] - 2026-05-27

### Fixed

- **`dropdown_with_values_show` and `dropdown_with_values_info` double-translated their labels.** `attribute_values` already runs each label through `t()` (it has to, so the values hash can use translation keys). The two show/info helpers then ran `t()` again on the *already-translated* string, so a missing translation rendered a bizarre `<span class="translation_missing" title="Low&quot;&gt;Low&lt;/Span&gt;">Low"&gt;Low&lt;/Span&gt;</span>` blob inside the inline-edit link (visible on `priority` / `priority2` in the showcase). The second `t()` call has been removed and the helpers now nil-guard the lookup, matching the 8.1.7 fixes to `dropdown_with_integers_show` and the two scale helpers.
- **`money_field_show` dropped cents on whole-dollar amounts.** money-rails defaults `humanized_money_with_symbol` to `no_cents_if_whole: true`, so `Money.from_amount(124.00, "USD")` rendered as `$124` while `Money.from_amount(12.34, "USD")` rendered as `$12.34` — inconsistent, and indistinguishable from a precision bug on values that *rounded* to a whole dollar (e.g. `Money.from_amount(123.999, "USD")` rounds up to 12400 cents because cents are the smallest Money unit; the helper now shows that as `$124.00`). The helper now passes `no_cents_if_whole: false` so the displayed amount always has two decimals.

### Changed

- **`FormElementShowcase` now demos `[:locales, :check_list]` + `[:locales_display, :info_list]` instead of `[:roles, :info_list]`.** Role is reserved for the auth Member/User model — reusing it on the showcase coincidentally shared rows with `roles_users` and obscured how the demo associations were coupled. The example app now seeds four locales (`en`/`nl`/`de`/`fr`, English is the default attached to the full demo) and a `has_and_belongs_to_many :locales` join, so the showcase exercises the editable HABTM editor (`check_list`) and the read-only mirror (`info_list`) side-by-side. The read-only row uses `alias_method :locales_display, :locales` because inline_forms keys turbo frames by attribute name, so two rows for the same association need two distinct names.
- **`start_month` label renamed to "Start month and year".** The widget is a month_year_picker; the old label hid the year half.
- **Full-demo seed now populates `attachment` / `jingle` / `cover`.** The installer ships `sample.txt`, `sample.wav` (440Hz / 0.5s mono PCM, generated with ffmpeg), and `sample_cover.png` under `lib/installer_templates/example_app_assets`, copies them into the generated app's `db/seed_uploads/`, and the seed migration hands File handles to CarrierWave so the three file-upload rows in the full demo render thumbnails / links instead of placeholders.

### Added

- **`ExampleAppShowcaseLocalesAssociationsTest` integration test.** Covers `check_list` toggling the HABTM (`locale_ids` add + remove via two PUTs), `info_list` rendering the `_presentation` for attached records, and the `--` empty-state placeholder. Replaces the dropped `roles`-based assertions in `ExampleAppShowcasePageRenderTest`.

### Lockstep

- `inline_forms`, `inline_forms_installer`, and `validation_hints` bumped from 8.1.8 to 8.1.9 in lockstep, even though `validation_hints` has no behavior change in this release.

## [8.1.8] - 2026-05-27

### Added

- **`money_field`, `scale_with_integers`, `scale_with_values` are back in the `FormElementShowcase`.** All three were dropped from 8.1.6 because their `_show` helpers crashed (`humanized_money_with_symbol` undefined, positional-index lookups against `[[key,label]]` pairs). 8.1.7 fixed the two `scale_*` helpers; 8.1.8 wires the missing money-rails dependency:
  - **money-rails wired into the installer Gemfile** (`gem 'money-rails', '~> 3.0'`). Adds the `humanized_money_with_symbol` view helper used by `money_field_show` and the `monetize` macro used in the showcase model.
  - **`config/initializers/money.rb` generated** with `MoneyRails.configure { default_currency = :usd }` so the showcase renders predictably under any host locale.
  - **`amount:money_field` column rewritten to `amount_cents:integer, default: 0, null: false`** in the generated create-table migration, and `monetize :amount_cents` declared on `FormElementShowcase`. That keeps the inline_forms attribute-list entry semantically correct (`[:amount, :money_field]`) — money-rails exposes the `amount`/`amount=` Money-aware accessors on top of the `_cents` column, so `obj.amount = "12.34"` parses to a Money and stores 1234 cents, and `obj.amount` reads back as `$12.34`.
  - **`scale_int:scale_with_integers` (`{ 1 => 'one', … 5 => 'five' }`) and `scale_val:scale_with_values` (`{ 1 => 'red', 2 => 'green', 3 => 'blue' }`)** added to the showcase with value hashes, locale labels, and seed values (`scale_int=3, scale_val=2` on the full demo; both `1` on the empty demo).
- **Showcase regression tests cover the three re-added fields.**
  - `money_field` round-trips `"12.34"` and asserts `amount_cents == 1234` (skipped if money-rails is not monetizing `:amount`, so the same test file still works for older host apps).
  - `scale_with_integers` and `scale_with_values` get round-trip integration tests structurally identical to the dropdown helper tests.
  - `EXPECTED_ATTRIBUTES` (model test) and `SHOWCASE_FIELD_ATTRIBUTES` (page-render test) updated to require all three frames to render on `/form_element_showcases/:id`.

### Fixed

- **`money_field_show` rendered an empty `<a>` when the value was `nil`/zero.** money-rails' `humanized_money_with_symbol(nil)` returns `""`, so the inline-edit link had no visible text. The helper now uses the standard `<i class="fi-plus">` empty-state placeholder for nil/zero values, matching `dropdown_with_values_show` / `radio_button_show` / the 8.1.7 scale fixes.

### Lockstep

- `inline_forms`, `inline_forms_installer`, and `validation_hints` bumped from 8.1.7 to 8.1.8 in lockstep, even though `validation_hints` has no behavior change in this release.

## [8.1.7] - 2026-05-27

### Fixed

- **`dropdown_with_integers` / `scale_with_integers` / `scale_with_values` `_show` helpers crashed on every non-trivial value.** All three did `attribute_values(object, attribute)[object.send(attribute)][1]` (or `[…].to_s` for `scale_with_integers`), i.e. they used `Array#[N]` against the `[[key, label], …]` array returned by `attribute_values` — that indexes positionally, not by key, so the stored integer was used as an array offset. Symptoms in the wild:
  - `dropdown_with_integers_show` on a `rating_int = 3` against `{1 => "One", 2 => "Two", 3 => "Three"}` returned `values[3]` → `nil`, then `nil[1]` raised `NoMethodError: undefined method '[]' for nil`. With smaller values it silently rendered the *next* label (`rating_int = 1` rendered `"Two"`).
  - `scale_with_integers_show` indexed an array with a string (`values[object.send(attribute).to_s]`), which raised `TypeError: no implicit conversion of String into Integer`.
  - `scale_with_values_show` had the same positional-index bug as `dropdown_with_integers_show` and crashed identically on out-of-range integers.
  
  All three now use `values.assoc(object.send(attribute))` so the stored value is matched against the *key* column of the pair, and gracefully fall back to the empty-state `<i class="fi-plus">` placeholder when no pair matches (matches the nil branch in `dropdown_with_values_show` and `radio_button_show`). Showcase row in the example app now renders `"One"` for `rating_int = 1` (was: `"Two"`), and the `scale_*` helpers no longer crash from the showcase page.

- **`Versions (N)` header flickered between `N` and `N+M` when the panel was toggled.** On a record whose associated `ActionText::RichText` has at least one PaperTrail version (e.g. the empty `FormElementShowcase` after a description edit), the closed `app/views/inline_forms/_versions.html.erb` partial counted `object.versions.length` (parent only, e.g. `7`) while the open `_versions_list.html.erb` partial counted `inline_forms_versions_for(@object).length` (parent + rich_text merged, e.g. `8`). The visible count therefore changed every time the user opened or closed the panel. Closed partial now uses the same `inline_forms_versions_for(object).length` so the header is stable and matches the number of rows the open panel actually shows. Verified against the running example app at `/form_element_showcases/4` after toggle.

- **`month_year_picker_update` left three debug `puts 'XXXXXX…'` lines in the helper.** They printed before/after values to STDOUT on every save (visible during `rails test` and in production logs) and added no diagnostic value. Removed. The helper now also no-ops on an empty/invalid `params[:attribute]` instead of letting `Date.parse("")` raise `Date::Error: invalid date` — the previous "always parse" version forced the showcase numericality test to thread a placeholder `start_month` through the create POST just to keep the unrelated update branch from crashing during the same controller cycle. With the rescue in place the helper degrades to `nil` and the rest of the update path keeps running.

### Lockstep

- `inline_forms`, `inline_forms_installer`, and `validation_hints` bumped from 8.1.6 to 8.1.7 in lockstep, even though `inline_forms_installer` and `validation_hints` have no behavior change in this release.

## [8.1.6] - 2026-05-27

### Added

- **FormElementShowcase example resource.** `inline_forms create … --example` now generates a fourth example model, `FormElementShowcase`, that declares every kept Tier 1 form_element helper on a single object. Coverage:
  - text-shaped: `text_field`, `plain_text_area`
  - numeric: `integer_field`, `decimal_field`
  - date/time: `date_select`, `time_select`, `month_select`, `month_year_picker`
  - choice: `check_box`, `radio_button`, `dropdown_with_integers`, `dropdown_with_values` (normal + `options_disabled`), `dropdown_with_values_with_stars`
  - files: `file_field`, `audio_field`, `image_field` (Cover reuses Photo's `ImageUploader`)
  - rich text: `rich_text`
  - display-only: `header` (6 section headers), `info` (`created_at`/`updated_at`), `info_list` (`has_and_belongs_to_many :roles` rendered read-only)
- **First field-level validation in the example app.** `validates :count, numericality: { only_integer: true }, allow_blank: true` on `FormElementShowcase`. The new integration test posts `count: "abc"` through the top-level create form and asserts the response re-renders the new form with the numericality error.
- **`dropdown_with_values_with_stars` ships its assets.** 5 small `<n>stars.png` PNGs are shipped under `lib/installer_templates/example_app_assets/` and copied into `app/assets/images/` at install time.
- **Showcase regression tests.** New integration tests cover text, numeric (incl. numericality negative), date/time, and choice/scale helpers, plus a full-page smoke test that asserts every per-attribute `<turbo-frame>` renders and the `info_list` empty-state branch is exercised. New model test pins the attribute list, the 8.1.5 row-shape `options_disabled` slot on `:priority2`, and the new numericality validation.
- **Showcase seed migration.** Seeds two `FormElementShowcase` rows (one fully populated with a role assigned, one empty), so the rendered demo at `/form_element_showcases/1` exercises every show branch out of the box.

### Dropped from previous draft

Per user choice:

- `text_area`, `text_area_without_ckeditor`, `plain_text` (redundant with `plain_text_area`).
- `ckeditor` (alias of `rich_text`; no behavior gap to exercise).
- `slider_with_values` (deferred; complex jQuery UI wiring).
- `multi_image_field` (deferred; needs array column + `mount_uploaders` plural override).

Per implementation discovery (runtime helpers are broken under the current code base; out of scope to fix here):

- `money_field` (helper calls `humanized_money_with_symbol`, a `money-rails` view helper that is not declared in the installer Gemfile).
- `scale_with_integers` (helper indexes the array returned by `attribute_values` with a string: `values[object.send(attribute).to_s]`, which raises `TypeError: no implicit conversion of String into Integer`).
- `scale_with_values` (helper does `values[object.send(attribute)][1]`, which raises `NoMethodError: undefined method '[]' for nil` whenever the stored integer is not a valid array index of the post-sorted values).

### Lockstep

- `inline_forms`, `inline_forms_installer`, and `validation_hints` bumped from 8.1.5 to 8.1.6 in lockstep, even though `validation_hints` has no behavior change in this release.

## [8.1.5] - 2026-05-27

### Changed (hard-breaking)

- **`inline_forms_attribute_list` rows are now 2-element by default.** The empty 2nd element (the unused human-name string) has been removed from every row across the gem, installer, generators, helpers, views, validators, tests, and docs. Labels have come from `Klass.human_attribute_name(attribute)` via locale files for a long time, so the slot was redundant. The migration in 8.1.5 makes that explicit by dropping the slot entirely.

  Old shape:

  ```ruby
  [ :name, "name", :text_field ],
  [ :sex, "sex", :radio_button, { 1 => 'f', 2 => 'm' } ],
  [ :sex, "sex", :dropdown_with_values, values_hash, options_disabled ],
  ```

  New shape:

  ```ruby
  [ :name, :text_field ],
  [ :sex, :radio_button, { 1 => 'f', 2 => 'm' } ],
  [ :sex, :dropdown_with_values, values_hash, options_disabled ],
  ```

  **This is a hard break.** Consumers that read positions inside the row (`attributes.assoc(:foo)[3]` for `attribute_values`, `attributes.assoc(:foo)[4]` for `dropdown_with_values`' `options_disabled`) have shifted to `[2]` / `[3]`. Any model file left in the old 3/4/5-element shape will silently misbehave (the empty string `""` will be returned where the values hash or `options_disabled` array used to be), so every existing `inline_forms_attribute_list` in downstream apps must be rewritten.

  Minimal migration for the common 3-element shape — run this once over `app/models/**/*.rb`:

  ```ruby
  # In your app's root, with a backup or in a clean git tree:
  Dir.glob("app/models/**/*.rb").each do |path|
    src = File.read(path)
    new = src.gsub(/\[\s*(:\w+)\s*,\s*["'][^"']*["']\s*,\s*(:\w+)\s*\]/) { "[ #{$1}, #{$2} ]" }
    File.write(path, new) if new != src
  end
  ```

  For 4/5-element rows (`dropdown_with_values`, `radio_button`, `scale_*`, `slider_*`, `check_box`, `simple_file_field`, `must_be_a_value` validator targets), drop only the empty 2nd element and keep the trailing `values` / `options_disabled` arguments unchanged.

### Changed (mechanical follow-through)

- **`InlineFormsGenerator`** and **`InlineFormsAddtoGenerator`** emit the new 2-element row shape.
- **Installer** (`inline_forms_installer/installer_core.rb`): hand-written `User` / `<custom>` model `inline_forms_attribute_list` rewritten; `gsub_file` injections for `Apartment#owner` and `Owner#apartments` updated to the new shape.
- **Runtime consumers** (`InlineFormsController#create`, `app/views/inline_forms/_show.html.erb`, `_new.html.erb`, `_new_nested.html.erb`, `InlineForms.validate_plain_text_configuration_for!`, `InlineForms.validate_no_archived_form_elements_for!`) updated their row destructuring to `|attribute, form_element|`.
- **Positional lookups** in `InlineFormsHelper#attribute_values`, `MustBeAValueValidator#attribute_values`, and `DropdownWithValuesHelper#…_edit` shifted from `[3]` / `[4]` to `[2]` / `[3]`.
- **Tests & docs:** all fixtures, assertions, and code samples (USAGE files, READMEs, `archived/*/README.md`) updated to the new shape.

### Notes

- **Example app gate (recorded):** `inline_forms create MyApp -d sqlite --example` against the freshly built **8.1.5** gem trio: install in ~73s, `bundle check: ok`, **88 runs, 502 assertions, 0 failures, 0 errors, 0 skips**. Gem unit tests: 42 runs, 240 assertions, 0 failures.

## [8.1.4] - 2026-05-26

### Fixed

- **Search box on `/users` (or `/members`, etc.) silently returned the full list.** The installer-generated user model declared `scope :inline_forms_list, -> { order(:name, :id) }` but **no** `inline_forms_search` scope, so `InlineFormsController#index`'s `merge(@Klass.inline_forms_search(params[:search]))` fell through to the `ApplicationRecord` no-op (`scope :inline_forms_search, ->(_q) { all }`) and emitted `SELECT … FROM users ORDER BY name ASC, id ASC LIMIT 7` — no `WHERE`, no filter, regardless of the search query. Installer's `User` / `<custom>` model template now ships `scope :inline_forms_search, ->(q) { where("name LIKE :q OR email LIKE :q", q: "%#{q}%") }`, so `/users?search=ad` now returns rows whose name or email matches `%ad%`. Custom user-model classes via `-U <Class>` get the same scope.
- **Top-bar "More" dropdown was empty in every generated app** (long-standing latent bug). `lib/generators/inline_forms_generator.rb#add_tab` looked for the marker `ActionView::CompiledTemplates::MODEL_TABS = %w(` in `app/controllers/application_controller.rb`, but the installer wrote the initializer at `config/initializers/inline_forms.rb` with the marker `MODEL_TABS = %w(` and the application controller had no marker at all. Thor's `inject_into_file` silently skipped (no error, no message), so `MODEL_TABS` stayed `%w()` through every `rails g inline_forms` call. The header partial (`app/views/inline_forms/_header.html.erb`) iterated an empty list and the dropdown rendered just the chevron with no children — for years.
  - `add_tab` now targets `config/initializers/inline_forms.rb` with the simpler marker `MODEL_TABS = %w(`, no-ops if the file or marker is missing (so consumers running `rails g inline_forms` in a non-installer-shaped app still work), and stays idempotent on re-run (skips the token if already present).
  - Installer's initializer is now created **before** the `Locale` / `Role` `generate "inline_forms"` calls (was created at the end of the run), and is pre-seeded with the user-model's pluralised route — `MODEL_TABS = %w(<plural_route> )` — because the user model is hand-written by the installer (not generated) and would otherwise never be added.
  - Net effect on a fresh `inline_forms create MyApp -d sqlite --example`: `MODEL_TABS = %w(owners apartments roles locales users )` (with `-U Member`: `… members `). The top-bar "More" dropdown now lists every HTML-reachable model the current `current_user` `can? :update`.

### Changed

- **Test skeleton (`test/inline_forms_generator_test.rb#build_destination_skeleton!`)** writes `config/initializers/inline_forms.rb` with `MODEL_TABS = %w()` (matching the installer) instead of the legacy `ActionView::CompiledTemplates::MODEL_TABS = %w()` in `application_controller.rb`. `test_generates_model_controller_route_migration_and_tab_injection` now asserts the token lands in the initializer.

### Notes

- **Example app gate (recorded):** `inline_forms create MyApp -d sqlite --example` against the freshly built **8.1.4** gem trio: install in ~71s, `bundle check: ok`, `MODEL_TABS = %w(owners apartments roles locales users )` in the initializer, **88 runs, 502 assertions, 0 failures, 0 errors, 0 skips**. Same result with `-U Member`, with `users → members` in `MODEL_TABS`.

## [8.1.3] - 2026-05-26

### Changed

- **PaperTrail 17.0:** generated app Gemfile bumped from `paper_trail ~> 16.0` to `paper_trail ~> 17.0`. PT 17 officially supports Rails 8.1 (it drops Rails 6.1 / 7.0 and Ruby 3.0 / 3.1, all out of scope here) and silences the "PaperTrail 16.0.0 is not compatible with ActiveRecord 8.1.3" boot warning that PT 16 emitted under our 8.1 stack. No installer / engine code changes needed — `has_paper_trail`, the rich-text mirror initializer, and the YAML safe-load initializer all work unchanged.

### Added

- **`inline_forms create -U <Class>` collision check.** The installer always generates `Locale` and `Role`; with `--example`, it also generates `Photo`, `Apartment`, and `Owner`. Passing `-U Locale|Role` (with or without `--example`) or `-U Photo|Apartment|Owner` together with `--example` previously aborted halfway through with a Thor `conflict app/models/<name>.rb` prompt because the user model file (generated first) was about to be overwritten by the example app's `rails g inline_forms <Name>`. `Creator#create` now rejects these combinations up front with an actionable red error before `rails new` runs.

### Notes

- **Example app gate (recorded):** `inline_forms create MyApp -d sqlite --example` against the freshly built **8.1.3** gem trio on `rails 8.1.3` / `paper_trail 17.0.0`: install completes cleanly (no PT compatibility warning), `bundle check: ok`, **88 runs, 502 assertions, 0 failures, 0 errors, 0 skips**.

## [8.1.2] - 2026-05-26

### Changed

- **Rails 8.1:** engine and installer pin **`rails >= 8.1, < 8.2`** (resolved **8.1.3**) and **`rails-i18n >= 8.1, < 9.0`** (resolved **8.1.0**). Generated apps' `config/application.rb` is normalised to **`config.load_defaults 8.1`** and the installer prefers **`rails _8.1.x_`** for `rails new`. All generator and installer migrations now emit **`ActiveRecord::Migration[8.1]`** (`lib/generators/templates/migration.erb`, `lib/generators/templates/add_columns_migration.erb`, `DeviseCreateUsers`, `InlineFormsCreateJoinTableUserRole`, `AddOwnerToApartments`, `SeedExampleApartmentsAndOwners`).
- **`validation_hints` constraint:** widened to **`>= 8.1.2, < 9.0`** so Bundler picks up the matching companion release that targets `activerecord >= 8.1`.
- **README.rdoc:** requirements table and `rails-i18n` narrative updated to **Rails 8.1.x** / `~> 8.1` / `config.load_defaults 8.1`.
- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **8.1.2** (lockstep with **validation_hints 8.1.2**).

### Notes

- **Example app gate (recorded):** `inline_forms create MyApp -d sqlite --example` against the freshly built **8.1.2** gem trio on `rails 8.1.3`: install completes in ~77s, `bundle check: ok`, **88 runs, 502 assertions, 0 failures, 0 errors, 0 skips**. A subsequent `bundle exec rails test` in the generated app reproduces the same result in ~1.9s.
- **PaperTrail 16.0.0 / ActiveRecord 8.1 warning:** PT emits a compatibility warning during boot (it pins `< 8.1` internally) but does not raise; all PaperTrail-backed integration and model tests pass on AR 8.1.3. Revisit pin when paper_trail ships an 8.1-compatible release; no behaviour change needed in inline_forms for now.
- **Frozen-string warnings:** Ruby 4.0's `--debug-frozen-string-literal` surfaces literal-string warnings from `tabs_on_rails 3.0.0` and one inline_forms helper (`check_list_helper.rb:13`); these are non-fatal under current Ruby and tracked separately.

## [8.1.1] - 2026-05-26

### Added

- **`rails g inline_forms_addto <Model> attr:type [...]`:** new generator that adds fields to an *existing* inline_forms model. Emits an additive migration (`add_column` for scalars, `add_reference :table, :name, foreign_key: true` for `:belongs_to`/`:references`/`:dropdown`, single `:string` column for `:image_field`/`:audio_field`; no column for `:rich_text`/`has_many`/`has_one`/`habtm`) and edits the model file: injects `belongs_to` / `has_many` / `has_one` / `has_and_belongs_to_many` / `has_rich_text` / `mount_uploader` lines (idempotent), and inserts new rows into the model's `inline_forms_attribute_list` (handles both the generator-shaped and the installer's hand-written `User`/`Member` block). Does NOT touch routes, controller, or `MODEL_TABS` — those are already wired for the existing model. Use case: extending the narrow `User` (or `--user-model Member`) shipped by the installer with app-specific fields like `occupation`, `birthdate`, `organization:dropdown`, `bio:rich_text` without hand-writing migrations or attribute-list edits. Plan: [`stuff/inline_forms_addto.md`](stuff/inline_forms_addto.md).
- **`--allow-unknown` parity** with `inline_forms`: unknown field types raise `Thor::Error` by default; pass `--allow-unknown` to keep the legacy commented output (`#    add_column …`, `#     [ :name , "name", :unknown ]`).
- **`--replace`** flag: opt-in rewrite of existing `_presentation` / `_list_order` (and the legacy `_order`) / `_list_search` scopes/methods. Without `--replace` these special names are skipped with `say_status :skipped` so re-runs don't silently mutate the model's ordering/search policy.

### Changed

- **Refactor — `Rails::Generators::GeneratedAttribute` overrides moved to `lib/generators/inline_forms_attribute_overrides.rb`** and shared by both `InlineFormsGenerator` (`rails g inline_forms`) and the new `InlineFormsAddtoGenerator` (`rails g inline_forms_addto`). Pure refactor: same `column_type` / `attribute_type` / `relation?` / `migration?` / `attribute?` / `SPECIAL_GENERATOR_NAMES` semantics, now qualified with `InlineForms::` constants so the file works outside the `module InlineForms` lexical scope.

### Notes

- The new generator class is top-level (`InlineFormsAddtoGenerator`, not `InlineForms::InlineFormsAddtoGenerator`) so `rails g inline_forms_addto …` resolves directly. Rails' generator lookup only collapses `name:name` namespaces (the `inline_forms:inline_forms` → `inline_forms` rule that `InlineFormsGenerator` relies on). A `module InlineForms; InlineFormsAddtoGenerator = ::InlineFormsAddtoGenerator; end` alias is provided for any programmatic invokers that reach for the namespaced constant.

## [8.1.0] - 2026-05-25

### Added

- **`ApplicationRecord` template carries shared model behavior:** `has_paper_trail on: [:create, :update, :destroy]`, `attr_writer :inline_forms_attribute_list`, `self.per_page = 7`, `human_attribute_name` instance wrapper, and `def self.not_accessible_through_html?` default. Generated models inherit all of this; `lib/generators/templates/model.erb` only emits per-model differences (associations, `inline_forms_attribute_list`, `_presentation`, `<=>`, `not_accessible_through_html?` override when `_enabled` is absent).
- **`scope :inline_forms_list, -> { all }` and `scope :inline_forms_search, ->(_q) { all }`** on `ApplicationRecord`. Both are no-ops by default; subclasses opt in. Replaces the old `def self.order_by_clause` contract with composable Active Record relations.
- **Generator flags `_list_order:col` and `_list_search:col`:** emit `scope :inline_forms_list, -> { order(:col, :id) }` and `scope :inline_forms_search, ->(q) { where("col LIKE ?", "%#{q}%") }` respectively. `_list_order` also still emits `def <=>(other)` for in-memory sort on associations (used by `check_list` show). Tie-break on `:id` is added automatically so will_paginate pages stay stable.
- **`SPECIAL_GENERATOR_NAMES` constant** in `InlineForms::InlineFormsGenerator` consolidates `_presentation`, `_order`, `_list_order`, `_list_search`, `_enabled`, `_id`, `_no_migration`, `_no_model` so `migration?` / `attribute?` no longer drift.

### Changed

- **`order_by_clause` is gone from the gem.** `InlineFormsController#index` / `#create`, `check_list_helper.rb`, and `app/views/inline_forms/_list.html.erb` now compose `merge(@Klass.inline_forms_list)` and `merge(@Klass.inline_forms_search(params[:search]))` instead of building raw `"table.col"` strings. Search and order are now independent (one column had to do both jobs before); models can declare each separately or neither.
- **Per-page pagination fix in `ApplicationRecord`:** `self.per_page = 7` (class-level, what will_paginate's `class_attribute :per_page` reads). The old `attr_reader :per_page` + `@per_page = 7` instance pair on every generated model was a no-op (described at length in 8.0.x notes); models that need a different value override with `self.per_page = N` (Photo uses `5`). The installer’s Photo override now uses `inject_into_class "app/models/photo.rb", "Photo", "  self.per_page = 5\n"` instead of patching the legacy `attr_reader` block out.
- **`_order:col` is deprecated as an alias for `_list_order:col`.** Still works (emits the same scope plus `<=>`); the generator prints `say_status :deprecated, "_order:col is deprecated; use _list_order:col"` so existing scripts keep generating but the migration path is visible.
- **Installer User model:** dropped `default_scope { order :name }` and the `def self.order_by_clause; nil; end` stub. Added `scope :inline_forms_list, -> { order(:name, :id) }` with a comment about why named scopes beat `default_scope` (no `unscope`/`reorder` foot-guns; cleaner `update_all` / association inheritance).
- **Installer example-app generator calls** for `Locale`, `Role`, `Photo`, `Apartment`, `Owner` now pass `_list_order:name` (and `_list_search:name` for the searchable top-level models `Apartment` and `Owner`) to declare ordering and search explicitly. Replaces the implicit `order_by_clause = "name"` default that the old generator produced.

### Removed

- **`lib/generators/assets/javascripts/`** (including the empty `ckeditor/` subfolder). Leftover from the CKEditor era; nothing in the gem or installer copied from it. The engine still ships JS under `app/assets/javascripts/` and `vendor/assets/javascripts/`.
- **`lib/generators/assets/stylesheets/inline_forms.scss`** mirror. The installer doesn't copy it; the gem stylesheet at `app/assets/stylesheets/inline_forms/inline_forms.scss` is the single source consumed via `@use "inline_forms/inline_forms"`. `inline_forms_devise.css` stays — it is the host-app override hook copied by the installer and linked from `layouts/devise.html.erb`.

### Migration notes

Existing apps upgrading from 8.0.x:

1. Replace your `app/models/application_record.rb` with the contents of `lib/generators/templates/application_record.rb` (or just merge in the new `has_paper_trail`, `self.per_page`, `inline_forms_list` / `inline_forms_search` scopes, and `not_accessible_through_html?` default).
2. For each model that had `def self.order_by_clause; "col"; end`, replace with `scope :inline_forms_list, -> { order(:col, :id) }`. Drop the old method; the gem no longer reads it.
3. If you used `default_scope { order(:name) }` for inline_forms list ordering, swap to the named scope above.
4. Per-model `attr_reader :per_page` / `@per_page = N` pairs are no-ops; replace with `self.per_page = N` (or remove and inherit `7` from `ApplicationRecord`).
5. `_order:col` in your generator scripts still works but emits a deprecation notice; switch to `_list_order:col` and add `_list_search:col` if you want the search box to filter on that column.

## [8.0.4] - 2026-05-24

### Added

- **`inline_forms create --user-model` (`-U`):** choose the Devise-backed model class (e.g. `Member`). Default remains `User`. Non-default models use `devise_for :users, class_name: "…", path: "…"` so Warden scope stays `:user` (`current_user`, `destroy_user_session_path`, etc.). Installer generates matching table, routes, controller, Locale/Role associations, HABTM join table (`members_roles`, etc.), seeds, Ability guest user, and `--example` test substitutions.

### Changed

- **`version_modified_by`:** resolves the auth model via `Devise.mappings[:users]` instead of hard-coding `User` (PaperTrail “modified by” on custom auth models).

## [8.0.3] - 2026-05-22

### Added

- **Rails 8 release docs (Phase 5):** [`docs/rails-8-release.md`](docs/rails-8-release.md) (gate results, stack table); [`docs/zeitwerk-and-load-paths.md`](docs/zeitwerk-and-load-paths.md) (intentional ignores vs autoloaded paths).
- **Example app gate (recorded):** `inline_forms create MyApp -d sqlite --example` → **88 runs, 502 assertions, 0 failures**; `rails zeitwerk:check` → clean.

### Changed

- **Rails 8 (Phase 4):** framework-defaults audit documented in [`docs/rails-8-phase4-audit.md`](docs/rails-8-phase4-audit.md); generated apps stay on `load_defaults 8.0` only (no `new_framework_defaults_8_0.rb`, matching `rails new` 8.0.5).
- **Unicorn template:** `before_fork` uses `ActiveRecord::Base.connection_pool.disconnect!` (Rails 8–compatible).
- **README.rdoc:** requirements table for Ruby 4 / Rails 8 / validation_hints 8; remove stale “broken after 6.2.14” notice; `rails-i18n ~> 8.0` narrative.
- **`inline_forms.gemspec`:** summary/description updated for Rails 8 (remove stale “broken after 6.2.14” text).

## [8.0.2] - 2026-05-22

### Changed

- **Rails 8 (installer):** `inline_forms create` prefers **`rails` 8.0.x** for `rails new`; generated Gemfile pins **`rails ~> 8.0`**, **`rails-i18n ~> 8.0`**, **`config.load_defaults 8.0`**; installer migrations **`[8.0]`**; dev/test **`sqlite3 >= 2.1`** (Phase 3).
- **Pre-release gem install:** before `bundle install`, installs built **`*.gem`** files from **`INLINE_FORMS_RELEASE_ROOT`** / **`VALIDATION_HINTS_ROOT`** (auto-discovered from `~/code/inline_forms` and `~/code/validation_hints` when present) into the app RVM gemset so unreleased 8.x gems resolve without Gemfile path pins.
- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **8.0.2** (lockstep with **validation_hints**).

## [8.0.1] - 2026-05-22

### Changed

- **Rails 8 (engine):** `inline_forms` gemspec requires **`rails >= 8.0`, `< 8.1`**, **`rails-i18n >= 8.0`, `< 9.0`**, **`validation_hints >= 8.0.1`, `< 9.0`** (Phase 2). Generator migrations emit **`ActiveRecord::Migration[8.0]`**.
- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **8.0.1** (lockstep with **validation_hints**).

### Note

- **`inline_forms_installer` / `--example` app** still pins **Rails 7.2** in the template until Phase 3.

## [8.0.0] - 2026-05-22

### Added

- **`stuff/rails8forReal.md`:** consolidated Rails 8 migration runbook; Phase 0 baseline recorded.

### Fixed

- **`Gemfile`:** `gemspec name: "inline_forms"` (dual gemspec repo); `tabs_on_rails ~> 3.0` for engine tests.
- **`test/test_helper.rb`:** load Rails + `FormElementRegistry.apply!` so generator tests resolve `:dropdown` and similar types.
- **`InlineFormsGenerator#add_tab`:** read `application_controller.rb` under `destination_root` (fixes generator unit tests).

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **8.0.0** (lockstep with **validation_hints**).
- **Gemspec / installer Gemfile:** `inline_forms` and `validation_hints` pinned at **`~> 8`** (stack still **Rails 7.2.x** until Rails 8 migration phases complete).

## [7.13.18] - 2026-05-22

### Removed

- **DB-backed translations:** installer no longer generates `InlineFormsLocale`, `InlineFormsKey`, `InlineFormsTranslation`, or the `translations` SQL view migration. Removed `InlineForms::TranslationRecord`, `InlineFormsController#extract_translations`, its view, and YAML-export helpers (`deep_hashify`, `deep_merge`, `unravel`). Apps use standard Rails I18n YAML under `config/locales/` (e.g. `inline_forms_local.en.yml`); the old `i18n-active_record` path was never wired.

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **7.13.18** (lockstep with **validation_hints**).

## [7.13.17] - 2026-05-21

### Fixed

- **Misleading version banner during `inline_forms create`:** the opening line ("Creating MyApp with inline_forms vX...") used `Gem::Specification.find_by_name("inline_forms").version`, i.e. whatever happened to be in the Creator's own gemset, which can differ from what Bundler then resolves for the generated app (since the Gemfile pins `~> 7`). The banner now reports the constraint (`inline_forms ~> 7`) instead of an exact version.
- **Install summary now reads the actual locked versions** of `inline_forms` and `validation_hints` from the generated app's `Gemfile.lock`, so the post-create summary line reflects what's truly in the app (and surfaces drift if the Creator's gemset and the app's gemset disagree).

## [7.13.16] - 2026-05-21

### Fixed

- **`inline_forms create` gemset switch (real fix):** in 7.13.15 the helper bailed via `defined?(RVM) && RVM.current` *before* `require "rvm"`, so inside the `rails new` subprocess (which had not loaded the rvm gem) it always returned without switching. Now require rvm first; if the gem is unavailable, log and skip; otherwise switch via `RVM.use_from_path! "."` after `.ruby-gemset` is written. Result: `bundle install`, the example tests, and the post-create `bundle check` all run inside the app's gemset (`@MyApp` for `inline_forms create MyApp`), and `cd MyApp && rails s` no longer reports missing gems.

## [7.13.15] - 2026-05-21

### Fixed

- **RVM gemset during `inline_forms create`:** switch to `@MyApp` (or app name) only after `.ruby-gemset` exists, so `bundle install` and example tests install gems into the app gemset—not plain `ruby-4.0.4`.
- **Install summary `bundle check`:** run with `rvm use .` from the app directory so it reflects the app gemset, not the CLI gemset used to run `inline_forms create`.

## [7.13.14] - 2026-05-21

### Fixed

- **Install log:** header (`Install log: …` at top), test output (`tee -a`), and closing summary are all written into `MyApp/log/inline_forms_create-*.log` (not only on the terminal).
- **`--example` test summary:** read from the install log after create (ENV set inside `rails new` did not reach the Creator parent process).

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **7.13.14** (lockstep with **validation_hints**).
- **Gemfile header:** records `inline_forms_installer` version, not the resolved `inline_forms` engine version.

## [7.13.13] - 2026-05-21

### Added

- **`InlineFormsInstaller::CreateLog`:** timestamped install log at `MyApp/log/inline_forms_create-YYYYMMDD-HHMMSS.log`; path printed at start and end of `inline_forms create`; end-of-run summary (duration, versions, `bundle check`, test line).

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **7.13.13** (lockstep with **validation_hints**).
- **`--example`:** always runs `bundle exec rails test` during create; removed `--run-test` Thor option.
- **Post-create CLI message (1C):** removed redundant Creator footer; yellow “Done! Example app…” block remains.
- **`validation_hints` local `.gem`:** only when `VALIDATION_HINTS_ROOT` is set (2C).
- **`gem install` in installer:** `--no-document` for bundler and optional validation_hints (3B).
- **Generated Gemfile:** `foreman` in `:development` (7B).
- **`inline_forms` generator:** skip duplicate `MODEL_TABS` inserts when tab already present (6B).
- **Rails 8 checklist:** Dart Sass deprecation note in Phase 4 (`validation_hints/stuff/rails-8-checklist.md` + `inline_forms/stuff/rails-8-checklist.md` mirror).

## [7.13.12] - 2026-05-20

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **7.13.12** (three-gem lockstep with **validation_hints**).
- **`installer_core.rb`:** `bundle_install!` runs `bundle install` + `bundle check` and **aborts** app generation if either fails (avoids a finished `MyApp` with `Gemfile.lock` but missing `inline_forms` / `validation_hints` in the RVM gemset).
- **`InlineFormsInstaller::Creator`:** prints `rvm use .`, `bundle install`, and `bundle exec rails test` after a successful create.

## [7.13.11] - 2026-05-20

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **7.13.11** (three-gem lockstep with **validation_hints**).
- **`rake install:local`:** optional task to `gem install` built gems from `pkg/`.
- **`rake release:all`:** build + tag + RubyGems push only (no MyApp, no `install:local`).

## [7.13.10] - 2026-05-20

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → **7.13.10** (three-gem lockstep with **validation_hints**).
- **Generated app Gemfile:** `inline_forms` and `validation_hints` pinned at `~> 7` (Bundler resolves the highest 7.x), not `~> 7.13` / exact installer version.
- **`inline_forms` gemspec:** `validation_hints ~> 7`.
- **`inline_forms_installer` gemspec:** `inline_forms ~> 7` (not locked to installer version).
- **`InlineFormsInstaller::Creator`:** removed install-time check that installer and engine versions must match.
- **`README.rdoc`:** documents `~> 7` pins and joint releases instead of matching versions at `gem install` time.

## [7.13.9] - 2026-05-20

### Changed

- **`InlineForms::VERSION`**, **`InlineFormsInstaller::VERSION`**, and **`ValidationHints::VERSION`** → **7.13.9** (three-gem lockstep; publish all three to RubyGems together via `rake release:all` plus `validation_hints` release).
- **`inline_forms_installer` gemspec:** depends on `inline_forms ~> <installer version>` so `gem install inline_forms_installer` pulls a matching engine.
- **`InlineFormsInstaller::Creator`:** aborts before `rails new` when the installed `inline_forms` gem version differs from `inline_forms_installer` (avoids `validation_hints ~> 6.3` vs `>= 7.13` resolver failures). Defines `exit_on_failure?` for Thor.
- **`README.rdoc`:** documents that `inline_forms`, `inline_forms_installer`, and matching `validation_hints` must share the same release; `gem install inline_forms_installer` installs the CLI (not `gem install inline_forms` alone).

## [7.13.8] - 2026-05-20

### Added

- **`README.rdoc`: "Where to put the `tabs_tag` block (five patterns)" section** under `== Per-resource Turbo tabs`. Documents the five common ways to wire a Turbo-driven tab strip in an inline_forms app, each with a runnable code snippet and a "best when ..." recommendation:
  1. **Inlined in the show view** — drop the `tabs_tag` block straight into `show_with_tabs.html.erb`, no partial.
  2. **Dedicated tab-strip partial** (the `--example` app's pattern) — strip lives in `_<resource>_tabs.html.erb` and iterates over a controller constant.
  3. **Helper-driven, reusable across resources** — extract into `InlineFormsTabsHelper#inline_forms_turbo_tabs_for(object, tabs, update:, i18n_scope:)` so multiple resources opt in with one line.
  4. **One partial per tab content** — `app/views/<resource>/tabs/_<tab>.html.erb` per tab; each tab owns its own markup (charts, custom forms, mixed-resource pages) instead of going through `inline_forms/_show`.
  5. **Grouped tab strips** — render two or more `tabs_tag` blocks side-by-side (e.g. an "info" group + a "process" group on a `Client` detail page), each with its own `open_tabs` class / id but sharing `set_tab` / `current_tab?` so the active highlight always lands on the one tab matching `params[:tab]`.
  The section closes by noting that every option uses the same Turbo wiring (`link_options: { data: { turbo_frame: @update_span } }` on the `<a>`, surrounding `<turbo-frame id="<%= @update_span %>">` in the show view, controller `set_tab` + `params[:tab]`) and that the `InlineForms::TurboTabsBuilder` choice is independent of the partial layout.

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → `7.13.8`.

## [7.13.7] - 2026-05-20

### Added

- **Example app seed migration `SeedExampleApartmentsAndOwners`** (`installer_core.rb`). Replaces the old `SeedKonferenshaPhotos` migration. Seeds three apartments (`Apt 1`, `Apt 2`, `Apt 3`) with one photo gallery each (`db/seed_images/apt<N>_*.png`) and three owners — Maria Martinez (owns Apt 1 + Apt 2), Jean-Pierre Dupont (owns Apt 3), Akira Tanaka (owns none) — so the new per-owner `:check_list` sub-tab has zero / one / many cases out of the box. Idempotent via `find_or_create_by!`.
- **`pics/` shipped as 9 CC0 PNG placeholders** (640x480 pastel + apartment label) generated with ImageMagick. The folder is still `.gitignore`d, but the gem repo's working copy is now populated so `inline_forms create MyApp --example` picks them up without any extra steps. The old conference jpgs (`dsc*.jpg`) were removed.

### Changed

- **`InlineForms::TurboTabsBuilder` now emits Foundation-friendly active markup.** The active tab label is rendered as an hrefless `<a aria-current="page" aria-selected="true">` (previously a plain `<span>`) so Foundation 6's `.tabs-title.is-active > a` / `[aria-selected='true']` rules in `_tabs.scss` style it identically to the inactive tabs. The active `<li>` keeps the `active_class` (now `is-active` in the example app via `tabs_tag active_class: "is-active"`), letting the bundled `foundation-tabs` mixin render the strip horizontally with the correct padding / colors instead of as a bare bullet list.
- **`app/views/owners/_owner_tabs.html.erb`** now passes `class: "tabs-title"` per tab + `active_class: "is-active"` and `data-tabs: ""` on the wrapping `<ul class="tabs">`, matching the Foundation 6 tabs DOM contract.
- **Owner#apartments is now a `:check_list`** (was `:associated`). The user picks from a checklist of *existing* apartments rather than building a new nested apartment under the owner; assignment is done via Rails' built-in `apartment_ids=` setter on the `has_many`, which sets / clears `apartments.owner_id` accordingly. `CheckListHelper` already works against `has_many`, no helper changes needed; only the form-element kind in `Owner#inline_forms_attribute_list` changes.
- **`README.rdoc`** documents the seed data, the `:check_list` change, and the new Foundation 6 tab markup.
- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → `7.13.7`.

### Removed

- **`SeedKonferenshaPhotos` migration** in generated apps. Replaced by `SeedExampleApartmentsAndOwners` (see above). The matching `pics/dsc*.jpg` conference photos were dropped from the gem repo.

## [7.13.6] - 2026-05-20

### Added

- **`InlineForms::TurboTabsBuilder`** (`lib/inline_forms/turbo_tabs_builder.rb`) — drop-in subclass of `TabsOnRails::Tabs::TabsBuilder` that threads a new `:link_options` item option through to the tab's `<a>` (upstream 3.0's `tab_for(tab, name, url_options, item_options = {})` only annotates the surrounding `<li>`). Turbo-shaped replacement for the historical `acesuares/tabs_on_rails` `update_remote_before_action` branch (which added `:remote => true` for UJS); now any `data: { turbo_frame: "…" }` (or other html option) survives the builder and lands on the link, enabling per-resource Turbo-Frame tab swaps without re-introducing the fork. Active-tab highlighting is unchanged (still driven by `set_tab` / `current_tab?`).
- **Example app `Owner` model + per-owner sub-tabs** (`installer_core.rb`, `lib/installer_templates/example_app_views/owners/`):
  - `rails g inline_forms Owner name:string birthdate:date address:string city:string country:string apartments:has_many apartments:associated _enabled:yes _presentation:'#{name}'`
  - Migration `add_owner_to_apartments` adds `owner_id` (nullable FK).
  - `Apartment` gains `belongs_to :owner, optional: true` and a leading `[ :owner, "owner", :dropdown ]` entry in `inline_forms_attribute_list`.
  - `OwnersController#show` is overridden to render `owners/show_with_tabs.html.erb` with one of two attribute subsets driven by `params[:tab]`: `naw` (name, birthdate, address, city, country) or `apartments` (name + the associated apartments list). `name` appears on both tabs by design.
  - `app/views/owners/_owner_tabs.html.erb` uses `tabs_tag builder: InlineForms::TurboTabsBuilder` so each tab link gets `data-turbo-frame="<row frame>"` and switching tabs is a single Turbo partial swap. Field-level inline edit, cancel and close still delegate to the stock controller flow via `super`.
  - Example app header (`example_app_views/inline_forms/_header.html.erb`) surfaces an **Owners** link in the More menu.

### Fixed

- **`InlineForms::FormElements::DropdownHelper#dropdown_update` no longer raises `NoMethodError` on top-level POSTs that omit the wrapper key.** Inline edit posts the value under `params[:_<model>][:<attr>_id]`; top-level create flows that bypass that wrapper (existing integration tests posting `{name:, title:}` directly) used to blow up on `nil[:owner_id]` as soon as the attribute list grew a `:dropdown` entry (e.g. the new `[ :owner, :dropdown ]` on `Apartment`). The helper now treats a missing wrapper as "do not touch the foreign key" and leaves the attribute alone, matching the intent of `dropdown_show` / inline edit.

### Changed

- **`README.rdoc`** documents the new `Owner` model and the `InlineForms::TurboTabsBuilder` pattern (the per-resource tab strip is the only piece of `tabs_on_rails` that benefits from the builder; the rest of inline_forms still uses `set_tab` only).
- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → `7.13.6`.

## [7.13.5] - 2026-05-19

### Changed

- **Generated app Gemfile — no more git forks for `tabs_on_rails` / `i18n-active_record`.**
  - **`tabs_on_rails`:** `gem 'tabs_on_rails', '~> 3.0'` from RubyGems (weppos 3.0.0). The acesuares fork only added unused `:remote` on tab links; inline_forms uses `set_tab` only.
  - **`i18n-active_record`:** removed. Generated apps never configured `I18n.backend`; only `extract_translations` read the `translations` SQL view. Replaced with **`InlineForms::TranslationRecord`** (`lib/inline_forms/translation_record.rb`) — read-only AR on the existing view (`thekey` column kept for MySQL).
  - **`will_paginate`:** dropped commented acesuares git line; RubyGems only.

### Added

- **`docs/git-deps-assessment.md`** — fork history and verification notes (local copy also under `stuff/`, gitignored).

### Changed (also)

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → `7.13.5`.

### Verified

- `gem build inline_forms.gemspec` → `inline_forms-7.13.5.gem`; `gem build inline_forms_installer.gemspec` → `inline_forms_installer-7.13.5.gem`.
- `inline_forms create MyApp -d sqlite --example` → `bundle exec rails test` — **83 runs, 461 assertions, 0 failures, 0 errors, 0 skips** (Ruby 4.0.4 / Rails 7.2.3.1). `Gemfile.lock`: `tabs_on_rails (3.0.0)` from rubygems.org; no `i18n-active_record` git source.

## [7.13.4] - 2026-05-19

### Fixed

- **Restore on a rich_text `create` version was asymmetric** depending on what the first save of the field happened to look like. If the field's first rich_text save was empty (e.g. opening the inline editor and saving without typing — common on top-level Apartments), the user later got a `create` (body: nil -> "") plus an `update` (body: "" -> "...") and could click Restore on the update to clear the field. If the first save already had content (more common on nested Photo descriptions), the field had only the `create` version and the 7.13.2 hide-Restore-on-create rule meant there was no Restore link at all — the user reported "I can restore the empty value on Apartments but not on the nested Photo".
  - **`app/views/inline_forms/_versions_list.html.erb`**: show the Restore link on `:rich_text` `create` rows (still hide it on `:primary` `create` rows — those would mean destroying the parent record, which is the Destroy button's job).
  - **`app/controllers/inline_forms_controller.rb#revert`**: when `reify` is nil and `@version.item` is an `ActionText::RichText`, treat the revert as "undo the creation" — destroy the rich_text row, `touch` the parent, and respond with the existing turbo-stream replacing the row + versions frames. Primary `create` reverts (only reachable via replayed URLs since the view hides the link) still no-op cleanly through the same handler.

### Added

- **`test/integration/example_app_apartment_versions_turbo_test.rb`** (installer template):
  - `revert on rich_text create destroys the rich_text record so the field becomes empty` — pins the Apartment-side fix.
  - `revert on nested Photo rich_text create destroys the rich_text record` — pins the originally reported nested-Photo case.
  - `versions list shows Restore link on rich_text create rows` — pins the view-side link surfacing.
  - `versions list hides Restore link on primary create rows but keeps it on update rows` — clarifies the asymmetry between `:primary` and `:rich_text` create rows (renames the earlier test).

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** -> `7.13.4`. Companion `validation_hints` release will follow in lockstep.

### Verified

- `gem build inline_forms.gemspec` -> `inline_forms-7.13.4.gem`; `gem build inline_forms_installer.gemspec` -> `inline_forms_installer-7.13.4.gem`.
- `inline_forms create MyApp -d sqlite --example` -> `bundle exec rails test` -- **83 runs, 0 failures, 0 errors, 0 skips** (Ruby 4.0.4 / Rails 7.2.3.1).

## [7.13.3] - 2026-05-19

### Fixed

- **Versions panel — "empty" `update` row whose Restore link did nothing.** Creating a record with a `rich_text` field (e.g. a new Photo with a `description`) produced a parent-side PaperTrail `update` version with `changeset == {}`. Cause: PaperTrail 16 tracks `:touch` by default (`on: [:create, :update, :destroy, :touch]`), and ActionText's `belongs_to :record, polymorphic: true, touch: true` calls `parent.touch` on every rich-text save. The resulting version reified to the same state, so clicking Restore was a visible no-op.
  - **`lib/generators/templates/model.erb`**: emit `has_paper_trail on: [:create, :update, :destroy]` (drop `:touch`). New `rails g inline_forms …` models no longer create these noise versions. Existing apps need to re-apply the change to their models.
  - **`lib/inline_forms_installer/installer_core.rb`** (`config/initializers/rich_text_paper_trail.rb`): mirror the opt-out on `ActionText::RichText` for symmetry against any future `touch: true` association pointing at rich-text rows.
  - **`app/views/inline_forms/_versions_list.html.erb`**: defensive view-side gate — hide the Restore link when `version.changeset` is `nil` or empty after dropping `updated_at`. Covers legacy apps that still track `:touch`, plus any other empty-update source (e.g. CarrierWave callbacks that don't change attributes). The row stays visible in the audit trail; only the dead Restore link is suppressed.

### Added

- **`test/integration/example_app_apartment_versions_turbo_test.rb`** (installer template):
  - `creating a record with a rich_text body does not append a touch-only parent update` — pins the generator-template change.
  - `versions list hides Restore link on empty-changeset update rows` — pins the view-side guard against legacy `:touch` tracking.

### Changed

- **`InlineForms::VERSION`** and **`InlineFormsInstaller::VERSION`** → `7.13.3` (installer's `INLINE_FORMS_VERSION = VERSION` writes the `gem "inline_forms", "~> X.Y.Z"` pin into generated `Gemfile`s).

### Verified

- `gem build inline_forms.gemspec` → `inline_forms-7.13.3.gem`; `gem build inline_forms_installer.gemspec` → `inline_forms_installer-7.13.3.gem`.
- `inline_forms create MyApp -d sqlite --example` → `bundle exec rails test` — **81 runs, 0 failures, 0 errors, 0 skips** (Ruby 4.0.4 / Rails 7.2.3.1).

## [7.13.2] - 2026-05-19

### Fixed

- **Versions panel — `Restore` on a `create` event no longer 500s.** `PaperTrail::Version#reify` returns `nil` for `create` events (no prior state), so the old `revert` action fell through to `@parent.save!` on `nil` and raised `NoMethodError: undefined method 'save!' for nil` — most visibly when reverting an ActionText (`rich_text`) `create` version in the description column, which was the first `create` row most apps encountered for rich text.
  - **`app/views/inline_forms/_versions_list.html.erb`**: hide the `Restore` link for `version.event == "create"` rows (covers both `:primary` and `:rich_text` entries). Reverting a `create` is semantically a destroy; primary records keep their dedicated Destroy button, and rich-text content can still be cleared by editing.
  - **`app/controllers/inline_forms_controller.rb#revert`**: defensive nil-reify guard. If the request still arrives (bookmarked / replayed URL), short-circuit to the existing turbo-stream row-close response keyed off `@version.item` (its parent for `ActionText::RichText`) instead of calling `save!` on nil.

### Added

- **`test/integration/example_app_apartment_versions_turbo_test.rb`** (installer template): two new regression tests that pin the fix above — `revert on rich_text create version no-ops via turbo-stream instead of NoMethodError` (replays the failing POST and asserts the parent body is preserved) and `versions list hides Restore link on create rows but keeps it on update rows` (asserts the view-side link gating).

### Fixed (also)

- **`test/integration/example_app_apartment_photos_pagination_test.rb`** (installer template): `refute_match(/UnknownFormat|406/, …)` is flaky because CarrierWave's seeded image URL contains a random UUID that can include the substring `406`. Tightened to `/UnknownFormat|406 Not Acceptable/`, which still catches the original `ActionController::UnknownFormat` / `406` error-page regression but no longer matches harmless hex inside the upload path.

### Changed (also)

- **`InlineFormsInstaller::VERSION`** bumped to `7.13.2` in lockstep (the installer's `INLINE_FORMS_VERSION = VERSION` constant is what `installer_core.rb` writes into generated `Gemfile`s as the `gem "inline_forms", "~> X.Y.Z"` pin).

### Verified

- `gem build inline_forms.gemspec` → `inline_forms-7.13.2.gem`; `gem build inline_forms_installer.gemspec` → `inline_forms_installer-7.13.2.gem`.
- `inline_forms create MyApp -d sqlite --example` → `bundle exec rails test` — **79 runs, 441 assertions, 0 failures, 0 errors, 0 skips** (Ruby 4.0.4 / Rails 7.2.3.1).

## [7.13.1] - 2026-05-19

### Fixed

- **Generated app Gemfile:** add **`puma`** in `:development` so plain **`rails s`** works on Rails 7.2 (rackup default handler is puma/falcon/webrick; `thin` and `unicorn` are not auto-selected).

### Verified

- **`inline_forms create MyApp -d sqlite --example`** → **`bundle exec rails s`** boots Puma → **`bundle exec rails test`** — **77 runs, 427 assertions, 0 failures**.

## [7.13.0] - 2026-05-19

### Changed

- **Track B — Zeitwerk / form elements:** ~37 form elements moved from `app/helpers/form_elements/*.rb` (top-level `def` + `Dir[]` require) to namespaced `InlineForms::FormElements::*Helper` modules under `lib/inline_forms/form_elements/*_helper.rb`.
- **`InlineForms::FormElementRegistry`:** central `SPECIAL_COLUMN_TYPES` registration (replaces per-file side effects).
- **`InlineFormsHelper` / `InlineFormsController`:** both include `InlineForms::FormElements::HelperIncludes` so views still call `text_field_show`, etc., and controllers still dispatch `*_update` (e.g. `name_list.html.erb` unchanged).
- **Loading:** form-element helpers are explicitly `require`d at boot; `lib/inline_forms/form_elements/` is ignored by Zeitwerk (avoids `_helper.rb` constant mismatches during `zeitwerk:check`).
- **`inline_forms_generator`:** requires `inline_forms` only (no full helper preload).
- **`validation_hints`:** requires `~> 7.13`.

### Verified

- **`inline_forms create MyApp -d sqlite --example`** on Ruby 4.0.4 / Rails 7.2.3.1 → **`bundle exec rails zeitwerk:check`** — clean → **`bundle exec rails test`** — **77 runs, 427 assertions, 0 failures**.

## [7.12.0] - 2026-05-19

### Changed

- **Rails 7.2:** engine gemspec and installer Gemfile pin `rails ~> 7.2.3`, `config.load_defaults 7.2`, migrations `ActiveRecord::Migration[7.2]`.
- **Ruby 4.0:** gemspecs require Ruby `>= 4.0.0`; generated apps write `.ruby-version` `ruby-4.0.4` (`InlineFormsInstaller::TARGET_RUBY_VERSION`).
- **`validation_hints`:** requires `~> 7.12` (Active Record 7.2).
- **`rails-i18n`:** `~> 7.0` in generated Gemfile (7.0.x is the published line for Rails 7.2); engine dependency `>= 7.0`, `< 8.0`.
- **`bin/inline_forms`:** prefers locally installed `rails` 7.2.x for `rails new`.
- **`.ruby-version`:** written from the app template after `rails new` (avoids Thor conflict with Rails’ own file).
- **`config.autoload_lib`:** no longer stripped from generated `application.rb` (Rails 7.2 expects it).

### Fixed

- **Example app test:** `example_app_photos_test` — standalone `GET /photos` asserts non-success (403), not `UnknownFormat`.

### Verified

- **`inline_forms create MyApp -d sqlite --example`** on Ruby 4.0.4 / Rails 7.2.3.1 → **`bundle exec rails test`** — **77 runs, 427 assertions, 0 failures**.

## [7.11.0] - 2026-05-19

### Changed

- **Split installer into `inline_forms_installer` gem.** The Rails engine (`inline_forms`) no longer ships the `inline_forms create` CLI, Thor/RVM dependencies, or `lib/installer_templates/`. Install both gems (or `gem install inline_forms_installer`, which registers the `inline_forms` executable). Capistrano/Unicorn deploy templates moved from `lib/generators/templates/` to `lib/installer_templates/`.
- **Generated app Gemfile:** `gem 'inline_forms', '~> <version>'` instead of `path:` (set `INLINE_FORMS_GEMFILE_PATH` for maintainer local-path overrides).

### Verified

- **`gem build inline_forms.gemspec && gem build inline_forms_installer.gemspec`** → install both → **`inline_forms create MyApp -d sqlite --example`** → **`bundle exec rails test`** — **77 runs, 427 assertions, 0 failures**.

## [7.10.2] - 2026-05-18

### Added

- **Example app:** `Apartment.opening_date` (`date` / jQuery UI datepicker) — demonstrates centralized `initInlineFormsWidgets` on show, inline edit, and new form.
- **Regression test:** `example_app_apartment_opening_date_test.rb`.

### Verified

- **`inline_forms create MyApp -d sqlite --example`** → **`bundle exec rails test`** — **77 runs, 427 assertions, 0 failures**.
- **Browser:** new Apartment form → `Opening date` input has `class="datepicker hasDatepicker"` (jQuery UI initialized); submit persists `15-03-2019`; show panel renders it; inline edit re-binds datepicker on the same field.

## [7.10.1] - 2026-05-18

### Fixed

- **`inline_forms create`:** installer installs `validation_hints` from `~/code/validation_hints/*.gem` when `~> 6.3` is not on RubyGems yet (before first `bundle install`).

## [7.10.0] - 2026-05-18

### Changed

- **Rails 7.1:** gemspec and `--example` installer Gemfile pin `rails ~> 7.1.5`, `config.load_defaults 7.1`, migrations `ActiveRecord::Migration[7.1]`.
- **`validation_hints`:** requires 6.3.0+ (Rails 7.1 activerecord).

### Verified

- **`bundle exec rails test`** in `--example` MyApp on Rails 7.1 — **74 runs, 412 assertions, 0 failures**.
- **curl:** `GET /apartments/new?update=apartments_list` with session + Turbo-Frame — validation hint source present.
- **Browser (headless Chromium):** login → new Apartment → hover Name — Tippy tooltip visible with **"can't be blank"**.

## [7.9.8] - 2026-05-18

### Changed

- **jQuery widget init (Phase 4):** `initInlineFormsWidgets` centralizes datepicker, month/year picker, timepicker, Trix, and validation-hint Tippy re-bind on DOM ready, `turbo:load`, and `turbo:frame-load`.
- **`date` / `time` / `month_year_picker` form elements:** removed inline `<script>` tags; fields use class hooks (`datepicker`, `datepicker-month-year`, `timepicker`).

### Added

- **`docs/jquery-widgets.md`** — migration status and remaining jQuery dependencies.

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **74 runs, 408 assertions, 0 failures**.
- **curl + browser:** validation hint tooltips on new Apartment form (7.9.8).

## [7.9.7] - 2026-05-18

### Added

- **`docs/turbo-stream-audit.md`** — documents current `format.turbo_stream` usage and optional future candidates (Phase 3 hygiene).

### Changed

- **Repo hygiene:** built `*.gem` artifacts remain gitignored; remove local copies after `gem build`.

## [7.9.6] - 2026-05-17

### Fixed

- **Validation hint tooltips runtime error:** `tippy-bundle.umd.min.js` is *not* a self-contained bundle — it expects `window.Popper` (`@popperjs/core` v2) to exist before its UMD factory runs. Without it Tippy threw `TypeError: Cannot read properties of undefined (reading 'applyStyles')` and no tooltip was ever attached, so the **Name** label looked unstyled and unpositioned even though the trigger markup and hidden `<ul>` source were correct.

### Added

- **Vendored `popper.min.js`** (`@popperjs/core` 2.11.8) under `vendor/assets/javascripts/`, precompiled by the engine and loaded by `app/views/layouts/inline_forms.html.erb` immediately before `tippy-bundle.umd.min`.

### Verified

- **Browser:** new Apartment form — hover over **Name** shows the black Tippy tooltip positioned above the label with bulleted **"Name can't be blank"**.
- **`bundle exec rails test`** in `--example` MyApp — **74 runs, 408 assertions, 0 failures**.

## [7.9.5] - 2026-05-17

### Fixed

- **Validation hint tooltip styling and position:** switched from Foundation Tooltip to **Tippy.js** (vendored bundle + Popper). Foundation lost the base `tooltip` class when using a custom `tooltipClass`; even with that fixed, positioning was wrong inside `#outer_container` (`position: absolute`). Tippy renders HTML `<ul>/<li>` hints with a black `validation-hints` theme anchored to the label. Loaded as a separate script tag (Sprockets concatenation breaks the UMD global).
- **Hidden hint source:** `[hidden].validation-hints-source` forced to `display: none`.

### Verified

- **Browser:** Konferensha show + new apartment form — black tooltip above **Name**, bulleted **"Name can't be blank"**.
- **`bundle exec rails test`** in `--example` MyApp — **74 runs, 408 assertions, 0 failures**.

## [7.9.4] - 2026-05-17

### Fixed

- **Validation hint tooltips (show + new):** hints use a hidden `<ul>` source div and scoped Foundation `Tooltip` init with `allowHtml: true` — no HTML in `title` (fixes literal `<ul><li>…` in tooltips on existing records).
- **New form parity:** `_new.html.erb` and `_new_nested.html.erb` render the same `_attribute_label` partial as `_show.html.erb`, so required fields (e.g. Apartment `name`) show hints on create.

### Added

- **`_attribute_label.html.erb`**, `validation_hints_source_id`, and `initValidationHintTooltips` (also on `turbo:frame-load`).
- **Regression tests:** `example_app_validation_hints_test.rb`.

### Changed

- **`validation_hints_as_list_for`:** uses `full_messages_for` (e.g. "Name can't be blank") inside escaped `<ul class="validation-hints-list">` items.

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **74 runs, 408 assertions, 0 failures**.

## [7.9.3] - 2026-05-17

### Fixed

- **Nested Photo versions frame id:** `inline_forms_versions_turbo_frame_id` returns `apartment_<aid>_photo_<pid>_versions` for `not_accessible_through_html?` children. `render_revert_turbo_streams` and versions partials now use it so image revert turbo-stream replaces the correct frame (fixes `ExampleAppPhotoRevertTest`).

## [7.9.2] - 2026-05-17

### Changed

- **`validation_hints` dependency** bumped to `>= 6.0`, `< 7.0`; the `--example` installer Gemfile pins `~> 6.2`.

### Fixed

- **`validation_hints` load order:** engine initializer applies `ValidationHints::ValidationsPatch` because apps `require "rails/all"` before `Bundler.require`, so the gem's `on_load(:active_model)` hook never runs.

## [7.9.1] - 2026-05-17

### Added

- **Example app — apartment name required:** the `--example` installer injects `validates :name, presence: true` on `Apartment`. Top-level create without a name re-renders the new form instead of persisting.
- **Regression tests:** `example_app_apartment_name_validation_test.rb` (model); `example_app_apartment_name_required_test.rb` (Turbo create).

### Verified

- **`bundle exec rails test`** (new validation tests) in `--example` MyApp — **3 runs, 10 assertions, 0 failures**.

## [7.9.0] - 2026-05-16

### Added

- **Restore rich_text (ActionText) versions from the versions panel:** the Restore link now renders for `:rich_text` entries too. `InlineFormsController#revert` reifies the `ActionText::RichText` row, saves it, and `touch`es the parent so any timestamp display refreshes.
- **CarrierWave history for `image_field` / `multi_image_field`:** the installer ships a `config/initializers/carrierwave.rb` with `remove_previously_stored_files_after_update = false` and patches the generated `app/uploaders/image_uploader.rb` with a no-op `remove!` plus a per-upload UUID `filename` prefix. PaperTrail reverts on an image column now restore the previous bytes (not just the previous filename). Source: <https://stackoverflow.com/questions/9423279/papertrail-and-carrierwave> (Answers 2, 4, 5).
- **Regression tests:** `example_app_photo_revert_test.rb` (image-column revert restores bytes); rich_text revert assertions in `example_app_apartment_versions_turbo_test.rb`.

### Changed

- **`render_revert_turbo_streams`:** no longer mutates `@update_span` mid-method. The row and versions frames are rendered with explicit `locals: { update_span:, object:, inline_forms_turbo_row: }`. The `row_close` / `versions_panel` templates and their `_close` / `_versions` partials prefer `local_assigns[:…]` and fall back to the matching ivar.
- **Frame ids in revert:** `row_id` and `versions_id` now derive from `@parent` (the rich_text branch sets `@parent = @rich_text_record.record`), so revert works identically for primary and rich_text versions.

### Removed

- **`format.html` fallback in `revert`:** the action only responds with `turbo_stream` now. The "Turbo POST on row frame" regression test was updated to send `Accept: text/vnd.turbo-stream.html`.

### Trade-offs

- The `ImageUploader` no longer deletes previous files on update or destroy. Files accumulate; sweep tooling is out of scope (would have to reconcile with `PaperTrail::Version#object` snapshots across the whole table).

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **68 runs, 358 assertions, 0 failures, 0 errors, 0 skips**.

## [7.8.1] - 2026-05-16

### Fixed

- **Restore from versions panel (Turbo 2 + Drive):** POSTs from inside `<turbo-frame id="…_versions">` sent `Turbo-Frame: …_versions` while the server returned only the **row** frame, so Turbo showed **Content missing**. Restore links now request **`turbo_stream`**; **`revert`** responds with **`turbo_stream.replace`** for both the row and the versions panel.

### Added

- **Regression tests:** versions list restore link carries `data-turbo-stream`; revert with versions-frame header returns stream (`example_app_apartment_versions_turbo_test.rb`).

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **67 runs, 342 assertions, 0 failures**.

## [7.8.0] - 2026-05-16

### Changed

- **Step 5 (UJS → Turbo):** **Turbo Drive** left at the default (**enabled**); removed **`Turbo.session.drive = false`** from **`inline_forms`** and **`application`** layouts.
- **`app/assets/javascripts/inline_forms/inline_forms.js`:** dropped **`jquery_ujs`** and **`jquery.remotipart`**; inline navigation uses Turbo only.
- **Installer Gemfile** (`bin/inline_forms_installer_core.rb`): removed **`remotipart`**; updated **`turbo-rails`** comment.
- **Helpers / partials:** removed **`remote: true`** fallbacks (`close_link`, toolbar, new/versions links, field cancel, `link_to_inline_edit` legacy branch, **`_close`**, **`_new`**); all use **`data-turbo`** + frame targets.

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **65 runs, 330 assertions, 0 failures**.

## [7.7.3] - 2026-05-16

### Changed

- **Step 4 (UJS → Turbo) — versions panel:** `VersionsConcern#list_versions` is **HTML-only** (`versions_panel` / `versions_list_panel` inside matching `<turbo-frame>`). Removed **`versions.js.erb`** and **`versions_list.js.erb`**.

### Fixed

- **Nested Photo (and other `not_accessible_through_html?` children) versions restore:** `_versions_list` revert links targeted `photo_<id>` but nested list rows use `apartment_<aid>_photo_<id>`. Turbo could not find that frame, fell back to `photo_<id>_versions`, and `revert` returned **406** (`row_html_turbo_allowed?` false for bare `photo_<id>`). **`inline_forms_row_turbo_frame_id`** now matches `_list.html.erb` row ids.

### Added

- **Regression tests:** expanded-row versions open link (Turbo, not `data-remote`); revert from versions list via Turbo POST (`example_app_apartment_versions_turbo_test.rb`); nested Photo versions list restore + Turbo POST revert (`example_app_apartment_photos_pagination_test.rb`).

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **65 runs, 330 assertions, 0 failures**.

## [7.7.0] - 2026-05-16

### Changed

- **Step 4 (UJS → Turbo) — top-level list + create:** `/apartments` index list root is **`<turbo-frame id="apartments_list">`** with in-frame pagination (`update=apartments_list`); **`+ new` / cancel / create** use Turbo HTML (`new_record` / `create_list_frame`) instead of **`new.js.erb`** / **`list.js.erb`**. **`#outer_container > turbo-frame.list_container { width: 100% }`** fixes the 7.5.2 layout collapse.
- **`:tree` / `:move` archived:** hierarchical child list (**`_tree.html.erb`**) and reparent helper (**`move.rb`**) moved to **`archived/form_elements/tree/`** — they expect host-app tree APIs (`#children`, `#hash_tree_to_collection`, `#add_child`), not defined in the gem; no example-app model. Registry blocks `:tree` / `:move` in `inline_forms_attribute_list`.
- **Removed row/list UJS templates:** **`show.js.erb`**, **`close.js.erb`**, **`record_destroyed.js.erb`**, **`show_undo.js.erb`**, **`new.js.erb`**, **`list.js.erb`**; row actions and list flows use **`format.html`** only.

### Added

- **Regression tests:** `example_app_apartment_top_level_new_test.rb` (Turbo new/cancel/create), `example_app_apartment_top_level_pagination_test.rb`.

### Verified

- **`bundle exec rails test`** in `--example` MyApp — **62 runs, 312 assertions, 0 failures**.

## [7.6.0] - 2026-05-16

### Changed

- **Project-specific form elements archived (not loaded by default):** `:geo_code_curacao` (helper + model + controller + views), **`chicas_*`** (`:chicas_photo_list`, `:chicas_family_photo_list`, `:chicas_dropdown_with_family_members`), and **`:kansen_slider`**. Sources live under **`archived/form_elements/`** with per-folder README restore steps.
- **Registry:** **`InlineForms::ARCHIVED_FORM_ELEMENTS`**; boot raises **`ArchivedFormElementError`** if a model still declares an archived symbol (including **`:absence_list`**, removed in 6.3.0 without source in tree).
- **Versioned archive:** **`archived/README.md`** catalogs all retired features.
- **`_edit.html.erb`:** removed **`kansen_slider`** from `@BUTTONS_UNDER` (element archived).

### Upgrade notes

- **Breaking:** Remove or vendor archived symbols from `inline_forms_attribute_list`: **`:geo_code_curacao`**, **`:chicas_*`**, **`:kansen_slider`**. Copy from the matching **`archived/form_elements/<name>/`** README (geo also needs host route `get "geo_code_curacao", to: "geo_code_curacao#list_streets"`).

## [7.5.2] - 2026-05-16

### Fixed

- **Field re-edit after Turbo update / cancel (Photo image, name, etc.):** `render_turbo_field` now sets **`@inline_forms_turbo_field = true`**, so the link inside the swapped **`<turbo-frame id="photo_<id>_image">`** carries **`data-turbo`** instead of legacy **`data-remote`**. 7.5.1 set the flag only in `_show.html.erb` (the row open template); the bare `field_show` re-render after a field cancel/update lost it, the link fell back to **`remote: true`**, jquery_ujs intercepted as a JS request the controller does not register, and the second click silently failed (no swap, no edit form).
- **Top-level `+ new` flow (e.g. /apartments):** `link_to_new_record` falls back to **UJS (`remote: true`)** when called without a `parent_class`. The top-level list root stays a **`<div id="apartments_list">`** (a `<turbo-frame>` there collapses inside `position: absolute` `#outer_container` and hides rows under the fixed top bar), so a Turbo target on the **`+`** link is invalid -- 7.5.1 emitted `data-turbo-frame="apartments_list"`, which made cancel/create produce Turbo's "Content missing" or fall back to a full-page navigation. UJS (`new.js.erb` / `list.js.erb`) swap **`#apartments_list`** in place; nested has_many lists keep the Turbo contract unchanged.

### Added

- **Defensive CSS:** `turbo-frame { display: block; }` so any `<turbo-frame>` inside `#outer_container` (custom elements default to `display: inline`) does not collapse and hide its row content.
- **Regression tests:**
  - `example_app_apartment_top_level_new_test.rb` -- top-level list root stays `<div>`, **`+`** link is UJS, `new` / `cancel` / `create` go through `format.js` and swap **`#apartments_list`**.
  - `example_app_apartment_photos_pagination_test.rb` -- after Turbo update / cancel of a Photo image field, `field_show` carries `data-turbo="true"` (not `data-remote="true"`).

### Verified

- **`bundle exec rails test`** -- **60 runs, 302 assertions, 0 failures**.
- **curl:** field show after cancel/update emits `data-turbo="true" data-turbo-frame="_self"` (no `data-remote`); top-level new returns `format.js` swap of `#apartments_list`.
- **Browser:** top-level `+ new Apartment` form renders inline + cancel returns to list (no "Content missing"); nested Photo image edit can be reopened immediately after cancel and after replacement.

## [7.5.1] - 2026-05-16

### Fixed

- **Nested associated `+` (New) on `not_accessible_through_html?` models (Photo):** `new` now serves **`format.html`** when `parent_class` and `update` are present (was **406** / empty frame for Photo).
- **New / Cancel / OK after New:** associated-list frame responses use the **`inline_forms`** layout (styled) instead of bare **`turbo_rails/frame`**; **`create`** restores the list with **`@ul_needed = true`** so the inner **`…_photos_list`** `<turbo-frame>` matches **`_show`** (fixes Turbo **“Content missing”** on cancel and create).
- **`_new.html.erb`:** Turbo form sets **`data-turbo-frame`** to the parent list frame id.

### Verified

- **`bundle exec rails test`** — **53 runs, 260 assertions, 0 failures**; nested Photo new → cancel → create integration test.
- **curl:** new **200** + stylesheet; cancel/create **200** with **`apartment_<id>_photos`** + **`…_photos_list`** frames.

## [7.5.0] - 2026-05-16

### Added

- **Step 3 completion (UJS → Turbo row/field lifecycle):** row toolbar **`soft_delete` / `soft_restore` / `destroy` / `revert`** respond with **`format.html`** (`row_close`, `row_destroyed`) inside matching **`<turbo-frame>`**; helpers default to Turbo (`inline_forms_turbo_link_data`, `turbo_row:` on toolbar / versions / nested **`+`** links).
- **Nested `+new` / `create` / versions panel:** `new_record`, `create_list_frame`, `versions_panel`, `versions_list_panel` HTML templates; associated/has_one/versions regions in **`_show`** wrapped in **`<turbo-frame>`**.
- **`turbo:frame-load`** in **`inline_forms.js`:** re-init datepicker, timepicker, and Trix after frame swaps.
- **Regression tests:** row destroy/revert Turbo, versions panel Turbo (`example_app_apartment_row_turbo_test.rb`, `example_app_apartment_versions_turbo_test.rb`).

### Removed

- **`edit.js.erb`**, **`update.js.erb`**, **`show_element.js.erb`** — scalar field edit/update/cancel is Turbo HTML only.

### Changed

- **`docs/ujs-to-turbo.md`:** Step 3 checklist marked done except **`show.js.erb` / `close.js.erb` / …** retained for **`_tree.html.erb`** (Step 4).

### Verified (end-to-end against the `--example` install)

- **`bundle exec rails test`** — **52 runs, 236 assertions, 0 failures, 0 errors, 0 skips** against the generated MyApp.
- **curl smoke:** versions panel **`GET /apartments/1/list_versions?update=apartment_1_versions`** with **`Turbo-Frame`** → **200** + matching **`<turbo-frame id="apartment_1_versions">`**.
- **curl + browser** — row toolbar, versions, field edit, nested photos (same contract as 7.4.x).

## [7.4.5] - 2026-05-15

### Added

- **Example app integration test** (`example_app_apartment_photos_pagination_test.rb`): nested Photo **`image`** field — Turbo **`Turbo-Frame`** GET edit (multipart form) and **multipart `PUT`** — asserts **200** HTML with matching **`<turbo-frame id="…_image">`** and no **`UnknownFormat`** / **406** (Step 3 multipart regression guard from the 7.2.0 nested-frame era).

### Changed

- **`docs/ujs-to-turbo.md`:** Step 3 checklist — “replace photo image (multipart) inside nested frame” marked done.

### Verified (end-to-end against the `--example` install)

- **`bundle exec rails test`** — **47 runs, 208 assertions, 0 failures, 0 errors, 0 skips** against the generated MyApp (Apartment + Photo).
- **curl smoke** (authenticated **`Turbo-Frame`** GETs / **`POST` multipart** with **`_method=put`**): same contract as 7.4.4 plus nested Photo **`/photos/1/edit?attribute=image&form_element=image_field&update=apartment_1_photo_<id>_image`** and image replace **`POST /photos/1?...`** — **200** and matching **`<turbo-frame id="…_image">`** (Devise scope **`/auth/users/sign_in`**; cookie jar must be sent on the multipart step).
- **Browser** (cursor-ide-browser MCP, dev server): already-signed-in session — open **Konferensha** row (URL stays **`/`**, gallery appears) — **Next page** (gallery shows page-2 filenames) — **`/apartments/name_list`** — edit name — **ok** (read-only link shows new value).

## [7.4.4] - 2026-05-16

### Fixed

- **`inline_forms create … --example` against a Rails 8 system gem:** `bin/inline_forms` now prefers a locally installed Rails **`~> 7.0`** (`rails _7.0.X_ new …`) when one is present, so the generated **`config/application.rb`** matches the **`rails ~> 7.0.0`** pin the installer writes into the **`Gemfile`**. Without this, a system **`rails 8.x`** wrote **`config.load_defaults 8.0`** and **`config.autoload_lib(ignore: …)`** into `application.rb`, both rejected by Rails 7.0 (`rails aborted! Unknown version "8.0"` and `NoMethodError: undefined method 'autoload_lib'` on the first **`bundle exec rails dartsass:install`**), so app generation aborted right after Dart Sass install.
- **Defensive `application.rb` rewrite (belt + suspenders):** even when the picked generator is Rails 8.x (e.g. no 7.0 gem available), `bin/inline_forms_installer_core.rb` rewrites **`config.load_defaults <N>.<M>`** to **`config.load_defaults 7.0`** and strips **`config.autoload_lib(…)`** post-generation so the bundled Rails 7.0 can boot.

### Changed

- **`docs/ujs-to-turbo.md`:** Step 3 marks the apartment field flow integration test (**`example_app_apartment_field_turbo_test.rb`** — open row → edit text field → save → cancel) as done; the test has been shipping since 7.4.1.

### Verified (end-to-end against the `--example` install)

- **`bundle exec rails test`** — **46 runs, 196 assertions, 0 failures, 0 errors, 0 skips** against the generated MyApp (Apartment + Photo).
- **curl smoke** with **`Turbo-Frame`** header: top-level row open/close (**`/apartments/1?update=apartment_1[&close=true]`**), scalar field edit/update/cancel (**`/apartments/1/edit?attribute=name&form_element=text_field&update=apartment_1_name`** + **`PUT /apartments/1`**), nested **`/photos?parent_class=Apartment&parent_id=1&update=apartment_1_photos_list`** pagination, and nested Photo row open/close (**`/photos/1?update=apartment_1_photo_1[&close=true]`**) all return **200** with the matching **`<turbo-frame id="…">`** in the body.
- **Browser** (devtools MCP, Drive disabled, UJS for the legacy paths): sign-in → click apartment row (Turbo open, no full-page nav) → nested photo pagination Next (Turbo) → click name field (Turbo edit-in-place) → save (in-place swap, no reload) → close X (Turbo collapse, list shows updated name). **`/apartments/name_list`** field-edit demo confirmed reachable from the **More** menu.

## [7.4.3] - 2026-05-16

### Added

- **Turbo row open/close on stock index:** each top-level list row is a **`<turbo-frame id="{model}_{id}">`**; presentation links use Turbo (**`row_show.html.erb`** / **`row_close.html.erb`**, **`close_link(..., turbo_row:)`**, **`example_app_apartment_row_turbo_test.rb`**).

### Fixed

- **Nested associated list (e.g. Apartment → Photo):** same per-row **`<turbo-frame>`** + Turbo presentation as top-level; removed **`data-turbo="false"`**, which broke nested **cancel** and other in-frame GETs. **`row_html_turbo_allowed?`** / **`nested_associated_list_row_update?`** serve **`format.html`** row **show** / **close** for **`not_accessible_through_html?`** models when **`params[:update]`** is a nested row id (e.g. **`apartment_1_photo_5`**).

### Changed

- **`docs/ujs-to-turbo.md`:** Step 2 / Step 3 checklist for row + nested Turbo.
- **`example_app_apartment_photos_pagination_test.rb`:** asserts nested turbo-frame rows and Photo row open/close + field cancel; drops the obsolete requirement that nested rows opt out of Turbo.

## [7.4.1] - 2026-05-15

### Added

- **Turbo field edit (Step 3, partial):** scalar fields in stock **`_show.html.erb`** are wrapped in **`<turbo-frame id="{model}_{id}_{attribute}">`**. Field **edit**, **update**, and **cancel** respond with **`format.html`** via **`field_edit.html.erb`** / **`field_show.html.erb`** and the **`turbo_rails/frame`** layout (no UJS on field links/forms). Row-level show/close remains UJS.
- **`inline_forms_field_cancel_link`** helper and **`inline_forms_field_show`** helper; **`link_to_inline_edit`** accepts **`turbo_frame:`** and omits **`remote: true`** on the Turbo path.
- **Regression tests** **`example_app_apartment_field_turbo_test.rb`** (stock panel field turbo-frame edit/update/cancel) and extended **`example_app_apartment_name_list_test.rb`** (turbo-frame contract, no **`UnknownFormat`** on cancel).

### Fixed

- **Field cancel on Turbo path:** cancel no longer triggers full-page navigation or **`UnknownFormat`** — **`format.html`** is always registered for single-attribute show; cancel uses a plain GET link with **`data-turbo-frame="_self"`** (no **`data-method`**, which conflicted with jQuery UJS).
- **Cancel button height:** restored **`input[type=button]`** inside a thin wrapper link (Turbo/UJS attrs on the **`<a>`**) so cancel matches the **ok** submit height; Foundation **`a.button`** was rendering much taller in collapse rows.

### Changed

- **Example name list (`--example`):** uses the same turbo-field contract as stock **`_show`** ( **`@inline_forms_turbo_field`**, **`<turbo-frame>`** wrappers), not a separate UJS path.
- **`docs/ujs-to-turbo.md`:** Step 3 field-level checklist items marked done for stock scalar fields and name-list regression.

## [7.4.0] - 2026-05-15

### Added

- **`--example` demo: field-level inline edit without the stock `_show` UI** (`ApartmentsController#name_list`, **`GET /apartments/name_list`**). Lists the first 10 apartments with each **`name`** rendered via **`text_field_show`** inside a wrapper `id="apartment_<id>_name"`, so edit/update use the normal polymorphic paths without opening the full inline-edit panel. Installer copies **`app/views/apartments/name_list.html.erb`**, injects the controller action (with CanCan **`skip_load_and_authorize_resource`** / **`authorize! :read, Apartment`**), and adds the route.
- **More menu link** in the example app only: installer overrides **`app/views/inline_forms/_header.html.erb`** with an extra item **“Apartment names (first 10)”** pointing at **`apartment_name_list_path`**.
- **UJS → Turbo migration checklist** at **`docs/ujs-to-turbo.md`** (Steps 1–2 done, 3–5 tracked).
- **Regression test** **`test/integration/example_app_apartment_name_list_test.rb`**: page render, More menu link, and UJS edit-link **`update=`** contract.

## [7.3.4] - 2026-05-15

### Changed

- **Installer Gemfile**: `devise-i18n` is taken from RubyGems (`~> 1.16`, current release **1.16.0**) instead of the obsolete `https://github.com/acesuares/devise-i18n.git` fork (which matched upstream only through 2018). `devise` is pinned to **`~> 5.0`** so it satisfies `devise-i18n` 1.16’s runtime dependency on Devise 5+.

## [7.3.3] - 2026-05-07

### Fixed

- **Session flash no longer appears inside inline-edit fields**: `_edit.html.erb` was injected into the field span via UJS and iterated the full `flash` hash, so an unconsumed Devise notice (for example after sign-in) could show up inside the Trix/rich-text editor when opening a field. The edit partial no longer renders global flash; `_new.html.erb` only shows `flash.now` keys used by `create` (`header`, `error`, `success`). **`layouts/inline_forms.html.erb`** now renders **`flash["notice"]` / `flash["alert"]`** under the header so redirect flash is shown once and consumed on normal pages.
- **`InlineFormsApplicationController` default layout**: `layout 'devise' if :devise_controller?` was ineffective because `:devise_controller?` is a Symbol (always truthy), so every controller defaulted to `layouts/devise`. Replaced with `layout ->(c) { c.devise_controller? ? "devise" : "inline_forms" }` so app controllers use the full **`inline_forms`** chrome unless an action overrides `render` layout.
- **Devise sign-in form** (`app/views/devise/sessions/_form.html.erb`): added `data-turbo="false"` on the form so a Turbo-enabled asset bundle cannot turn the POST into a non-navigational request (which would skip Devise’s `set_flash_message!` for `:signed_in`).

## [7.3.2] - 2026-05-07

### Fixed

- **Legacy `:text_area` alias no longer triggers plain-text column checks**: `:text_area` is treated as the rich-text alias path, while plain-text column enforcement remains limited to `:plain_text`, `:plain_text_area`, and `:text_area_without_ckeditor`. This prevents false `InlineForms::PlainTextColumnMissingError` when switching an ActionText-backed attribute from `:rich_text` to `:text_area`.

## [7.3.1] - 2026-05-07

### Changed

- **Long text form element naming is now explicit**: `:plain_text` is the canonical non-WYSIWYG textarea form element (backed by a DB `text` column), while `:rich_text` remains the ActionText/Trix element.
- **Default mapping for migration type `:text` now emits form element `:plain_text`** (instead of `:text_area`) so newly generated models use the explicit name.
- **Legacy aliases remain supported**: `:text_area_without_ckeditor` and `:plain_text_area` delegate to `:plain_text`; legacy `:text_area` and `:ckeditor` delegate to `:rich_text`.

### Fixed

- **Misconfigured `plain_text` attributes now fail fast with a clear error**: inline_forms now raises `InlineForms::PlainTextColumnMissingError` when a `plain_text`-style form element targets an attribute without a DB column (for example, an ActionText-only attribute such as `description` after switching from `:rich_text` to `:text_area`/`:plain_text` without adding a column).
- **Checks run both during app boot/reload (for loaded models) and at request runtime** (`getKlass`, `create`, `update`) to prevent late `ActiveModel::MissingAttributeError` failures.
- **Generated example-app tests now cover rich_text/plain_text edge cases**, including the failure path above and the reverse direction (`plain_text` -> `rich_text`) staying non-failing from inline_forms' perspective.

## [7.3.0] - 2026-05-07

### Removed

- **CKEditor**: no CDN script tags in engine layouts, no `cktext_area_tag` / `CKEDITOR` usage, no `.ckeditor_area` styles, and no `inline_forms/ckeditor/config.js` asset precompile entry. Long text uses the same plain `<textarea>` path as before when the CKEditor gem was absent.

### Changed

- **`:text_area`** always renders a plain multiline field (equivalent to the old non-CKEditor path and to **`:text_area_without_ckeditor`**).
- **`:ckeditor`** remains a valid generator/model type name but now delegates to **`:text_area`** behavior (plain text); migrate to **`:text_area`** or **`:rich_text`** when convenient.

## [7.2.11] - 2026-05-07

### Changed

- **Release status notice added to user-facing docs and gem metadata**: `README.rdoc` now includes a top-level notice that versions after `6.2.14` are currently broken and that a follow-up notice will be posted when the gem is good again. `inline_forms.gemspec` now mirrors this status in both `summary` and `description` so the same warning is visible on RubyGems.

### Fixed

- **Generated apps now always source `inline_forms` from the exact generator path** (`gem 'inline_forms', path: generator_repo`) so local unreleased builds are used consistently during `inline_forms create`. To support that safely outside git checkouts, `inline_forms.gemspec` now falls back to globbed file lists when `.git` is absent (instead of shelling out to `git ls-files` unconditionally), while keeping the warning cleanup (`required_ruby_version`, bounded runtime deps, deprecated `rubyforge_project` removal, and executables limited to `inline_forms`).
- **Dart Sass jQuery UI imports are now deterministic**: vendored jQuery UI SCSS import chains now target explicit `*.css.scss` files (`jquery.ui.all.css.scss` -> `jquery.ui.base.css.scss`/`jquery.ui.theme.css.scss`, plus explicit component/theme-base imports), and `inline_forms.scss` imports the vendored bundle directly. This fixes the case where `dartsass:build` exited 0 but wrote an error CSS payload (`Can't find stylesheet to import`) into `app/assets/builds/inline_forms/inline_forms.css`, leaving logged-in pages effectively unstyled.

## [7.2.10] - 2026-05-06

### Changed

- **Generated apps: Dart Sass instead of sass-rails (sassc)**. The installer Gemfile (`bin/inline_forms_installer_core.rb`) replaces **`sass-rails`** with **`dartsass-rails`**, runs **`rails dartsass:install`**, drops the default **`app/assets/stylesheets/application.css`** (Sprockets must not compile `.scss`), copies **`config/initializers/inline_forms_dartsass_builds.rb`** plus Dart Sass entry files under **`app/assets/stylesheets/inline_forms_install/`**, and appends **`test/test_helper.rb`** with **`Rake::Task["dartsass:build"].invoke`** so CI/tests materialize **`app/assets/builds/*.css`** before integration tests. The initializer documents the prior visually tuned stack (**`foundation-rails` ~> 6.6.2** + sassc) beside the new pin (**`foundation-rails` ~> 6.9** + Dart Sass) for regression comparison.
- **`foundation-rails` ~> 6.9** (e.g. 6.9.0.x on RubyGems): Foundation 6.7+ relies on Dart Sass `sass:math`; that path is incompatible with sassc, which motivated the dartsass migration.
- **jQuery UI**: SCSS and PNGs from the former **`jquery-ui-sass-rails`** stack are **vendored** under **`app/assets/stylesheets/jquery_ui/`** and **`app/assets/images/jquery-ui/`**, with every `url(image-path("jquery-ui/…"))` rewritten to **`url("jquery-ui/…")`** so Dart Sass can compile without Ruby asset helpers. **`gem 'jquery-ui-rails', '4.0.3'`** is added for the same JavaScript pin that **`jquery-ui-sass-rails`** used (`//= require jquery.ui.all` in **`inline_forms.js`**). **`jquery-ui-sass-rails`** is removed from the generated Gemfile.
- **Foundation Icons**: **`foundation-icons-sass-rails`** is removed (it hard-depends on **`sass-rails`**). Icons are vendored as **`app/assets/stylesheets/inline_forms/_foundation_icons.scss`** (plain **`url()`** in `@font-face`) plus fonts under **`app/assets/fonts/`** (woff/ttf from cdnjs **foundicons 3.0.0**, svg from the original gem). **`inline_forms.scss`** (and the generator mirror) now **`@import 'inline_forms/foundation_icons'`** instead of **`foundation-icons`**.
- **Dart Sass entrypoints** (`lib/installer_templates/dartsass/*.scss`): use **`@use "inline_forms/…" as *`** instead of **`@import`** to avoid top-level Dart Sass deprecation noise on those two files only (Foundation and vendored jQuery UI still use `@import` internally until a wider migration).

### Fixed

- **`bin/inline_forms_app_template.rb`**: RVM **`chdir`** no longer uses **`../#{app_name}`** (Rails exposes **`app_name`** underscored, e.g. **`my_app`**, while the directory may be **`MyApp`**), which broke on case-sensitive filesystems. The block now **`chdir`s the current app root** (`File.expand_path(".")`).
- **Dart Sass could not resolve `themes/jquery.ui.sunny`**: **`dartsass-rails`** builds **`--load-path`** only from **`Rails.application.config.assets.paths`**, not from **`config.dartsass.extra_load_paths`**. **`lib/inline_forms.rb`** now appends the engine’s **`app/assets/stylesheets/jquery_ui`** directory to **`config.assets.paths`** when that directory exists.
- **Devise layout / Sprockets**: after **`dartsass:install`**, **`manifest.js`** no longer includes **`link_directory ../stylesheets .css`**, so the host app’s plain **`inline_forms_devise.css`** was not linked. The installer appends **`//= link inline_forms_devise.css`** (logical path, not a path relative to **`config/`**).

## [7.2.8] - 2026-05-06

### Fixed

- **Versions list (`Versions (N)` panel opened via the inline-edit "show versions" link) rendered every cell on its own line under Foundation 6** instead of as a horizontal table-like row of `restore | event | timestamp | whodunnit | changeset`. Repro: open an Apartment, click the versions link in the inline edit -- the header row showed `Event` / `Done by` / `Changeset` stacked vertically, and each entry showed `restore` / `create` / `2026-05-06` / `16:19:57 UTC` / `Unknown` stacked vertically with the changeset table dangling below. Root cause is a markup pattern in **`app/views/inline_forms/_versions_list.html.erb`** that only worked under Foundation 5's float grid: the partial wrapped each entry in `<div class='small-12 column'>` and put the per-cell `<div class='small-N column'>` divs as direct children of that wrapper. F5's float-based `.column` was always `float: left`, so even nested-without-a-`.row` columns laid out side-by-side; F6's flex grid only makes the immediate children of `.row` flex items, so `.small-N column` divs that sit inside another `.column` (no intervening `.row`) collapse to plain block divs and stack vertically. **`_versions_list.html.erb` now drops the `small-12 column` wrapper and emits each entry as its own `<div class="row odd|even">` whose direct children are the `small-1` / `small-1` / `small-2` / `small-2` / `small-6` cell columns** (header row likewise restructured). With cells now sitting directly under a `.row`, F6's flex grid lays them out horizontally and the partial recovers F5's visual layout.
- **Top-bar dropdown indicator triangles (`More ▾` / `Admin ▾`) had < 3 pixels between the link text and the triangle**. F6 ships `.is-dropdown-submenu-parent > a { padding-right: 1.5rem }` to reserve clearance for the absolutely-positioned `::after` triangle (at `right: 5px`), but the 7.2.5 model-/app-bar shim added `.menu > li > a { padding: 0 1rem }` to compress the bar height. That override has higher specificity than F6's dropdown-parent rule (id + 4 classes/elements vs. F6's 2 classes + 1 element), so it clamped padding-right back to `1rem` for *all* menu links including the dropdown parents -- leaving the triangle visually crowding the text. **`#inline_forms_application_top_bar.top-bar` now adds a more-specific `.menu > li.is-dropdown-submenu-parent > a { padding-right: 1.5rem }`** so the dropdown-parent links recover F6's intended right-padding while the rest of the menu links keep the compact `1rem`. Result: clear gap (>= 3px) between `More` / `Admin` and their `▾` triangles.
- **Search-bar `[x]` reset link, `zoek op naam...` text input, and `[zoek]` submit button sat at the top of the gold model top-bar's 45px content band** (around y=44..46 of the 45..90px viewport band) instead of being vertically centered like `Apartments` (line-height: 45px) and the `+` new-record button. F6's `.menu` is `display: flex` with default `align-items: stretch`, so each `<li>` (and the search-form `<li>` in particular) fills the band's full 45px height; the form's `.row.collapse` then anchors its column children at the top, and a legacy stack of `.top-bar input { top: 4px !important }` / `#inline_forms_model_top_bar .inline_forms_model_top_bar_buttons { top: 6px !important }` / `#input_search { margin-top: -2px }` shims approximated centering for F5's float bar but no longer match the F6 flex bar's geometry. **`#inline_forms_model_top_bar.top-bar` now sets `align-items: center` on `.top-bar-right > .menu`** (so each `<li>` is sized to its content and centered in the 45px band) **and on `.top-bar-right > .menu > li > .row` and `.top-bar-right > .menu > li form > .row`** (so the `.row.collapse` inside the search form centers its column children too). The legacy `top: 4px / 6px / margin-top: -2px` shims are now reset to `top: 0` / `margin: 0` so they stop fighting the flex alignment, and the catch-all `.top-bar input, .top-bar .button { top: 4px !important }` rule is also defused. Net effect: `[x]` / `[zoek op naam...]` / `[zoek]` now share the same vertical center as `Apartments` and the `+` button, all without per-element pixel shims.

## [7.2.7] - 2026-05-06

### Removed

- **`switch_user` gem and the user-switcher dropdown it added to the application top bar**. The dropdown was rendered conditionally in `app/views/inline_forms/_header.html.erb` (`<li class="menu-text"><%= switch_user_select %></li>` inside `if current_user.role?(:superadmin) && Rails.env.development?`); it pulled in `switch_user` (https://github.com/flyerhzm/switch_user) which mounts an admin-only "switch user" `<select>` for impersonating other accounts during local development. **`bin/inline_forms_installer_core.rb` no longer adds `gem 'switch_user'` to the generated Gemfile**, the `<%= switch_user_select %>` `<li>` is removed from `_header.html.erb`, and the dead `#switch_user_identifier { ... }` rule is dropped from both `app/assets/stylesheets/inline_forms/inline_forms.scss` and `lib/generators/assets/stylesheets/inline_forms.scss`. The application top bar's right-hand dropdowns (More / current user / Logout) are unchanged.

## [7.2.6] - 2026-05-06

### Fixed

- **Inline-edit panel collapsed to ~340px wide on Foundation 6**: clicking a top-level row (e.g. `Konferensha` in Apartments) used to swap `_show.html.erb` into the row via `show.js.erb`'s `$('#<row_id>').html(<rendered _show>)`. The swapped HTML's outermost wrapper is `<div class="row">` (the `_show` partial's root), which under F6 becomes a flex item inside the row that already lives at `<div class="row top-level …" id="apartment_<id>">`. F5's float-based `.row` was a block element and filled its parent's width by default; F6's flex `.row` makes a nested `.row` a flex item that, with no explicit `flex-basis` and no sizing class, shrinks to its content's intrinsic width — and its child `.small-11.column` resolves `flex: 0 0 91.66%` against that shrunken parent. Net effect: the gold inline-edit panel right-aligned but indented from the left only ~340px in, instead of spanning the full row width like the F5 build did. **`app/assets/stylesheets/inline_forms/inline_forms.scss` and the mirrored `lib/generators/assets/stylesheets/inline_forms.scss`** now add `.row .row { flex: 1 1 100%; width: 100%; max-width: 100%; }` so any nested `.row` (which `_show` and several `_list` branches emit as their outermost wrapper after a UJS swap) takes 100% of its parent flex container's width, restoring the F5 visual contract.
- **`Apartments` (and any model name) rendered in F6's default link blue inside the gold model top bar** (`#inline_forms_model_top_bar`). The bar's markup is `<li class="menu-text"><h1><a><%= t(controller_name) %></a></h1></li>` (`lib/generators/templates/_inline_forms_tabs.html.erb`); the SCSS only set `background-color` on the surrounding bar / menu wrappers, so the inner `<a>` inherited Foundation 6's `a { color: #1779ba; }` from `_base.scss`. **The model top bar's `#inline_forms_model_top_bar.top-bar` block now sets `color: #FFFFFF` on `.menu-text`, `.menu-text h1`, and `.menu-text h1 a`** so the model name reads white against the gold background, matching the F5 chrome.
- **Dropdown indicator triangle next to `More ▾` / `Admin ▾` in the dark-red app top bar (`#inline_forms_application_top_bar`) was painted in F6's `$primary-color` (default `#1779ba` blue)**. F6's `_dropdown-menu.scss` paints the `::after` triangle on every `.is-dropdown-submenu-parent > a` with `border-color: $primary-color transparent transparent transparent`, regardless of the parent text color. **Override added in the app top bar block: `.is-dropdown-submenu-parent > a::after { border-top-color: #FFFFFF; border-color: #FFFFFF transparent transparent; }`** so the triangle reads white like the link label.
- **Search-bar `[x]` reset link and `[zoek]` submit button were ~30px tall while the `zoek op naam...` text input next to them was F6's default 2.4375rem (~39px) tall**, so the three controls in the same `<form>` row didn't line up. F6's `.button` heights derive from padding+line-height, F6's `input[type=text]` heights derive from `$input-height` — the legacy F5 rule (`.inline_forms_model_top_bar_buttons { padding: 7px 0 7px 0 }`) only constrained the buttons. **`#inline_forms_model_top_bar.top-bar` now pins `.inline_forms_model_top_bar_buttons` and `#input_search` to a shared 32px box (`height: 32px; line-height: 32px; padding: 0 0.5rem`)** so both buttons and the input visually align across the search row.
- **Pagination links rendered vertically (one per line: `← Previous`, `1`, `2`, `3`, `Next →` each on its own row) instead of horizontally as in F5**. Foundation 6's `_pagination.scss` (line 120) emits `.pagination a, .pagination button { display: block }` because its canonical markup is `<ul class="pagination"><li><a>...</a></li>...</ul>` — the `<li>` is `inline-block` so successive items sit side-by-side, and the inner `<a>` is `block` to fill the `<li>`. **will_paginate** (used by `_list.html.erb` line 137-142 for nested has_many lists) emits FLAT `<a>` / `<span>` / `<em>` directly under `<div class="pagination">` with NO `<li>` wrapper, so F6's `display: block` rule applies straight to every page link and they stack vertically. F5's pagination CSS shipped with no equivalent block-display rule, so the same will_paginate output rendered inline. **`.pagination` block in both stylesheets now adds `a, span, em, button { display: inline-block }`** to override F6's default for the will_paginate (no-`<li>`) case while leaving any future `<ul><li>`-wrapped pagination unaffected.

## [7.2.5] - 2026-05-06

### Fixed

- **Logged-in chrome regressed visually after the Foundation 6 upgrade**: the application top bar (red) and model top bar (gold) lost their fixed positioning, max-width, and 45/90px row heights. Foundation 6's `.row`/grid no longer styles the legacy `.contain-to-grid.fixed` wrapper, and its default `.top-bar` ships with `padding: 0.5rem` plus a flex layout that lets the inner `<h1>` push the bar to ~80px tall. **`app/assets/stylesheets/inline_forms/inline_forms.scss` and the mirrored `lib/generators/assets/stylesheets/inline_forms.scss`** now reproduce the F5 stacking explicitly: `.contain-to-grid.fixed` is `position: fixed; top:0; left:0; right:0; max-width: 62.5rem; margin: 0 auto; z-index: 99` so the chrome stays pinned to the top of the viewport at the same 1000px row width as the body content; `#inline_forms_application_top_bar.top-bar` and `#inline_forms_model_top_bar.top-bar` zero out F6's `.top-bar` padding/min-height and pin the inner `.menu-text h1` / `.menu > li > a` to `line-height: 45px` so the application bar is exactly 45px and the model bar is exactly 90px (45px top-padding + 45px usable). `#outer_container` keeps its `position: absolute; top: 90px` offset.
- **Generated apps had `.row` widths bumped from 1000px to 1200px** because Foundation 6's `$global-width` default is `75rem` (vs F5's `62.5rem` `$row-width`), making every body row 200px wider than the inline_forms admin chrome was designed for. **`app/assets/stylesheets/inline_forms/foundation_and_overrides.scss`** now overrides `$global-width: 62.5rem; $grid-row-width: $global-width;` AFTER `@import 'settings/settings'` (settings/_settings.scss assigns these without `!default`, so a pre-import override would lose). The flex grid emits its widths from these variables, so all `.row` containers now match the F5 1000px width without per-rule overrides.
- **Devise login banner (`/auth/users/sign_in`, `/auth/users/password/new`) was full-width and grey** instead of the F5-style centered dark-red strip. The devise top-bar partials wrap their nav in `.contain-to-grid` (no `.fixed` variant), so the new `.contain-to-grid.fixed` rule above did not apply; and Foundation 6's default `.top-bar` paints `$light-gray` on `.top-bar-left` / `.menu` / `.menu li`, which bled through the single `background-color: #A3381E` rule on the nav element. **`app/assets/stylesheets/inline_forms/devise.scss`** now constrains the bare `.contain-to-grid` directly (`max-width: 62.5rem; margin: 0 auto`) so the devise pages share the 1000px chrome width, and adds a compact `#inline_forms_devise_top_nav_bar.top-bar` block (zero padding, 45px height, dark red across `.top-bar-left` / `.menu` / `.menu li` / `.menu a`) so the inner sub-elements stop bleeding grey. The two devise top-bar partials (`app/views/devise/sessions/_top-bar.html.erb` and `app/views/devise/passwords/_top-bar-and-flash.html.erb`) keep their already-migrated F6 markup (`top-bar-left` / `ul.menu` / `menu-text`) unchanged.

## [7.2.4] - 2026-05-06

### Changed

- **ZURB Foundation**: generated apps now use **Foundation for Sites 6** (`foundation-rails` **~> 6.6.2**) instead of the legacy 5.5 line. Stylesheets use the Foundation 6 mixin entrypoint (`settings/settings` + selective `@include`s), **flex grid** (`foundation-flex-grid`) so existing `.row` / `.column` / `.columns` markup keeps working, plus small shims for Foundation 5 helpers (`.button.expand`, `.column.centered`). Top-bar partials were updated to the Foundation 6 layout (`top-bar-left` / `top-bar-right`, `ul.menu`, `ul.dropdown.menu` with `data-dropdown-menu`). Visibility / alignment classes were renamed where needed (`hide-for-large-up` → `hide-for-large`, `text-centered` → `text-center`). `$body-bg` references in SCSS now use **`$body-background`** (Foundation 6 settings).
- **Installer Gemfile** (`bin/inline_forms_installer_core.rb`): add **`autoprefixer-rails`** (recommended by foundation-rails). **`foundation-rails` is pinned to ~> 6.6.2** rather than 6.9+: newer foundation-rails releases assume Dart Sass (`math.*` in SCSS), which does not compile under **sassc** (the path still used here via `sass-rails`).

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