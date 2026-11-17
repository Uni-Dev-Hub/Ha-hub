#!/usr/bin/env bash
# Extracts strings, updates .po files, compiles .mo files into the package
# and (with --package) builds the .plasmoid archive for the KDE Store.
#
#   translate/build.sh            update template + catalogs, compile .mo
#   translate/build.sh --package  same, then create dist/<id>-<version>.plasmoid
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ID="$(python3 -c 'import json;print(json.load(open("metadata.json"))["KPlugin"]["Id"])')"
VERSION="$(python3 -c 'import json;print(json.load(open("metadata.json"))["KPlugin"]["Version"])')"
DOMAIN="plasma_applet_${ID}"

# 1. Template
find contents -name '*.qml' -o -name '*.js' | sort > translate/.files
xgettext --from-code=UTF-8 -C --no-wrap -ki18n:1 -ki18np:1,2 -ktr:1 \
    --package-name="HA-Hub Revived" --package-version="$VERSION" \
    -o translate/template.pot -f translate/.files 2>/dev/null
rm -f translate/.files
sed -i 's/^#, c-format$/#, kde-format/' translate/template.pot

# 2. Merge + compile every catalog
for po in translate/*.po; do
    lang="$(basename "$po" .po)"
    msgmerge --quiet --no-wrap --update --backup=none "$po" translate/template.pot
    sed -i 's/^#, c-format$/#, kde-format/' "$po"
    mkdir -p "contents/locale/$lang/LC_MESSAGES"
    msgfmt --check -o "contents/locale/$lang/LC_MESSAGES/${DOMAIN}.mo" "$po"
    echo "$lang: $(msgfmt --statistics -o /dev/null "$po" 2>&1)"
done

# 3. Optional store package (a .plasmoid is a zip of metadata.json + contents/)
if [[ "${1:-}" == "--package" ]]; then
    mkdir -p dist
    out="dist/${ID}-${VERSION}.plasmoid"
    rm -f "$out"
    python3 - "$out" <<'PY'
import sys, os, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for top in ("metadata.json", "LICENSE", "contents"):
        if os.path.isfile(top):
            z.write(top)
            continue
        for d, _, files in os.walk(top):
            for f in sorted(files):
                if not f.endswith(("~", ".po")):
                    z.write(os.path.join(d, f))
PY
    echo "Package: $out"
fi
