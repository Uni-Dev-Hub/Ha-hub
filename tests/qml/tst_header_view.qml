import QtQuick
import QtTest
import "../../contents/l10n"
import "../../contents/ui/views" as Views

// The header shows the Home Assistant user picture in a Kirigami avatar and
// an optional entity value next to the greeting.
TestCase {
    name: "HeaderView"

    QtObject {
        id: fakeManager
        property bool isConnected: true
        property int entitiesRevision: 1
        property string serverName: "Test HA"
        property string connectionStatus: "Disconnected"
        property string primaryPersonName: "Alice"
        property string primaryPersonPictureUrl:
            "file:///usr/share/icons/breeze/preferences/22/preferences-desktop-theme-global.svg"
        property var entities: ({
            "sensor.outside": { entity_id: "sensor.outside", state: "-3.5", attributes: { unit_of_measurement: "°C" } }
        })
        function getEntity(id) { return entities[id] || null }
        function getCatalogEntry(id) { return id === "sensor.outside" ? { name: "Снаружи" } : null }
    }

    Views.HeaderView {
        id: header
        width: 420
        height: 64
        visible: true
        haManager: fakeManager
    }

    function findByProperty(item, property) {
        if (!item) return null
        if (item[property] !== undefined) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var found = findByProperty(kids[i], property)
            if (found) return found
        }
        return null
    }

    function texts(item, out) {
        out = out || []
        if (item && typeof item.text === "string" && item.text.length > 0) out.push(item.text)
        var kids = item ? (item.children || []) : []
        for (var i = 0; i < kids.length; i++) texts(kids[i], out)
        return out
    }

    function test_avatar_is_loaded_and_available() {
        wait(300)
        verify(header.pictureUrl.length > 0, "picture url reaches the header")
        var avatar = findByProperty(header, "asynchronous")
        verify(!!avatar, "the header contains a Kirigami avatar")
        compare(avatar.source, header.pictureUrl, "the avatar shows the user picture")
        compare(avatar.name, "Alice", "the avatar knows the user for its fallback")
        var image = findByProperty(avatar, "fillMode")
        verify(!!image, "the avatar hosts a picture image")
        compare(image.status, Image.Ready, "the picture loaded (status Ready)")
    }

    function test_header_entity_value_and_label() {
        compare(header.headerEntityText, "")
        header.headerEntityId = "sensor.outside"
        compare(header.headerEntityText, "-3.5 °C")
        header.headerEntityLabel = true
        compare(header.headerEntityText, "Снаружи: -3.5 °C")
        header.headerEntityId = ""
        header.headerEntityLabel = false
        compare(header.headerEntityText, "")
    }

    function test_greeting_and_status_are_rendered() {
        wait(50)
        var shown = texts(header, []).join(" | ")
        verify(shown.indexOf("Test HA") !== -1, "server name is shown: " + shown)
        verify(shown.indexOf(Loc.t("Connected")) !== -1, "connection state is shown: " + shown)
    }
}
