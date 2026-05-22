# Rails 8.0 release (8.0.x line)

**Shipped:** 2026-05-22  
**Tags:** `v8.0.3` (inline_forms, inline_forms_installer, validation_hints)

## Stack

| Component | Constraint |
|-----------|------------|
| Ruby | `>= 4.0` (generated apps: `ruby-4.0.4`) |
| Rails | `>= 8.0`, `< 8.1` |
| rails-i18n | `>= 8.0`, `< 9.0` |
| validation_hints | `>= 8.0.2`, `< 9.0` (release **8.0.3** lockstep) |

Install CLI:

```bash
gem install inline_forms_installer
inline_forms create MyApp -d sqlite --example
```

Pre-release local builds: installer auto-installs `*.gem` from `~/inline_forms` / `~/validation_hints` when present (no `path:` in consumer Gemfiles).

## Verification gate (2026-05-22)

| Check | Result |
|-------|--------|
| validation_hints `rake test` | 24 runs, 50 assertions, 0 failures |
| inline_forms `rake test` | 24 runs, 89 assertions, 0 failures |
| `inline_forms create MyApp -d sqlite --example` | OK (Rails 8.0.5) |
| `bundle exec rails zeitwerk:check` | All is good! |
| `bundle exec rails test` (MyApp) | **88 runs, 502 assertions, 0 failures, 0 errors, 0 skips** |
| `bundler-audit` (validation_hints lockfile) | No vulnerabilities found |

## Migration phases (maintainer runbook)

Canonical step-by-step: `stuff/rails8forReal.md` (local; gitignored in this repo). Mirror checklist: `validation_hints/stuff/rails-8-checklist.md`.

| Phase | Status |
|-------|--------|
| 0 Baseline | Done |
| 1 validation_hints → AR 8 | Done (8.0.1+) |
| 2 inline_forms engine → Rails 8 | Done (8.0.1+) |
| 3 Installer + example app | Done (8.0.2+) |
| 4 Framework defaults + audit | Done (8.0.3) — [`rails-8-phase4-audit.md`](rails-8-phase4-audit.md) |
| 5 Release + docs | Done (8.0.3) — this file |

## Zeitwerk

See [`zeitwerk-and-load-paths.md`](zeitwerk-and-load-paths.md). No remaining active code on pre-Zeitwerk `app/helpers/form_elements/` paths.

## Deferred

- Dart Sass 3.0 (`@import` removal) — not released; deprecations only on Dart Sass 1.x
- [`stuff/towards_rails_8.md`](../stuff/towards_rails_8.md) product bets (auth, encryption, …) — post-ship
- Asset pipeline (`stuff/pipeline.md`) — orthogonal
