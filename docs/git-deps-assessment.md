# Git-sourced installer dependencies — assessment

**Date:** 2026-05-19  
**Context:** Generated apps from `inline_forms create` used three non-RubyGems pins: `tabs_on_rails` (git + branch), `i18n-active_record` (git), and a commented `will_paginate` fork. This doc records why they existed and what replaced them.

**Related (risk callouts only):** `validation_hints/stuff/rails-7.2-zeitwerk-plan.md` (Track A3), `validation_hints/stuff/rails-8-checklist.md` (Phase 3).

---

## Summary (7.13.5+)

| Gem | Was | Now | Reason |
|-----|-----|-----|--------|
| `will_paginate` | RubyGems + commented acesuares fork | RubyGems only | Fork never active; comment removed |
| `tabs_on_rails` | `acesuares/tabs_on_rails` branch `update_remote_before_action` | `~> 3.0` (weppos, RubyGems) | Fork only added unused `:remote` on tab links; upstream 3.0.0 already uses `before_action` |
| `i18n-active_record` | `acesuares/i18n-active_record` (2012) | **Removed** (7.13.18: no DB translation tables) | Never configured `I18n.backend`; DB tables/view and `extract_translations` removed |

**No generated-app Gemfile should use `:git` for these anymore.**

---

## `will_paginate`

- **Fork:** `https://github.com/acesuares/will_paginate.git` (commented out for years).
- **Usage:** Nested/top-level list pagination in `_list.html.erb`; Turbo Frame nav since 7.5.x (no `:remote => true`).
- **Verdict:** RubyGems `will_paginate` is sufficient. No acesuares-specific behavior required.

---

## `tabs_on_rails`

### Why the fork existed

Branch `update_remote_before_action` on `acesuares/tabs_on_rails` (2019) did two things:

1. `before_filter` → `before_action` (Rails 4+ rename).
2. Optional `:remote => true` on `tab_for` links (`tabs_builder.rb`).

### What inline_forms actually uses

- Controllers call **`set_tab :resource`** only (generator template + installer).
- Top bar is **not** built with `tabs_tag` / `tab_for`; `_inline_forms_tabs.html.erb` is a Foundation top-bar with search + new button.
- Turbo migration removed **`data-remote`** from inline UI; no code passes `:remote` into tabs.

### Upstream today

- **RubyGems:** `tabs_on_rails` **3.0.0** (weppos, 2017).
- **`set_tab`** already uses **`before_action`** in `lib/tabs_on_rails/action_controller.rb`.
- **Missing vs fork:** `:remote` on tab links only — **unused by inline_forms**.

### Verdict

**Use `gem 'tabs_on_rails', '~> 3.0'`.** No runtime dependency on the fork. Re-test on Rails 7.2+ / 8.0 when upgrading (gem is unmaintained but tiny).

---

## `i18n-active_record`

### History

- Fork existed because MySQL reserves `KEY`; acesuares fork used **`thekey`**.
- **7.13.5–7.13.17:** gem removed from Gemfile; installer still generated locale/key/translation tables + `translations` view; **`InlineForms::TranslationRecord`** read the view; **`extract_translations`** exported YAML (never routed by default).
- **`I18n.backend` was never** `I18n::Backend::ActiveRecord` in generated apps.

### Verdict (7.13.18+)

**No DB translation layer.** Generated apps use Rails I18n YAML only (`config/locales/inline_forms_local.en.yml`, etc.). If **I18n::Backend::ActiveRecord** is needed later, add **`i18n-active_record ~> 1.4`** and migrations separately—not via inline_forms installer.

---

## Previously removed forks (reference)

| Gem | Removed in | Replacement |
|-----|------------|-------------|
| `devise-i18n` | 7.3.4 / 7.10+ | RubyGems `~> 1.16` |
| `paper_trail` | 7.0.x | RubyGems `~> 16.0` |
| `switch_user` | 7.2.x | Removed from installer |

---

## Verification

After changing `installer_core.rb`:

```bash
cd /home/code/inline_forms && rvm use . && gem build inline_forms.gemspec && gem build inline_forms_installer.gemspec
cd /home/code/testInline && rvm use .
gem install /home/code/inline_forms/inline_forms-*.gem /home/code/inline_forms/inline_forms_installer-*.gem
rm -rf MyApp && inline_forms create MyApp -d sqlite --example
cd MyApp && rvm use . && bundle exec rails test
```

Expect **0 failures**; `Gemfile.lock` should list `tabs_on_rails (3.0.0)` and **no** `i18n-active_record` git source.
