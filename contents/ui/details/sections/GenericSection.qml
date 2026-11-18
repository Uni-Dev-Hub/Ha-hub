import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../code/ha_helpers.js" as HAHelpers

Rectangle {
    id: genSec
    required property var detailsPage

    readonly property var entityObj: detailsPage.primaryEntityObj
    readonly property var attributes: entityObj && entityObj.attributes ? entityObj.attributes : ({})
    readonly property string domain: detailsPage.primaryDomain
    readonly property string entityId: detailsPage.cleanId

    readonly property bool isActionable: ["script", "scene", "automation", "button", "input_button", "update"].indexOf(domain) !== -1
    readonly property var visibleAttributes: {
        var result = [];
        var keys = Object.keys(genSec.attributes || {});
        var ignored = ["friendly_name", "icon", "supported_features", "editable", "options", "device_class", "unit_of_measurement", "state_class"];
        for (var i = 0; i < keys.length && result.length < 8; i++) {
            var key = keys[i];
            if (ignored.indexOf(key) !== -1) continue;
            var value = genSec.attributes[key];
            if (value === null || value === undefined) continue;
            if (typeof value === "object") {
                try { value = JSON.stringify(value); } catch (e) { value = String(value); }
            }
            result.push({ key: key, value: String(value) });
        }
        return result;
    }

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: genericCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    function runAction() {
        if (!genSec.detailsPage.haManager || !genSec.entityId) return;
        var manager = genSec.detailsPage.haManager;
        if (domain === "scene") manager.callService("scene", "turn_on", entityId, {});
        else if (domain === "script") manager.callService("script", "turn_on", entityId, {});
        else if (domain === "automation") manager.callService("automation", "trigger", entityId, {});
        else if (domain === "button" || domain === "input_button") manager.callService(domain, "press", entityId, {});
        else if (domain === "update") manager.callService("update", "install", entityId, {});
    }

    ColumnLayout {
        id: genericCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("CURRENT STATE")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                text: genSec.domain
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                color: Kirigami.Theme.disabledTextColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: {
                    if (!genSec.entityObj) return i18n("Unavailable");
                    var st = genSec.entityObj.state;
                    var u = (genSec.entityObj.attributes && genSec.entityObj.attributes.unit_of_measurement)
                        ? (" " + genSec.entityObj.attributes.unit_of_measurement) : "";
                    return st + u;
                }
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.5
                color: Kirigami.Theme.textColor
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                visible: genSec.isActionable
                text: genSec.domain === "update" ? i18n("Install") : i18n("Run")
                icon.name: genSec.domain === "update" ? "system-software-update" : "media-playback-start-symbolic"
                onClicked: genSec.runAction()
            }
        }

        PlasmaComponents3.Label {
            visible: genSec.entityId.length > 0
            text: genSec.entityId
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            visible: genSec.visibleAttributes.length > 0
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: genSec.visibleAttributes.length > 0
            Layout.fillWidth: true
            spacing: 2

            PlasmaComponents3.Label {
                text: i18n("ATTRIBUTES")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.72
                color: Kirigami.Theme.disabledTextColor
            }

            Repeater {
                model: genSec.visibleAttributes
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        text: modelData.key
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.Label {
                        text: modelData.value
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.maximumWidth: Math.round(genSec.width * 0.6)
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
