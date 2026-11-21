#!/usr/bin/env bash
# Runs the QML unit tests (tests/qml/tst_*.qml).
#
# Requires:
#   - Qt 6 qmltestrunner (qt6-declarative / qt6-declarative-dev-tools)
#   - Plasma QML modules: org.kde.plasma.core, org.kde.plasma.plasmoid
set -euo pipefail

cd "$(dirname "$0")/.."

RUNNER="${QMLTESTRUNNER:-}"
if [[ -z "$RUNNER" ]]; then
    for candidate in qmltestrunner6 /usr/lib/qt6/bin/qmltestrunner; do
        if command -v "$candidate" >/dev/null 2>&1; then
            RUNNER="$candidate"
            break
        fi
    done
fi
# /usr/bin/qmltestrunner is often Qt 5 on many distros, so it is only used
# when it is actually linked against Qt 6.
if [[ -z "$RUNNER" ]] && command -v qmltestrunner >/dev/null 2>&1; then
    if ldd "$(command -v qmltestrunner)" 2>/dev/null | grep -q "libQt6Core"; then
        RUNNER="$(command -v qmltestrunner)"
    fi
fi
if [[ -z "$RUNNER" ]]; then
    echo "error: Qt 6 qmltestrunner not found (set QMLTESTRUNNER=/path/to/qmltestrunner)" >&2
    exit 1
fi

# "minimal" has no font database at all, so FontLoader always fails there and
# tests that draw from a bundled font could never pass; offscreen is the
# headless platform that keeps font loading (and rendering) working.
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-}"
if [[ -z "$QT_QPA_PLATFORM" ]]; then
    for platform_root in /usr/lib/qt6/plugins/platforms /usr/lib/x86_64-linux-gnu/qt6/plugins/platforms \
        /usr/lib64/qt6/plugins/platforms /usr/local/lib/qt6/plugins/platforms; do
        if [[ -f "$platform_root/libqoffscreen.so" ]]; then
            QT_QPA_PLATFORM="offscreen"
            break
        fi
    done
fi
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-minimal}"
export QML_IMPORT_PATH="${QML_IMPORT_PATH:-/usr/lib/qt6/qml}"

status=0
for test_file in tests/qml/tst_*.qml; do
    echo "== $test_file"
    "$RUNNER" -import tests/qml -input "$test_file" || status=1
done
exit "$status"
