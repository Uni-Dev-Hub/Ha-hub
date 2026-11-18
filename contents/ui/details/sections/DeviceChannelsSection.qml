import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../code/ha_helpers.mjs" as HAHelpers
import "../../../l10n"

Rectangle {
    id: channelsSec
    required property var detailsPage
    required property var haManager

    readonly property var channels: detailsPage.channelsList || []

    Layout.fillWidth: true
    visible: channels.length > 0
    radius: 10
    color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    border.width: 1
    implicitHeight: channelsCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: channelsCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.2
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "view-list-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.Label {
                text: Loc.t("Channels & Additional Controls (%1)", channelsSec.channels.length)
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.88
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: channelsSec.channels
            delegate: Rectangle {
                required property string modelData

                readonly property var entry: haManager ? haManager.getCatalogEntry(modelData) : null
                readonly property var eObj: haManager ? haManager.getEntity(modelData) : null
                readonly property string domain: entry ? entry.domain : HAHelpers.getDomain(modelData)
                readonly property bool isOn: eObj ? (eObj.state === "on") : false
                readonly property bool isToggleable: ["switch", "light", "fan", "input_boolean", "outlet"].indexOf(domain) !== -1
                readonly property bool isActionable: ["button", "input_button", "scene", "script"].indexOf(domain) !== -1

                Layout.fillWidth: true
                radius: 6
                color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
                implicitHeight: channelRow.implicitHeight + Kirigami.Units.smallSpacing * 1.2

                RowLayout {
                    id: channelRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        PlasmaComponents3.Label {
                            text: entry ? entry.name : modelData
                            font.bold: true
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        PlasmaComponents3.Label {
                            text: entry && entry.deviceName.length > 0
                                ? (modelData + "  •  " + entry.deviceName)
                                : modelData
                            font.pointSize: 7
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    PlasmaComponents3.Label {
                        visible: !isToggleable && !isActionable
                        text: eObj ? eObj.state : Loc.t("Unavailable")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                        color: Kirigami.Theme.disabledTextColor
                    }

                    PlasmaComponents3.Switch {
                        visible: isToggleable
                        enabled: eObj ? (eObj.state !== "unavailable") : false
                        checked: isOn
                        onToggled: {
                            if (!haManager || !eObj) return;
                            haManager.callService(domain, checked ? "turn_on" : "turn_off", modelData, {});
                        }
                    }

                    PlasmaComponents3.Button {
                        visible: isActionable
                        text: Loc.t("Run")
                        icon.name: "media-playback-start-symbolic"
                        enabled: eObj ? (eObj.state !== "unavailable") : false
                        onClicked: {
                            if (!haManager) return;
                            if (domain === "scene") haManager.callService("scene", "turn_on", modelData, {});
                            else if (domain === "script") haManager.callService("script", "turn_on", modelData, {});
                            else if (domain === "button" || domain === "input_button") haManager.callService(domain, "press", modelData, {});
                        }
                    }
                }
            }
        }
    }
}
