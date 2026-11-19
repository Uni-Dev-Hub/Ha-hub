pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

// Form field that stores a single entity id. Shows the friendly name plus the
// raw id, opens a searchable picker (same filter strip as the big lists) and
// can be cleared. Used by the appearance settings.
RowLayout {
    id: pickerField

    property var haManager: null
    property string value: ""
    // Restrict the list to these domains; empty means every selectable entity.
    property var domainFilter: []
    property string emptyText: Loc.t("Not selected")
    // Fires when the user picked or cleared an entity.
    signal entityPicked(string entityId)

    readonly property string revision: haManager ? haManager.entitiesRevision : 0

    readonly property string displayTitle: {
        var rev = pickerField.revision;
        if (!pickerField.value) return pickerField.emptyText;
        var entry = pickerField.haManager && pickerField.haManager.getCatalogEntry
            ? pickerField.haManager.getCatalogEntry(pickerField.value) : null;
        if (entry && entry.name) return entry.name;
        var ent = pickerField.haManager ? pickerField.haManager.getEntity(pickerField.value) : null;
        var reg = pickerField.haManager ? pickerField.haManager.getEntityRegistry(pickerField.value) : null;
        return HAHelpers.getEntityTitle(pickerField.value, ent, reg, pickerField.haManager);
    }

    readonly property bool isSet: pickerField.value.length > 0

    readonly property var candidates: {
        var rev = pickerField.revision;
        var manager = pickerField.haManager;
        if (!manager || !manager.isConnected) return [];
        var source = manager.userDevicesList || [];
        var result = [];
        for (var i = 0; i < source.length; i++) {
            var domain = HAHelpers.getDomain(source[i]);
            if (pickerField.domainFilter.length > 0 && pickerField.domainFilter.indexOf(domain) === -1) continue;
            result.push(source[i]);
        }
        return result;
    }

    readonly property var domainCounts: {
        var rev = pickerField.revision;
        var source = pickerField.candidates || [];
        var counts = {};
        for (var i = 0; i < source.length; i++) {
            var domain = HAHelpers.getDomain(source[i]);
            if (!domain) continue;
            counts[domain] = (counts[domain] || 0) + 1;
        }
        return counts;
    }

    readonly property var areaOptions: {
        var rev = pickerField.revision;
        var areas = (pickerField.haManager && pickerField.haManager.areasList) ? pickerField.haManager.areasList : [];
        var result = [];
        for (var i = 0; i < areas.length; i++) {
            var id = areas[i].area_id || areas[i].id || "";
            if (!id) continue;
            result.push({ id: id, name: areas[i].name || id });
        }
        result.sort(function(a, b) { return a.name.localeCompare(b.name); });
        return result;
    }

    function titleFor(entityId) {
        var manager = pickerField.haManager;
        if (!manager) return entityId;
        var entry = manager.getCatalogEntry ? manager.getCatalogEntry(entityId) : null;
        if (entry && entry.name) return entry.name;
        return HAHelpers.getEntityTitle(entityId, manager.getEntity(entityId),
            manager.getEntityRegistry ? manager.getEntityRegistry(entityId) : null, manager);
    }

    spacing: Kirigami.Units.smallSpacing

    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            text: pickerField.displayTitle
            font.bold: pickerField.isSet
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            visible: pickerField.isSet
            text: pickerField.value
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    PlasmaComponents3.ToolButton {
        icon.name: "edit-clear-symbolic"
        visible: pickerField.isSet
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.text: Loc.t("Clear")
        onClicked: {
            pickerField.value = "";
            pickerField.entityPicked("");
        }
    }

    PlasmaComponents3.Button {
        id: openButton
        icon.name: "search"
        text: Loc.t("Select…")
        enabled: pickerField.haManager && pickerField.haManager.isConnected
        onClicked: pickerPopup.open()
    }

    Controls.Popup {
        id: pickerPopup
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Kirigami.Units.gridUnit * 26
        height: Kirigami.Units.gridUnit * 22
        modal: true
        padding: Kirigami.Units.smallSpacing

        ColumnLayout {
            id: popupContent
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: Loc.t("Select an entity")
                    font.bold: true
                    Layout.fillWidth: true
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "dialog-close-symbolic"
                    onClicked: pickerPopup.close()
                }
            }

            EntityFilterBar {
                id: popupFilter
                Layout.fillWidth: true
                domainCounts: pickerField.domainCounts
                areaOptions: pickerField.areaOptions
            }

            PlasmaComponents3.Label {
                visible: !(pickerField.haManager && pickerField.haManager.isConnected)
                text: Loc.t("Connect to Home Assistant first.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 1
                model: {
                    var query = (popupFilter.searchText || "").toLowerCase().trim();
                    var domain = popupFilter.selectedDomain;
                    var area = popupFilter.selectedArea;
                    var manager = pickerField.haManager;
                    var result = [];
                    if (!manager || !manager.isConnected) return result;
                    var list = pickerField.candidates || [];
                    for (var i = 0; i < list.length; i++) {
                        var id = list[i];
                        var entry = manager.getCatalogEntry ? manager.getCatalogEntry(id) : null;
                        if (domain !== "all" && HAHelpers.getDomain(id) !== domain) continue;
                        if (area !== "all" && (!entry || (entry.areaId || "") !== area)) continue;
                        if (query.length > 0) {
                            var haystack = [entry && entry.name ? entry.name : "", id,
                                entry && entry.areaName ? entry.areaName : "",
                                entry && entry.deviceName ? entry.deviceName : ""].join(" ").toLowerCase();
                            if (haystack.indexOf(query) === -1) continue;
                        }
                        result.push(id);
                    }
                    return result;
                }

                PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                    active: true
                }

                delegate: PlasmaComponents3.ItemDelegate {
                    id: pickerDelegate
                    required property string modelData
                    width: ListView.view ? ListView.view.width : 0
                    onClicked: {
                        pickerField.value = modelData;
                        pickerField.entityPicked(modelData);
                        pickerPopup.close();
                    }

                    contentItem: ColumnLayout {
                        spacing: 0

                        PlasmaComponents3.Label {
                            text: pickerField.titleFor(pickerDelegate.modelData)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        PlasmaComponents3.Label {
                            text: pickerDelegate.modelData
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
