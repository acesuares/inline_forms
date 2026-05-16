# `:kansen_slider` form element (archived)

**Archived in gem version:** 7.6.0  
**Reason:** Project-specific jQuery UI slider for integer-coded “kansen” (chance) scales. Uses inline `<script>` per field, `attribute_values(object, attribute)` on the model, and custom layout via `@BUTTONS_UNDER` in `_edit.html.erb` (removed from that list in 7.6.0).

## Behavior

- **Show:** read-only jQuery UI slider when value is 1–5; otherwise plain label from `attribute_values`.
- **Edit:** interactive slider; updates hidden input and label on slide.
- **Update:** assigns integer from `params[:_<model>][attribute]`.
- **Migration:** `SPECIAL_COLUMN_TYPES[:kansen_slider]=:integer`.

## Dependencies

- jQuery UI slider (in `inline_forms.js` bundle).
- Host model implements `attribute_values` for the attribute (see `InlineFormsHelper#attribute_values`).

## Restore

```bash
cp archived/form_elements/kansen_slider/app/helpers/form_elements/kansen_slider.rb \
   app/helpers/form_elements/
```

If you need OK/cancel buttons below the slider in edit forms, add `"kansen_slider"` back to `@BUTTONS_UNDER` in `app/views/inline_forms/_edit.html.erb`.

Remove `:kansen_slider` from `InlineForms::ARCHIVED_FORM_ELEMENTS` when restoring into the gem.

## Turbo

Inline scripts must be re-bound on `turbo:frame-load` if used inside Turbo field frames (not done in archive).
