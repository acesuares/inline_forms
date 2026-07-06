# question_list (archived)

**Archived in gem version:** 8.1.30  
**Reason:** App-specific leftover. The edit helper hardcodes a host `Question` model with a `subquestions` association (survey-style app), the show helper iterates a HABTM-ish collection of `_presentation`s, and the update writes `<attribute singular>_ids`. No example app ever exercised it, and it cannot render without that exact host schema.

## What it was

| Method | Behavior |
|--------|----------|
| `question_list_show` | `<ul>` of the association's `_presentation`s, each linking to inline edit |
| `question_list_edit` | Static nested `<ul>` of ALL `Question.all` + `question.subquestions` (read-only markup, despite being the edit state) |
| `question_list_update` | `object.<attr singular>_ids = params[attr].keys` |

## Restore

```bash
cp archived/form_elements/question_list/lib/inline_forms/form_elements/question_list_helper.rb \
   lib/inline_forms/form_elements/
```

Re-add `:question_list => :no_migration` to `FormElementRegistry::ENTRIES` and remove `:question_list` from `InlineForms::ARCHIVED_FORM_ELEMENTS`. Your app must define `Question` (with `subquestions`) and the HABTM association named by the attribute.

## Turbo

Pre-Turbo markup; the edit state renders no form inputs, so it never round-tripped through the 7.x UJS → Turbo migration. Expect to rework it if restored.
