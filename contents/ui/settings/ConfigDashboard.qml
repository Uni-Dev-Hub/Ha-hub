pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../services" as Services
import "../components" as Components
import "../views" as Views
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../code/dashboard_model.mjs" as DashboardModel
import "../../l10n"

Kirigami.ScrollablePage {
    id: dashboardSettings
    title: Loc.t("Dashboard")
    topPadding: Kirigami.Units.smallSpacing

    property string cfg_host: ""
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property string cfg_dashboardGroups: ""
    property string cfg_dashboardCards: "[]"
    property int cfg_dashboardColumns: 4
    property string cfg_dashboardTileContent: "both"

    // Group the entity picker adds to; falls back to the first group.
    property string activeGroupId: ""
    // Group currently being recoloured by the palette popup.
    property string colorTargetId: ""

    // The effective model: saved groups, or the legacy card list migrated
    // into one untitled group. The first edit stores the full JSON, which
    // materialises that migration.
    readonly property var groups: DashboardModel.normalizeDashboardModel(
        dashboardSettings.cfg_dashboardGroups, dashboardSettings.cfg_dashboardCards)

    readonly property var groupOptions: {
        var result = [];
        for (var i = 0; i < groups.length; i++) {
            result.push({
                id: groups[i].id,
                label: groups[i].name && groups[i].name.length > 0
                    ? groups[i].name : Loc.t("Ungrouped")
            });
        }
        return result;
    }

    readonly property string pickerTargetId: {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].id === dashboardSettings.activeGroupId) return groups[i].id;
        }
        return groups.length > 0 ? groups[0].id : "";
    }

    // Reference for inline Components where the inner object shadows the
    // haManager id with a property of the same name.
    readonly property var managerRef: haManager

    Services.HAManager {
        id: haManager
        host: dashboardSettings.cfg_host
        port: parseInt(dashboardSettings.cfg_port) || 8123
        useSsl: dashboardSettings.cfg_useSsl
    }

    // The settings dialog builds its pages up front; connecting a full
    // WebSocket + entity catalogue for a page the user never opened made the
    // whole dialog (and the popup beside it) sluggish, so each page connects
    // only once it is actually shown for the first time.
    property bool managerStarted: false

    function maybeStartManager() {
        if (managerStarted) return;
        managerStarted = true;
        // HAManager prefers the shared credential store; startAutoConnect()
        // loads from it and connects when credentials exist.
        haManager.startAutoConnect();
    }

    Component.onCompleted: if (visible) maybeStartManager()
    onVisibleChanged: if (visible) maybeStartManager()

    function saveGroups(next) {
        dashboardSettings.cfg_dashboardGroups = DashboardModel.dumpGroups(next);
    }

    function createGroup() {
        dashboardSettings.saveGroups(DashboardModel.addGroup(dashboardSettings.groups, "", null));
    }

    function deleteGroup(groupId) {
        dashboardSettings.saveGroups(DashboardModel.removeGroup(dashboardSettings.groups, groupId));
    }

    function renameGroupById(groupId, name) {
        dashboardSettings.saveGroups(DashboardModel.renameGroup(dashboardSettings.groups, groupId, name));
    }

    function colorGroup(groupId, color) {
        dashboardSettings.saveGroups(DashboardModel.setGroupColor(dashboardSettings.groups, groupId, color));
    }

    function shiftGroup(groupId, delta) {
        dashboardSettings.saveGroups(DashboardModel.moveGroup(dashboardSettings.groups, groupId, delta));
    }

    // With no groups yet the first added entity creates the first group, so
    // the dashboard never needs a separate "create group" step.
    function addEntity(entityId) {
        if (!entityId) return;
        var base = dashboardSettings.groups;
        if (base.length === 0) base = DashboardModel.addGroup(base, "", null);
        var target = dashboardSettings.pickerTargetId;
        if (!DashboardModel.findGroup(base, target)) target = base[0].id;
        dashboardSettings.saveGroups(DashboardModel.addTile(base, target, entityId, "medium"));
    }

    function removeTileFrom(groupId, entityId) {
        dashboardSettings.saveGroups(DashboardModel.removeTile(dashboardSettings.groups, groupId, entityId));
    }

    function sizeTile(groupId, entityId, size) {
        dashboardSettings.saveGroups(DashboardModel.setTileSize(dashboardSettings.groups, groupId, entityId, size));
    }

    function contentTile(groupId, entityId, content) {
        dashboardSettings.saveGroups(DashboardModel.setTileContent(dashboardSettings.groups, groupId, entityId, content));
    }

    function moveTileTo(entityId, toGroupId) {
        if (!toGroupId || toGroupId === DashboardModel.groupOf(dashboardSettings.groups, entityId)) return;
        dashboardSettings.saveGroups(DashboardModel.moveTile(dashboardSettings.groups, entityId, toGroupId));
    }

    function groupLabel(groupId) {
        var group = DashboardModel.findGroup(dashboardSettings.groups, groupId);
        if (!group) return Loc.t("Ungrouped");
        return group.name && group.name.length > 0 ? group.name : Loc.t("Ungrouped");
    }

    readonly property var existingTileSet: {
        var ids = DashboardModel.allTileEntityIds(groups);
        var result = {};
        for (var i = 0; i < ids.length; i++) result[ids[i]] = true;
        return result;
    }

    function entityTitle(entityId) {
        if (!haManager) return entityId || "";
        var entry = haManager.getCatalogEntry ? haManager.getCatalogEntry(entityId) : null;
        if (entry && entry.name) return entry.name;
        var ent = haManager.getEntity(entityId);
        var reg = haManager.getEntityRegistry ? haManager.getEntityRegistry(entityId) : null;
        return HAHelpers.getEntityTitle(entityId, ent, reg, haManager);
    }

    function entitySubtitle(entityId) {
        if (!haManager) return entityId || "";
        var entry = haManager.getCatalogEntry ? haManager.getCatalogEntry(entityId) : null;
        if (entry && entry.deviceName) {
            return entityId + "  •  " + entry.deviceName;
        }
        return entityId;
    }

    // Candidates for the picker: everything selectable that is not a tile yet.
    readonly property var candidateEntities: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        if (!haManager || !haManager.isConnected) return [];
        var source = haManager.userDevicesList || [];
        var result = [];
        for (var i = 0; i < source.length; i++) {
            if (!dashboardSettings.existingTileSet[source[i]]) result.push(source[i]);
        }
        return result;
    }

    readonly property var domainCounts: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        // Counts come from every selectable entity in Home Assistant, so a
        // domain never disappears from the filter just because all of its
        // entities already sit on the dashboard.
        var source = (haManager && haManager.isConnected) ? (haManager.userDevicesList || []) : [];
        var counts = {};
        for (var i = 0; i < source.length; i++) {
            var domain = HAHelpers.getDomain(source[i]);
            if (!domain) continue;
            counts[domain] = (counts[domain] || 0) + 1;
        }
        return counts;
    }

    readonly property var areaOptions: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        var areas = (haManager && haManager.areasList) ? haManager.areasList : [];
        var result = [];
        for (var i = 0; i < areas.length; i++) {
            var id = areas[i].area_id || areas[i].id || "";
            if (!id) continue;
            result.push({ id: id, name: areas[i].name || id });
        }
        result.sort(function(a, b) { return a.name.localeCompare(b.name); });
        return result;
    }

    readonly property var availableEntities: {
        if (!haManager || !haManager.isConnected) return [];
        var list = dashboardSettings.candidateEntities || [];
        // Read picker filters as properties so this binding re-evaluates.
        var query = (pickerFilter.searchText || "").toLowerCase().trim();
        var domain = pickerFilter.selectedDomain;
        var area = pickerFilter.selectedArea;

        var result = [];
        for (var i = 0; i < list.length; i++) {
            var id = list[i];
            var entry = haManager.getCatalogEntry ? haManager.getCatalogEntry(id) : null;
            if (!entry) continue;
            if (domain !== "all" && entry.domain !== domain) continue;
            if (area !== "all" && (entry.areaId || "") !== area) continue;
            if (query.length > 0) {
                var haystack = [entry.name || "", id, entry.areaName || "", entry.deviceName || ""].join(" ").toLowerCase();
                if (haystack.indexOf(query) === -1) continue;
            }
            result.push(id);
        }
        return result;
    }

    readonly property int totalTiles: DashboardModel.countTiles(groups)

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        width: parent.width

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Controls.ComboBox {
                id: columnsCombo
                Kirigami.FormData.label: Loc.t("Grid columns:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                model: [2, 3, 4, 6]
                currentIndex: Math.max(0, model.indexOf(dashboardSettings.cfg_dashboardColumns))
                onActivated: dashboardSettings.cfg_dashboardColumns = currentText
            }

            Controls.ComboBox {
                id: contentCombo
                Kirigami.FormData.label: Loc.t("Tile content:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                readonly property var contentOptions: [
                    { value: "both", label: Loc.t("Name and icon") },
                    { value: "title", label: Loc.t("Name only") },
                    { value: "icon", label: Loc.t("Icon only") }
                ]
                model: contentOptions
                textRole: "label"
                currentIndex: {
                    for (var i = 0; i < contentOptions.length; i++) {
                        if (contentOptions[i].value === dashboardSettings.cfg_dashboardTileContent) return i;
                    }
                    return 0;
                }
                onActivated: dashboardSettings.cfg_dashboardTileContent = contentOptions[currentIndex].value
            }
        }

        // ---- Groups ----------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: Loc.t("Dashboard Groups")
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.1
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: Loc.t("%1 tiles", dashboardSettings.totalTiles)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                    color: Kirigami.Theme.disabledTextColor
                }
                PlasmaComponents3.Button {
                    icon.name: "list-add-symbolic"
                    text: Loc.t("Add group")
                    onClicked: dashboardSettings.createGroup()
                }
            }

            PlasmaComponents3.Label {
                visible: dashboardSettings.groups.length === 0
                text: Loc.t("No groups yet. The first entity you add below creates one.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                model: dashboardSettings.groups

                delegate: ColumnLayout {
                    id: groupSection
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 0.6

                    // Group header: colour swatch, name field, reorder, delete.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: groupHeader.implicitHeight + Kirigami.Units.smallSpacing * 1.2
                        radius: 8
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.04)
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                        border.width: 1

                        RowLayout {
                            id: groupHeader
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            // Colour chip; click to open the palette popup.
                            Rectangle {
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: implicitWidth
                                radius: Kirigami.Units.smallSpacing
                                color: groupSection.modelData.color
                                    ? groupSection.modelData.color
                                    : Kirigami.Theme.highlightColor
                                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.3)
                                border.width: 1

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dashboardSettings.colorTargetId = groupSection.modelData.id;
                                        colorPopup.open();
                                    }
                                }
                                PlasmaComponents3.ToolTip.visible: chipMouse.containsMouse
                                PlasmaComponents3.ToolTip.text: Loc.t("Group color:")
                            }

                            PlasmaComponents3.TextField {
                                id: nameField
                                Layout.fillWidth: true
                                placeholderText: Loc.t("Group name")
                                text: groupSection.modelData.name || ""
                                onEditingFinished: dashboardSettings.renameGroupById(
                                    groupSection.modelData.id, text)
                            }

                            PlasmaComponents3.ToolButton {
                                icon.name: "arrow-up-symbolic"
                                PlasmaComponents3.ToolTip.visible: hovered
                                PlasmaComponents3.ToolTip.text: Loc.t("Move up")
                                enabled: groupSection.index > 0
                                onClicked: dashboardSettings.shiftGroup(groupSection.modelData.id, -1)
                            }

                            PlasmaComponents3.ToolButton {
                                icon.name: "arrow-down-symbolic"
                                PlasmaComponents3.ToolTip.visible: hovered
                                PlasmaComponents3.ToolTip.text: Loc.t("Move down")
                                enabled: groupSection.index < dashboardSettings.groups.length - 1
                                onClicked: dashboardSettings.shiftGroup(groupSection.modelData.id, 1)
                            }

                            PlasmaComponents3.ToolButton {
                                icon.name: "delete"
                                PlasmaComponents3.ToolTip.visible: hovered
                                PlasmaComponents3.ToolTip.text: Loc.t("Delete group")
                                onClicked: dashboardSettings.deleteGroup(groupSection.modelData.id)
                            }
                        }
                    }

                    // Tiles of this group.
                    Repeater {
                        model: groupSection.modelData.tiles

                        delegate: Rectangle {
                            id: tileRowDelegate
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: tileRow.implicitHeight + Kirigami.Units.smallSpacing * 1.2
                            radius: 8
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.02)
                            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                            border.width: 1

                            RowLayout {
                                id: tileRow
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                anchors.leftMargin: Kirigami.Units.largeSpacing
                                spacing: Kirigami.Units.smallSpacing

                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true

                                    PlasmaComponents3.Label {
                                        text: dashboardSettings.entityTitle(tileRowDelegate.modelData.entityId)
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    PlasmaComponents3.Label {
                                        text: tileRowDelegate.modelData.entityId || ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                                        color: Kirigami.Theme.disabledTextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Controls.ComboBox {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                                    readonly property var sizeOptions: [
                                        { value: "small", label: Loc.t("Small") },
                                        { value: "medium", label: Loc.t("Medium") },
                                        { value: "wide", label: Loc.t("Wide") },
                                        { value: "large", label: Loc.t("Large") }
                                    ]
                                    model: sizeOptions
                                    textRole: "label"
                                    currentIndex: {
                                        for (var i = 0; i < sizeOptions.length; i++) {
                                            if (sizeOptions[i].value === tileRowDelegate.modelData.size) return i;
                                        }
                                        return 1;
                                    }
                                    PlasmaComponents3.ToolTip.visible: hovered
                                    PlasmaComponents3.ToolTip.text: Loc.t("Tile size")
                                    onActivated: dashboardSettings.sizeTile(
                                        groupSection.modelData.id, tileRowDelegate.modelData.entityId,
                                        sizeOptions[currentIndex].value)
                                }

                                Controls.ComboBox {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                                    readonly property var contentOptions: [
                                        { value: "", label: Loc.t("Default") },
                                        { value: "both", label: Loc.t("Name and icon") },
                                        { value: "title", label: Loc.t("Name only") },
                                        { value: "icon", label: Loc.t("Icon only") }
                                    ]
                                    model: contentOptions
                                    textRole: "label"
                                    currentIndex: {
                                        for (var i = 0; i < contentOptions.length; i++) {
                                            if (contentOptions[i].value === (tileRowDelegate.modelData.content || "")) return i;
                                        }
                                        return 0;
                                    }
                                    PlasmaComponents3.ToolTip.visible: hovered
                                    PlasmaComponents3.ToolTip.text: Loc.t("Tile content")
                                    onActivated: dashboardSettings.contentTile(
                                        groupSection.modelData.id, tileRowDelegate.modelData.entityId,
                                        contentOptions[currentIndex].value)
                                }

                                Controls.ComboBox {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                                    model: dashboardSettings.groupOptions
                                    textRole: "label"
                                    currentIndex: {
                                        var here = DashboardModel.groupOf(
                                            dashboardSettings.groups, tileRowDelegate.modelData.entityId);
                                        for (var i = 0; i < dashboardSettings.groupOptions.length; i++) {
                                            if (dashboardSettings.groupOptions[i].id === here) return i;
                                        }
                                        return 0;
                                    }
                                    PlasmaComponents3.ToolTip.visible: hovered
                                    PlasmaComponents3.ToolTip.text: Loc.t("Move to another group")
                                    onActivated: dashboardSettings.moveTileTo(
                                        tileRowDelegate.modelData.entityId,
                                        dashboardSettings.groupOptions[currentIndex].id)
                                }

                                PlasmaComponents3.ToolButton {
                                    icon.name: "delete"
                                    onClicked: dashboardSettings.removeTileFrom(
                                        groupSection.modelData.id, tileRowDelegate.modelData.entityId)
                                }
                            }
                        }
                    }

                    PlasmaComponents3.Label {
                        visible: groupSection.modelData.tiles.length === 0
                        text: Loc.t("No tiles in this group yet. Add an entity below.")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: Kirigami.Theme.disabledTextColor
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                    }
                }
            }
        }

        // ---- Live layout preview -------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: dashboardSettings.groups.length > 0

            PlasmaComponents3.Label {
                text: Loc.t("Layout Preview")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.05
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: Loc.t("This is how the dashboard grid will look in the widget popup. Card size changes apply here instantly.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 12
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                border.width: 1
                clip: true

                Kirigami.Icon {
                    anchors.centerIn: parent
                    visible: !(haManager && haManager.isConnected)
                    source: "network-connect-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.large
                    implicitHeight: implicitWidth
                    color: Kirigami.Theme.disabledTextColor
                }

                Loader {
                    id: previewLoader
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    active: haManager && haManager.isConnected && dashboardSettings.groups.length > 0
                    sourceComponent: Component {
                        Views.DashboardView {
                            haManager: dashboardSettings.managerRef
                            groupsJson: dashboardSettings.cfg_dashboardGroups
                            legacyCardsJson: dashboardSettings.cfg_dashboardCards
                            columns: dashboardSettings.cfg_dashboardColumns
                            tileContent: dashboardSettings.cfg_dashboardTileContent
                            // Preview clicks should not try to navigate.
                            onConfigureRequested: {}
                            onOpenDetailsRequested: function(entId) {}
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ---- Picker ----------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: Loc.t("Add Entity to Dashboard")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.05
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                visible: dashboardSettings.groups.length > 0

                PlasmaComponents3.Label {
                    text: Loc.t("Add to group:")
                }

                Controls.ComboBox {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    Layout.fillWidth: true
                    model: dashboardSettings.groupOptions
                    textRole: "label"
                    currentIndex: {
                        for (var i = 0; i < dashboardSettings.groupOptions.length; i++) {
                            if (dashboardSettings.groupOptions[i].id === dashboardSettings.pickerTargetId) return i;
                        }
                        return 0;
                    }
                    onActivated: {
                        var option = dashboardSettings.groupOptions[currentIndex];
                        dashboardSettings.activeGroupId = option ? option.id : "";
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Components.EntityFilterBar {
                id: pickerFilter
                Layout.fillWidth: true
                domainCounts: dashboardSettings.domainCounts
                areaOptions: dashboardSettings.areaOptions
            }

            PlasmaComponents3.Label {
                visible: haManager && !haManager.isConnected
                text: haManager ? haManager.connectionStatus : Loc.t("Connecting…")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 9
                clip: true
                spacing: 1
                model: dashboardSettings.availableEntities

                PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                    active: true
                }

                delegate: PlasmaComponents3.ItemDelegate {
                    id: pickerDelegate
                    required property string modelData
                    width: ListView.view ? ListView.view.width : 0
                    onClicked: dashboardSettings.addEntity(modelData)

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "list-add-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                            color: Kirigami.Theme.highlightColor
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            PlasmaComponents3.Label {
                                text: dashboardSettings.entityTitle(pickerDelegate.modelData)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            PlasmaComponents3.Label {
                                text: dashboardSettings.entitySubtitle(pickerDelegate.modelData)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            PlasmaComponents3.Label {
                visible: haManager && haManager.isConnected && dashboardSettings.availableEntities.length === 0
                text: Loc.t("No matching entities. Try another search or clear the filters.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    // ---- Colour palette popup ------------------------------------------------
    Controls.Popup {
        id: colorPopup
        parent: Controls.Overlay.overlay
        anchors.centerIn: Controls.Overlay.overlay
        width: Kirigami.Units.gridUnit * 16
        modal: true
        padding: Kirigami.Units.smallSpacing

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: Loc.t("Group color:")
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 5

                Repeater {
                    model: DashboardModel.METRO_COLORS.length + 1

                    delegate: Rectangle {
                        id: swatch
                        required property int index

                        readonly property string swatchColor: index === 0
                            ? "" : DashboardModel.METRO_COLORS[index - 1]

                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        radius: Kirigami.Units.smallSpacing
                        color: swatchColor.length > 0 ? swatchColor : Kirigami.Theme.highlightColor
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.3)
                        border.width: 1

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            visible: swatch.swatchColor.length === 0
                            text: "A"
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dashboardSettings.colorGroup(dashboardSettings.colorTargetId, swatch.swatchColor);
                                colorPopup.close();
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.TextField {
                    id: hexField
                    Layout.fillWidth: true
                    placeholderText: "#rrggbb"
                    onAccepted: applyHex()

                    function applyHex() {
                        if (!DashboardModel.isValidHex(hexField.text)) return;
                        dashboardSettings.colorGroup(dashboardSettings.colorTargetId, hexField.text);
                        colorPopup.close();
                    }
                }

                PlasmaComponents3.Button {
                    text: Loc.t("Apply")
                    enabled: DashboardModel.isValidHex(hexField.text)
                    onClicked: hexField.applyHex()
                }
            }
        }
    }
}
