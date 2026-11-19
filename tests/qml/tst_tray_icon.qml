import QtQuick
import QtTest
import "../../contents/ui/components" as Components
import "../../contents/ui" as Ui

// Which icon the panel/tray shows is a user choice: follow the connection,
// pick a theme icon, or use an own picture.
TestCase {
    name: "TrayIcon"

    Components.IconPickerField {
        id: iconField
        width: 400
        height: 48
        visible: true
    }

    Ui.CompactRepresentation {
        id: compact
        width: 32
        height: 32
        visible: true
        haManager: null
    }

    function findByName(item, objectName) {
        if (!item) return null
        if (item.objectName === objectName) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var found = findByName(kids[i], objectName)
            if (found) return found
        }
        return null
    }

    function themedIcon(root) {
        return findByName(root, "trayThemedIcon")
    }

    function test_field_starts_in_auto_mode() {
        wait(50)
        compare(iconField.mode, "auto")
        compare(iconField.resolved.name, "network-server-symbolic")
        compare(iconField.resolved.path, "")
    }

    function test_field_theme_choice_is_reported() {
        var signals = 0
        var target = iconField
        target.iconChanged.connect(function () { signals++ })
        iconField.chooseThemeIcon("home")
        compare(signals, 1)
        compare(iconField.mode, "theme")
        compare(iconField.iconName, "home")
        compare(iconField.resolved.name, "home")
        // A theme icon must never leak a stale custom path.
        compare(iconField.iconPath, "")
    }

    function test_field_custom_picture_gets_a_file_url() {
        var real = "/usr/share/icons/breeze/preferences/22/preferences-desktop-theme-global.svg"
        iconField.iconPath = real
        iconField.mode = "custom"
        wait(150)
        compare(iconField.resolved.path, real)
        compare(iconField.previewUrl, "file://" + real)

        iconField.iconPath = "file://" + real
        compare(iconField.previewUrl, "file://" + real)
    }

    function test_field_reset_returns_to_auto() {
        iconField.chooseAuto()
        compare(iconField.mode, "auto")
        compare(iconField.iconName, "")
        compare(iconField.iconPath, "")
    }

    function test_compact_falls_back_to_status_icons() {
        wait(50)
        compare(compact.imageSource, "")
        var icon = themedIcon(compact)
        verify(!!icon, "the compact representation has a themed icon")
        compare(icon.source, "network-offline")
    }

    function test_compact_uses_a_theme_icon_when_configured() {
        compact.preferredIconName = "home"
        compare(themedIcon(compact).source, "home")
        compact.preferredIconName = ""
        compare(themedIcon(compact).source, "network-offline")
    }

    function test_compact_uses_a_custom_picture() {
        var real = "/usr/share/icons/breeze/preferences/22/preferences-desktop-theme-global.svg"
        compact.preferredImagePath = real
        compare(compact.imageSource, "file://" + real)
        wait(250)
        var picture = findByName(compact, "trayPicture")
        verify(!!picture, "a picture item exists")
        // .visible is always false under qmltestrunner, so the load state and
        // the source are what can be asserted.
        verify(picture.loaded, "the custom picture loads")
        compact.preferredImagePath = ""
        compare(compact.imageSource, "")
        compare(findByName(compact, "trayPicture").loaded, false, "the picture is dropped again")
    }
}
