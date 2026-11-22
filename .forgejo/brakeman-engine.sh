#!/usr/bin/env bash
#
# Brakeman on a generated app together with the engine code.
#
#   .forgejo/brakeman-engine.sh APP [extra brakeman options]
#
# Brakeman skips gem code, so scanning the app alone never looks at the
# engine's controllers, helpers and views. Scanning the engine alone does not
# work either: without an app Brakeman cannot tell the Rails version and the
# templates do not parse. So: a temporary copy of APP with the engine's code
# in engines/, scanned as one application. APP itself is not touched.
#
# Accepted warnings, each with its reason, are in brakeman.ignore beside this
# file; --ensure-ignore-notes fails on one without a reason, and
# --ensure-no-obsolete-ignore-entries on one that no longer occurs. The paths
# in the copy are relative and fixed (engines/...), because Brakeman's
# fingerprints include them.
#
# Not scanned: lib/installer_templates and lib/generators (they produce code;
# what they produce is in APP).

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
app=$(cd "${1:?usage: brakeman-engine.sh APP [brakeman options]}" && pwd)
shift

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/app/engines/inline_forms" "$work/app/engines/inline_forms_schema_edit"

# No keys or credentials: Brakeman does not need them. Only those in config/:
# app code called credentials_controller.rb has to be scanned.
tar -C "$app" --anchored --exclude='config/credentials*' --exclude='config/*.key' -cf - \
  app config lib Gemfile Gemfile.lock | tar -C "$work/app" -xf -

for part in app config lib; do
  if [ -d "$root/$part" ]; then
    cp -R "$root/$part" "$work/app/engines/inline_forms/"
  fi
  if [ -d "$root/inline_forms_schema_edit/$part" ]; then
    cp -R "$root/inline_forms_schema_edit/$part" "$work/app/engines/inline_forms_schema_edit/"
  fi
done
rm -rf "$work/app/engines/inline_forms/lib/installer_templates" \
       "$work/app/engines/inline_forms/lib/generators"

# The version the ignore file was made with (its fingerprints can change with
# another one): gem install brakeman -v <brakeman_version in brakeman.ignore>.
version=$(ruby -rjson -e 'puts JSON.load_file(ARGV[0])["brakeman_version"]' "$here/brakeman.ignore")

# From a folder without a Gemfile: RVM's launchers load the bundle of the current
# folder and then ignore the version.
cd "$work"
found=$(brakeman "_${version}_" --version)
[ "$found" = "brakeman $version" ] || { echo "expected brakeman $version, got: $found" >&2; exit 1; }

brakeman "_${version}_" --no-pager \
  --add-engines-path engines/inline_forms,engines/inline_forms_schema_edit \
  -i "$here/brakeman.ignore" --ensure-ignore-notes --ensure-no-obsolete-ignore-entries \
  --path "$work/app" "$@"
