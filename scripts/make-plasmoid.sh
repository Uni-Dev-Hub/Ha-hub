#!/usr/bin/env bash
# Packages the widget into a .plasmoid (KPackage zip) in dist/.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(node -p "JSON.parse(require('fs').readFileSync('metadata.json','utf8')).KPlugin.Version" 2>/dev/null || python3 -c "import json;print(json.load(open('metadata.json'))['KPlugin']['Version'])")"
ID="$(node -p "JSON.parse(require('fs').readFileSync('metadata.json','utf8')).KPlugin.Id" 2>/dev/null || python3 -c "import json;print(json.load(open('metadata.json'))['KPlugin']['Id'])")"
OUT="dist/${ID}-${VERSION}.plasmoid"

mkdir -p dist
rm -f "$OUT"
zip -q -r "$OUT" contents metadata.json
echo "created $OUT"
