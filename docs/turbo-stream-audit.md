# Turbo Stream audit (optional)

Stock inline_forms flows use **`format.html`** inside matching `<turbo-frame>` ids. **`format.turbo_stream`** is used where a single response must update **multiple** frames (e.g. revert from the versions panel).

## Current turbo_stream usage

| Action | Response | Notes |
|--------|----------|-------|
| `revert` | `turbo_stream.replace` row + versions frames | Required when POST originates inside `*_versions` frame |

## Candidates for future streams (not migrated)

- Row destroy fade-out animation (today: HTML `row_destroyed` replaces frame)
- Multi-field batch updates (no stock flow today)

No change required for the example app; integration tests assert HTML frame contracts.
