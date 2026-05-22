# Rails 8 — Phase 4 audit (framework defaults & cleanup)

**Date:** 2026-05-22  
**Scope:** Post–Phase 3 (`inline_forms` 8.0.2 installer + example app gate).

## 4.1 Framework defaults (`rails new` 8.0.5)

Vanilla `rails _8.0.5_ new` (importmap, `--skip-bundle`):

- `config/application.rb`: `config.load_defaults 8.0`, `config.autoload_lib(ignore: %w[assets tasks])`
- Generator **removes** `config/initializers/new_framework_defaults_8_0.rb` (opt-in flags live only in the railties template until uncommented)
- Optional 8.0 toggles (all commented in upstream template): `active_support.to_time_preserves_timezone`, `action_dispatch.strict_freshness`, `Regexp.timeout`

**Installer decision:** Match vanilla Rails 8 — rely on `load_defaults 8.0` only; do **not** ship `new_framework_defaults_8_0.rb` in generated apps. Keep a belt-and-suspenders `gsub` to `load_defaults 8.0` if an older `rails new` left another minor.

## 4.2 Rails 8 API / deprecation grep

| Area | Result |
|------|--------|
| `form_with` / `model: nil` | No engine usage; inline fields use custom helpers / Turbo, not `form_with` |
| `form_for` | Devise templates only (upstream Devise 5) |
| `ActiveRecord::Base.connection` | Unicorn `before_fork` template updated → `connection_pool.disconnect!` |
| `ActionController` deprecated flags | None in `lib/` |
| Generator migrations | `ActiveRecord::Migration[8.0]` (tests assert) |

## 4.3 Dart Sass / SCSS

Foundation + engine SCSS still emit Dart Sass 1.x deprecation warnings during `dartsass:build`. Accepted for 8.0 ship; migrate to `@use` / `color.scale` before Dart Sass 3.0 (see `stuff/pipeline.md`).

## 4.4 bundler-audit

| Lockfile | Result (2026-05-22) |
|----------|---------------------|
| `validation_hints/Gemfile.lock` | No vulnerabilities found |
| Example app `MyApp/Gemfile.lock` | No vulnerabilities found (`bundler-audit` on default gemset) |

## 4.5 Example app gate (unchanged baseline)

`inline_forms create MyApp -d sqlite --example` → **88 runs, 502 assertions, 0 failures, 0 errors, 0 skips** (Phase 3, Rails 8.0.5 stack).
