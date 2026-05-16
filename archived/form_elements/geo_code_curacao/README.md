# `:geo_code_curacao` form element (archived)

**Archived in gem version:** 7.6.0  
**Reason:** Curaçao-specific street geocoder tied to legacy MySQL tables (`Zones`, `Buurten`, `Straatcode`), jQuery UI autocomplete, and UJS `list_streets.js.erb`. Not used by the `--example` app; blocks clean Turbo/UJS removal while inactive.

## What it did

- **Generator / model:** declare e.g. `address:geo_code_curacao` → string column storing a 6-digit zone/neighbourhood/street code.
- **Show:** human-readable `"Street, Zone"` via `GeoCodeCuracao#presentation`.
- **Edit:** text field + jQuery UI autocomplete hitting `GET /geo_code_curacao?term=…` (JSON labels).
- **Update:** parses six digits from submitted text, validates against `Straatcode`, stores code or `nil`.

## Files in this archive

| Path under `app/` | Role |
|-------------------|------|
| `helpers/form_elements/geo_code_curacao.rb` | `_show` / `_edit` / `_update`; registers `SPECIAL_COLUMN_TYPES[:geo_code_curacao]=:string` |
| `models/geo_code_curacao.rb` | Lookup, validation, raw SQL autocomplete |
| `controllers/geo_code_curacao_controller.rb` | `list_streets` action |
| `views/geo_code_curacao/list_streets.js.erb` | Returns JSON for autocomplete (UJS/JS request) |
| `views/geo_code_curacao/list_streets.html.erb` | Unused HTML variant |

## Host app requirements (when active)

1. **Database:** MySQL (or compatible) with tables `Zones`, `Buurten`, `Straatcode` and legacy column names (`ZONECODE`, `NBRHCODE`, `STREETCODE`, `NAME`, …) as expected by `GeoCodeCuracao.lookup` and `Street.find_by_ZONECODE_and_NBRHCODE_and_STREETCODE`.
2. **Routes** (not shipped by inline_forms installer; add to host `config/routes.rb`):

   ```ruby
   get "geo_code_curacao", to: "geo_code_curacao#list_streets"
   ```

3. **jQuery UI** autocomplete (already in `inline_forms.js` bundle when using stock assets).
4. **Turbo note:** edit partial embeds inline `<script>` for `#geo_code_curacao` autocomplete; field swaps need `turbo:frame-load` re-init if you restore this on a Turbo field path (see `docs/ujs-to-turbo.md` geo section — archived as of 7.6.0).

## Restore into the gem

```bash
# From gem root
cp archived/form_elements/geo_code_curacao/app/helpers/form_elements/geo_code_curacao.rb \
   app/helpers/form_elements/
cp archived/form_elements/geo_code_curacao/app/models/geo_code_curacao.rb \
   app/models/
cp archived/form_elements/geo_code_curacao/app/controllers/geo_code_curacao_controller.rb \
   app/controllers/
mkdir -p app/views/geo_code_curacao
cp archived/form_elements/geo_code_curacao/app/views/geo_code_curacao/* \
   app/views/geo_code_curacao/
```

Then remove `:geo_code_curacao` from `InlineForms::ARCHIVED_FORM_ELEMENTS` in `lib/inline_forms.rb` (optional if only your app uses it), document in CHANGELOG, and run the example app / host app tests.

## Restore only in a host application (vendor)

Copy the same files into your app’s `app/` tree (adjust namespaces if you drop the engine). Remove the symbol from any `inline_forms_attribute_list` until files are in place. Prefer migrating to a modern geocoding field rather than restoring unless you still maintain the Curaçao street tables.

## Generator usage (historical)

```bash
rails g inline_forms Address street:geo_code_curacao
```

After archive, the generator still accepts unknown types only with `--allow-unknown`; `:geo_code_curacao` is listed in `ARCHIVED_FORM_ELEMENTS` and will raise at boot if declared on a model.
