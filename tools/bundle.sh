#!/bin/sh
# Copies the plan-tools bundle into DEST (a ct/ folder) and stamps VERSION with the addon version.
# make install-skill, build-plugin and build-toolkit all call it, so their ct/ folders hold the same files.
# Usage (from the checkout root): sh tools/bundle.sh DEST "FILES" "DIRS"
dest=$1; files=$2; dirs=$3
[ -n "$dest" ] || { echo "bundle: no destination" >&2; exit 1; }
for f in $files; do
    mkdir -p "$dest/$(dirname "$f")" && cp "$f" "$dest/$f" || { echo "bundle: copying $f failed" >&2; exit 1; }
done
for d in $dirs; do
    mkdir -p "$dest/$d" && cp -R "$d/." "$dest/$d" || { echo "bundle: copying $d failed" >&2; exit 1; }
done
ver=$(sed -n 's/^## Version: *//p' CheckThat/CheckThat_Vanilla.toc)
[ -n "$ver" ] || { echo "bundle: no ## Version: in CheckThat/CheckThat_Vanilla.toc" >&2; exit 1; }
echo "$ver" > "$dest/VERSION"
