#!/usr/bin/env python3
"""Validates QML sources that qmllint cannot see:
- every relative QML/JS import resolves to an existing file or directory
  (a broken path surfaces at runtime as "Script file ... unavailable");
- every file that uses the Loc singleton imports the l10n module, otherwise
  every Loc.t() call throws "Loc is not defined" when that file is created.
qmllint does not catch either problem."""
import os
import re
import sys
import glob

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad = []
    for path in glob.glob(os.path.join(root, "contents", "**", "*.qml"), recursive=True):
        base = os.path.dirname(path)
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8") as fh:
            source = fh.read()
        for lineno, line in enumerate(source.splitlines(), 1):
            m = re.match(r'\s*import\s+"([^"]+)"', line)
            if not m:
                continue
            target = os.path.normpath(os.path.join(base, m.group(1)))
            if not os.path.exists(target):
                bad.append(f"{rel}:{lineno}: import \"{m.group(1)}\" -> {target} does not exist")
        code = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
        code = re.sub(r"//.*", "", code)
        if re.search(r'(?<![\w.])Loc\.', code):
            imports = re.findall(r'^\s*import\s+"([^"]+)"', source, re.M)
            if not any(i.rstrip("/").endswith("l10n") for i in imports):
                bad.append(f"{rel}: uses Loc but does not import the l10n module")
    if bad:
        print("\n".join(bad), file=sys.stderr)
        return 1
    print("all relative QML imports resolve; Loc imports are complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())
