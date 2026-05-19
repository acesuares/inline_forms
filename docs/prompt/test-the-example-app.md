You are in the inline_forms gem repo at /home/code/inline_forms.

Goal:
Build the current gem, install it into /home/code/testInline, recreate MyApp from scratch using --example, and verify it with Rails tests.

Do all steps end-to-end without asking for confirmation unless a command fails.

Steps:
1) In /home/code/inline_forms:
   - Ensure latest code is used.
   - Run: rvm use .
   - Build gems: gem build inline_forms.gemspec && gem build inline_forms_installer.gemspec
   - Confirm the built file names/versions (inline_forms-<version>.gem, inline_forms_installer-<version>.gem).

2) In /home/code/testInline:
   - Remove old app if present: /home/code/testInline/MyApp
   - Run: rvm use .
   - Install the freshly built gems from /home/code/inline_forms/inline_forms-<version>.gem and inline_forms_installer-<version>.gem

3) Still in /home/code/testInline:
   - Generate fresh example app:
     inline_forms create MyApp -d sqlite --example

4) In /home/code/testInline/MyApp:
   - Run: rvm use .
   - Run verification: bundle exec rails test

Output requirements:
- Briefly report each phase result (build, install, app generation, test run).
- Include exact commands run.
- Include test summary (runs/assertions/failures/errors/skips).
- If anything fails, stop at the failing step and include the exact error and the next corrective command you recommend.
