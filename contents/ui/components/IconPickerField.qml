pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs as QtDialogs
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

// Form field for the tray/panel icon: follow the connection status, pick an
// icon from the system theme, or point at an own picture.
RowLayout {
    id: iconField

    // "auto" | "theme" | "custom"
    property string mode: "auto"
    property string iconName: ""
    property string iconPath: ""
    // Icon used by the "auto" mode, mirroring the real tray behaviour.
    property string autoIconName: "network-server-symbolic"
    property string autoOfflineIconName: "network-offline"
    property bool connected: true
    signal iconChanged()

    readonly property var resolved: HAHelpers.resolveIconChoice(mode, iconName, iconPath,
        autoIconName, autoOfflineIconName, connected)

    readonly property string previewUrl: {
        var path = resolved.path;
        if (path.length === 0) return "";
        return path.indexOf("file:") === 0 ? path : "file://" + path;
    }

    readonly property string modeLabel: {
        if (mode === "theme" && iconName) return iconName;
        if (mode === "custom" && iconPath) {
            var parts = iconPath.split("/");
            return parts[parts.length - 1];
        }
        return Loc.t("Automatic (connection status)");
    }

    function chooseThemeIcon(name) {
        iconField.mode = "theme";
        iconField.iconName = name;
        iconField.iconPath = "";
        iconField.iconChanged();
    }

    function chooseAuto() {
        iconField.mode = "auto";
        iconField.iconName = "";
        iconField.iconPath = "";
        iconField.iconChanged();
    }

    spacing: Kirigami.Units.smallSpacing

    Item {
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium

        Kirigami.Icon {
            anchors.fill: parent
            visible: iconField.resolved.path.length === 0
            source: iconField.resolved.name
        }

        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: iconField.previewUrl
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            text: iconField.modeLabel
            font.bold: iconField.mode !== "auto"
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            visible: iconField.mode === "custom"
            text: iconField.iconPath
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
    }

    PlasmaComponents3.ToolButton {
        icon.name: "view-refresh-symbolic"
        visible: iconField.mode !== "auto"
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: Loc.t("Automatic (connection status)")
        onClicked: iconField.chooseAuto()
    }

    PlasmaComponents3.Button {
        text: Loc.t("Select…")
        onClicked: iconPopup.open()
    }

    QtDialogs.FileDialog {
        id: imageDialog
        nameFilters: [Loc.t("Images (*.png *.jpg *.jpeg *.svg *.ico *.webp)"), Loc.t("All files (*)")]
        onAccepted: {
            var file = imageDialog.selectedFile.toString();
            // The image is read on every start, so store the plain path.
            iconField.iconPath = file.replace(/^file:\/\//, "");
            iconField.mode = "custom";
            iconField.iconName = "";
            iconField.iconChanged();
        }
    }

    Controls.Popup {
        id: iconPopup
        parent: Controls.Overlay.overlay
        anchors.centerIn: Controls.Overlay.overlay
        width: Kirigami.Units.gridUnit * 22
        height: Kirigami.Units.gridUnit * 20
        modal: true
        padding: Kirigami.Units.smallSpacing

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: Loc.t("Select an icon")
                    font.bold: true
                    Layout.fillWidth: true
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "dialog-close-symbolic"
                    onClicked: iconPopup.close()
                }
            }

            GridView {
                id: iconGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Kirigami.Units.gridUnit * 3
                cellHeight: Kirigami.Units.gridUnit * 3
                boundsBehavior: Flickable.StopAtBounds
                model: HAHelpers.TRAY_ICON_CHOICES

                PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                    active: true
                }

                delegate: PlasmaComponents3.Button {
                    id: iconCell
                    required property string modelData
                    required property int index
                    width: iconGrid.cellWidth
                    height: iconGrid.cellHeight
                    checkable: true
                    checked: iconField.mode === "theme" && iconField.iconName === modelData
                    flat: !checked
                    display: Controls.AbstractButton.IconOnly
                    icon.name: modelData
                    Accessible.name: modelData
                    onClicked: {
                        iconField.chooseThemeIcon(modelData);
                        iconPopup.close();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Button {
                    icon.name: "document-open-symbolic"
                    text: Loc.t("Custom image…")
                    onClicked: {
                        iconPopup.close();
                        imageDialog.open();
                    }
                }

                PlasmaComponents3.Button {
                    icon.name: "view-refresh-symbolic"
                    text: Loc.t("Automatic (connection status)")
                    onClicked: {
                        iconField.chooseAuto();
                        iconPopup.close();
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
