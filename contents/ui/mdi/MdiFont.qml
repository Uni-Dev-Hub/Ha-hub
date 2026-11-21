pragma Singleton
import QtQuick

// Single shared handle on the bundled Material Design Icons font.
//
// Home Assistant refers to its entity icons by MDI name ("mdi:ceiling-light")
// and draws them from this font, so the widget ships the font as well (see
// contents/fonts/LICENSE) and draws the same glyphs. FontLoader registers the
// font per instance, hence a singleton: a dashboard with twenty tiles should
// not load 1.3 MB of font twenty times.
QtObject {
    id: mdiFont

    // The file URL is resolved against this file, which works both from the
    // source tree and from an installed package.
    readonly property FontLoader loader: FontLoader {
        source: Qt.resolvedUrl("../../fonts/materialdesignicons-webfont.ttf")
    }

    // "" until the font is registered, so callers can keep showing the icon
    // theme instead of an empty box while loading.
    readonly property string family: loader.status === FontLoader.Ready ? loader.name : ""
}
