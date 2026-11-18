#!/usr/bin/env python3
"""Validates that every relative QML/JS import resolves to an existing file or
directory. qmllint does NOT catch broken relative script paths, so this check
runs in CI to prevent "Script file ... unavailable" errors at runtime."""
import os
import re
import sys
import glob

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad = []
    for path in glob.glob(os.path.join(root, "contents", "**", "*.qml"), recursive=True):
        base = os.path.dirname(path)
        with open(path, encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, 1):
                m = re.match(r'\s*import\s+"([^"]+)"', line)
                if not m:
                    continue
                target = os.path.normpath(os.path.join(base, m.group(1)))
                if not os.path.exists(target):
                    rel = os.path.relpath(path, root)
                    bad.append(f"{rel}:{lineno}: import \"{m.group(1)}\" -> {target} does not exist")
    if bad:
        print("\n".join(bad), file=sys.stderr)
        return 1
    print("all relative QML imports resolve")
    return 0

if __name__ == "__main__":
    sys.exit(main())
