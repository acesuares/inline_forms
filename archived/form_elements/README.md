# Archived form elements

Form elements are Ruby files that define `#{name}_show`, `#{name}_edit`, and `#{name}_update` helpers. The engine loads them from:

```ruby
Dir[File.dirname(__FILE__) + "/form_elements/*.rb"].each { |f| require f }
```

Only **top-level** `app/helpers/form_elements/*.rb` files are loaded. Subdirectories (including this `archived/` tree) are ignored.

## Why archive instead of delete?

- **Turbo migration:** Some elements (e.g. `:geo_code_curacao`) still depend on jQuery UI autocomplete and `*.js.erb` responses. Parking them avoids maintaining dead code paths in the active tree while keeping a known-good reference.
- **Rare domains:** Curaçao street geocoding or one-off project widgets may be needed again; restoration should be copy-paste plus README steps, not archaeology in git.

## Per-element folders

Each subdirectory is named after the `params[:form_element]` / generator type symbol (e.g. `geo_code_curacao`).

Inside:

- `README.md` — purpose, DB schema, routes, generator usage, Turbo notes, restore checklist
- `app/` — snapshot of files that lived under the engine `app/` directory

## Related: removed without archive copy

`:absence_list` was removed in **6.3.0** without a copy in this tree. See the main [archived README](../README.md) catalog and CHANGELOG.
