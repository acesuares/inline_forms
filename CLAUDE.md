# CLAUDE.md — inline_forms

Instructions for any work in the inline_forms repo
(`/srv/vmsshared/projects/inline_forms`; validation_hints is its sibling
`/srv/vmsshared/projects/validation_hints`).
These apply to all work here and take precedence over global defaults where they
conflict. Consolidated from the former `stuff/prompt/workflow.md` and
`stuff/prompt/test-the-example-app.md`.

## Workflow after any significant change

1. Run the full example-app test (see **Testing the example app** below). Keep
   improving until all tests succeed.
2. Bump the **patch** version. Stay in the **8.1** line until further notice.
   Never bump the minor version — even for big or breaking changes.
   - Change the version in **all four gems** so they stay in lockstep, always,
     even if nothing changed in some of them:
     `validation_hints`, `inline_forms`, `inline_forms_installer`, and
     `inline_forms_schema_edit` (in this repo under `inline_forms_schema_edit/`).
3. Update the Changelog of all four gems.
4. Commit everything.
   - Publishing to RubyGems is not part of this workflow: Ace runs
     `rake release` as `ace` in both repos. Never `gem push`, and never build
     gems for publishing; local builds are only for the example-app test.
5. After committing, push to the `forgejo` remote
   (`ssh://forgejo@dev02:2222/ace/...`) in **both repos** (inline_forms and
   validation_hints) so every commit runs through CI (Forgejo Actions on dev02).
   - Check the run at http://dev02:3300/ace/inline_forms/actions and fix
     failures.
6. Never push to `origin` (GitHub). Only Ace pushes there, and GitHub must not
   run anything (no `.github/workflows`).

## Testing the example app

Goal: build the current gems, install them into
`/srv/vmsshared/projects/testInline`, recreate `MyApp` from scratch using
`--example`, and verify it with Rails tests.

`/srv/vmsshared/projects/testInline` replaces the old `/home/code/testInline`
(only user `code` can read `/home/code`). It holds `.ruby-version`
(`ruby-4.0.4`) and `.ruby-gemset` (`testInline`), and the generated app gets
its own `@MyApp` gemset. Both gemsets are shared by everyone on this machine:
do not build or install while another session is running this test.

Do all steps end-to-end without asking for confirmation unless a command fails.

### Steps

1. In `/srv/vmsshared/projects/inline_forms` (or the worktree you work in):
   - Ensure the latest code is used.
   - Run: `rvm use .`
   - Build gems:
     `gem build inline_forms.gemspec && gem build inline_forms_installer.gemspec && (cd inline_forms_schema_edit && gem build inline_forms_schema_edit.gemspec)`
   - In `/srv/vmsshared/projects/validation_hints`:
     `gem build validation_hints.gemspec`
   - Confirm the built file names/versions
     (`inline_forms-<version>.gem`, `inline_forms_installer-<version>.gem`,
     `inline_forms_schema_edit/inline_forms_schema_edit-<version>.gem`,
     `validation_hints-<version>.gem`).

2. In `/srv/vmsshared/projects/testInline`:
   - Remove the old app if present: `/srv/vmsshared/projects/testInline/MyApp`
   - Run: `rvm use .`
   - Install the freshly built gems: `validation_hints-<version>.gem`,
     `inline_forms-<version>.gem`, `inline_forms_installer-<version>.gem` and
     `inline_forms_schema_edit/inline_forms_schema_edit-<version>.gem`.

3. Still in `/srv/vmsshared/projects/testInline`:
   - Point the installer at the checkouts holding the built gems, so it
     installs them into the app's `@MyApp` gemset. Without these it silently
     uses whatever older inline_forms that gemset already has (it only looks
     in `~/code/<repo>` and `~/<repo>` by itself):
     `export INLINE_FORMS_RELEASE_ROOT=<the inline_forms checkout you built in> VALIDATION_HINTS_ROOT=/srv/vmsshared/projects/validation_hints`
   - Generate a fresh example app:
     `inline_forms create MyApp -d sqlite --example`
   - Check that the "Install complete" summary shows the version you built.

4. In `/srv/vmsshared/projects/testInline/MyApp`:
   - Run: `rvm use .`
   - Run verification: `rails test`

### Output requirements

- Briefly report each phase result (build, install, app generation, test run).
- Include the exact commands run.
- Include the test summary (runs/assertions/failures/errors/skips).
- If anything fails, stop at the failing step and include the exact error and
  the next corrective command you recommend.
