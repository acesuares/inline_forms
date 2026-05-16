# Chicas project form elements (archived)

**Archived in gem version:** 7.6.0  
**Reason:** One-off widgets for a specific host application (“Chicas”). Comments in source stated they do not belong in the generic gem. No `_edit`/`_update` on photo lists; dropdown moves CarrierWave upload dirs via shell `mv`.

## Symbols

| Symbol | File | Role |
|--------|------|------|
| `:chicas_photo_list` | `chicas_photo_list.rb` | Read-only gallery: `object.<members>.<photos>` by rating (attribute name encodes association path, e.g. `members_photos`) |
| `:chicas_family_photo_list` | `chicas_family_photo_list.rb` | Same via `object.family.<members>.<photos>` |
| `:chicas_dropdown_with_family_members` | `chicas_dropdown_with_family_members.rb` | Belongs-to style picker over `o.family.clients`; on update rehomes upload folder with `mkdir`/`mv` |

## Host app requirements

- Models with `family`, `clients`, members, photos, CarrierWave `image`, `_dropdown_presentation`, etc. as assumed in the helpers.
- No generator `SPECIAL_COLUMN_TYPES` registration on photo lists (show-only).
- `:chicas_dropdown_with_family_members` registers `SPECIAL_COLUMN_TYPES[:dropdown]=:belongs_to` when loaded (same as stock dropdown).

## Restore

```bash
cp archived/form_elements/chicas/app/helpers/form_elements/chicas_*.rb \
   app/helpers/form_elements/
```

Remove the three symbols from `InlineForms::ARCHIVED_FORM_ELEMENTS` if restoring into the gem.

## Turbo / UJS

Photo lists are display-only. Dropdown uses standard inline edit (UJS or Turbo field path depending on app). Re-init jQuery UI slider N/A for these files.
