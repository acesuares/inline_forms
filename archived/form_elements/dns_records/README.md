# dns_records (archived)

**Archived in gem version:** 8.1.30  
**Reason:** App-specific leftover from a DNS-admin application. The show helper calls `object.a_records`, `object.template_a_records` and `record.djbdns_line(name)` — host APIs no other app has. Edit and update were empty methods. Never registered in `FormElementRegistry::ENTRIES` (the helper methods are named `dnsrecords_*`, so the attribute-list symbol was `:dnsrecords`).

## What it was

| Method | Behavior |
|--------|----------|
| `dnsrecords_show` | One `djbdns_line` per A record, `<br/>`-joined, raw |
| `dnsrecords_edit` | empty |
| `dnsrecords_update` | empty |

## Restore

```bash
cp archived/form_elements/dns_records/lib/inline_forms/form_elements/dns_records_helper.rb \
   lib/inline_forms/form_elements/
```

Remove `:dnsrecords` from `InlineForms::ARCHIVED_FORM_ELEMENTS`. Your app must provide `a_records` / `template_a_records` returning objects with `djbdns_line(name)`.

## Turbo

Display-only; no Turbo concerns.
