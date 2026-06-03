# CKEditor-era form elements (archived)

**Archived in gem version:** 8.1.21  
**Reason:** CKEditor was removed in 7.3.0; these symbols were thin legacy aliases kept for backward compatibility.

| Symbol | Was | Use instead |
|--------|-----|-------------|
| `:ckeditor` | Delegated to `:rich_text` | `:rich_text` (ActionText / Trix) |
| `:text_area_without_ckeditor` | Delegated to `:plain_text` | `:plain_text` or `:plain_text_area` |

## Restore

Copy helpers back into the gem:

```bash
cp archived/form_elements/ckeditor/lib/inline_forms/form_elements/ckeditor_helper.rb \
   lib/inline_forms/form_elements/
cp archived/form_elements/ckeditor/lib/inline_forms/form_elements/text_area_without_ckeditor_helper.rb \
   lib/inline_forms/form_elements/
```

Re-add registry entries in `lib/inline_forms/form_element_registry.rb` and remove the symbols from `InlineForms::ARCHIVED_FORM_ELEMENTS`.

## Turbo

No special Turbo concerns; these were delegators to `:rich_text` and `:plain_text`.
