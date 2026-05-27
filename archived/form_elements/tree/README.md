# `:tree` form element + `:move` reparent helper (archived)

**Archived in gem version:** 7.7.0  
**Reason:** Hierarchical child lists depend on host-app APIs that were never defined inside inline_forms (`#children`, `#hash_tree_to_collection`, `#add_child`). Typical integrations used an external tree gem (e.g. **awesome_nested_set**, **acts_as_tree**, or a custom concern). The example app has no tree model; keeping the partial active implied support the gem did not provide.

## What it did

Declare in `inline_forms_attribute_list`, e.g. `[ :children, :tree ]`:

- **`_show.html.erb`:** header “Children”, `+` for new child, `<turbo-frame>` wrapping **`_tree.html.erb`**.
- **`_tree.html.erb`:** lists `parent.children` with Turbo row open, list-frame pagination (`update=…_list`).
- **`create`:** skips `:tree` attributes on the new-record form (like `:associated`).
- **`:move`:** separate form element (`move.rb`) to reparent a node via `hash_tree_to_collection` + `add_child` (host must implement both on the model class).

Top-level parents use `parent_id` **nil** on roots; children point at the parent record.

## Files in this archive

| Path | Role |
|------|------|
| `app/views/inline_forms/_tree.html.erb` | Child list partial (Turbo frames, 7.7.0) |
| `app/helpers/form_elements/move.rb` | Reparent dropdown (`:move`) |
| `app/views/inline_forms/_show_tree.html.erb` | `_show` branch removed in 7.7.0 — paste back into `_show.html.erb` |

## Host app requirements

1. Self-referential model, e.g. `belongs_to :parent, class_name: "Outline", optional: true` and `has_many :children, class_name: "Outline", foreign_key: "parent_id"`.
2. **`children`** scope/method returning child records (same class).
3. For **`:move`:** class methods **`hash_tree_to_collection`** (options for select) and instance **`add_child(node)`** — historically copied from a host app using a tree gem, not implemented in inline_forms.
4. Optional: **`INLINE_FORMS_TREE_INDENT`** constant (default true) for left spacer in `_show`.

## Restore

```bash
cp archived/form_elements/tree/app/views/inline_forms/_tree.html.erb \
   app/views/inline_forms/
cp archived/form_elements/tree/app/helpers/form_elements/move.rb \
   app/helpers/form_elements/
# Merge archived/form_elements/tree/app/views/inline_forms/_show_tree.html.erb
# into app/views/inline_forms/_show.html.erb (see comments in that fragment).
```

Remove `:tree` and `:move` from `InlineForms::ARCHIVED_FORM_ELEMENTS` when restoring into the gem.

## Turbo / UJS

Archive copy is the **7.7.0 Turbo** tree partial (frames + HTML row open). No `*.js.erb` row templates required when paired with current `InlineFormsController` row Turbo paths.
