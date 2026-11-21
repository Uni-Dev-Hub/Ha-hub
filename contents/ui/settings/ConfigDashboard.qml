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
    // The page's own heading. Plasma assigns a title of its own when it opens a
    // page - the category name it read *before* this page's bridge had set the
    // language, from a copy made while the dialog was still in the system
    // language - and an assignment breaks the binding, so the heading of the
    // first page opened kept that language. Re-asserting it here, and whenever
    // the language moves, puts the right one back.
    readonly property string pageTitle: Loc.t("Dashboard")
    title: pageTitle
    onPageTitleChanged: dashboardSettings.title = dashboardSettings.pageTitle
    topPadding: Kirigami.Units.smallSpacing

    // This dialog has its own Loc instance: without the bridge every page here
    // would stay in the system language no matter what is configured.
    Components.LanguageBridge {
        // Handed over where Plasma lets a settings page see the configuration
        // at all; a page normally cannot, and then the language is saved the
        // Plasma way - through the cfg_ property and Apply.
        configuration: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
            ? Plasmoid.configuration : null
    }

    property string cfg_host: ""
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property string cfg_dashboardGroups: ""
    property string cfg_dashboardCards: "[]"
    property int cfg_dashboardColumns: 4
    property string cfg_dashboardFontFamily: ""
    property real cfg_dashboardFontSize: 0
    property string cfg_dashboardTileContent: "both"
    // Names the user gave entities, as a JSON map. Its own key, not a field on
    // a tile: a name belongs to the entity, so it holds across groups, survives
    // an entity leaving the dashboard, and renames the same entity in the
    // device list and the pickers too.
    property string cfg_entityAliases: "{}"

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
        // The saved names as this page holds them, so the preview below retitles
        // while the user types, before Apply has run.
        entityAliases: dashboardSettings.cfg_entityAliases
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

    Component.onCompleted: {
        if (visible) maybeStartManager()
        dashboardSettings.title = dashboardSettings.pageTitle
    }
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

    // The names the user typed live in this page's own value: while the dialog
    // is open the manager still holds the saved map, and a rename has to be
    // visible on this page before Apply.
    readonly property var aliasMap: HAHelpers.parseAliases(dashboardSettings.cfg_entityAliases)
    // The row whose name is being edited; "" while none is.
    property string renamingEntity: ""

    function entityAlias(entityId) {
        return HAHelpers.aliasFor(dashboardSettings.aliasMap, entityId);
    }

    // An empty name removes the entry, which is how a rename is taken back.
    function setEntityName(entityId, name) {
        dashboardSettings.cfg_entityAliases = JSON.stringify(
            HAHelpers.setAlias(dashboardSettings.cfg_entityAliases, entityId, name));
    }

    function entityTitle(entityId) {
        var alias = dashboardSettings.entityAlias(entityId);
        if (alias) return alias;
        return dashboardSettings.entityHaName(entityId);
    }

    // The rows the editor shows: the saved model with each tile's name already
    // worked out. A row then reads its own data instead of calling back into the
    // page - a row that asked the page for a name kept showing the old one after
    // a rename, because its binding had no reason to look again.
    readonly property var groupRows: {
        var names = dashboardSettings.aliasMap;      // recomputes when a name changes
        var rows = [];
        for (var g = 0; g < dashboardSettings.groups.length; g++) {
            var group = dashboardSettings.groups[g];
            var tiles = [];
            for (var t = 0; t < (group.tiles || []).length; t++) {
                var tile = group.tiles[t];
                var alias = HAHelpers.aliasFor(names, tile.entityId);
                var haName = dashboardSettings.entityHaName(tile.entityId);
                tiles.push({
                    entityId: tile.entityId,
                    size: tile.size,
                    content: tile.content,
                    alias: alias,
                    haName: haName,
                    name: alias || haName,
                    // One line, always there, whatever the row is called: what
                    // Home Assistant calls the entity and its id. Made here
                    // rather than in the row, so every row of the list is the
                    // same height - a line that appears only on a renamed row
                    // made that row taller and left its controls off-centre.
                    subtitle: HAHelpers.entityRowSubtitle(haName, tile.entityId),
                    // Worked out once here so the row that offers to take a
                    // name back reads a fact about itself instead of
                    // computing one through the page.
                    hasAlias: alias.length > 0
                });
            }
            rows.push({ id: group.id, name: group.name, color: group.color, tiles: tiles });
        }
        return rows;
    }

    // What Home Assistant calls this entity, with no override in the way: the
    // placeholder in the editor and the tooltip, so an override reads as one.
    function entityHaName(entityId) {
        if (!haManager) return entityId || "";
        var ent = haManager.getEntity(entityId);
        var reg = haManager.getEntityRegistry ? haManager.getEntityRegistry(entityId) : null;
        // Not getEntityTitle(): that one answers with the override, and this
        // line exists to show what the override covers. The catalog entry is
        // out too - its name was resolved through the same path.
        return HAHelpers.entityTitleFromAssistant(entityId, ent, reg, haManager);
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

        // Kirigami gives a form the whole width of the space it is put in and
        // centres the two columns of its content inside that width, so a form as wide
        // as the page shows its labels and fields somewhere in the middle of the
        // window. The box is only as wide as the form asks itself to be and stands on
        // the left, so there is nothing left to centre; in a window narrower than that
        // the form reflows into one column and the box follows it down.
        Item {
            Layout.preferredWidth: Math.min(dashboardSettings.availableWidth, tilesForm.implicitWidth)
            Layout.preferredHeight: tilesForm.implicitHeight
            Layout.alignment: Qt.AlignLeft

            Kirigami.FormLayout {
                id: tilesForm
                anchors.fill: parent

                Controls.ComboBox {
                    id: columnsCombo
                    objectName: "columnsCombo"
                    Kirigami.FormData.label: Loc.t("Grid columns:")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    // Every count the grid can pack. The layout itself takes any
                    // number, so a value missing here would leave a saved setting
                    // unselectable - and currentIndex below would quietly show the
                    // first entry while the configuration kept the real one.
                    readonly property var counts: [2, 3, 4, 5, 6]
                    model: counts.indexOf(dashboardSettings.cfg_dashboardColumns) !== -1
                        ? counts
                        : counts.concat([dashboardSettings.cfg_dashboardColumns]).sort(function (a, b) { return a - b; })
                    currentIndex: Math.max(0, model.indexOf(dashboardSettings.cfg_dashboardColumns))
                    // The index the signal carries, not currentText: the control
                    // only moves currentIndex on its own picks, and the number the
                    // user chose is what has to end up in the configuration.
                    onActivated: (index) => dashboardSettings.cfg_dashboardColumns = Number(model[index])
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

                Controls.ComboBox {
                    id: fontCombo
                    objectName: "fontFamilyCombo"
                    Kirigami.FormData.label: Loc.t("Font:")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 16

                    // An empty family means the font the theme picked, and it goes
                    // first so the override can be picked back off.
                    readonly property var families: [""].concat(
                        Qt.fontFamilies().sort(function (a, b) { return a.localeCompare(b); }))
                    model: families
                    currentIndex: Math.max(0, families.indexOf(dashboardSettings.cfg_dashboardFontFamily))
                    displayText: currentIndex > 0 ? families[currentIndex] : Loc.t("System (default)")

                    delegate: Controls.ItemDelegate {
                        required property int index
                        width: fontCombo.width
                        text: index > 0 ? fontCombo.families[index] : Loc.t("System (default)")
                        highlighted: fontCombo.highlightedIndex === index
                        onClicked: {
                            fontCombo.currentIndex = index
                            fontCombo.popup.dismiss()
                            dashboardSettings.cfg_dashboardFontFamily = fontCombo.families[index]
                        }
                    }
                    onActivated: (index) => dashboardSettings.cfg_dashboardFontFamily = families[index]
                }

                Controls.SpinBox {
                    id: fontSizeSpin
                    objectName: "fontSizeSpin"
                    Kirigami.FormData.label: Loc.t("Font size:")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    // 0 is not a size: it is "the size a tile is designed at".
                    from: 0
                    to: 24
                    stepSize: 1
                    value: dashboardSettings.cfg_dashboardFontSize
                    textFromValue: function (size) {
                        return size > 0 ? size.toFixed(1) + " pt" : Loc.t("Default");
                    }
                    valueFromText: function (text) {
                        var parsed = parseFloat(text.replace(",", "."));
                        return isNaN(parsed) ? 0 : parsed;
                    }
                    onValueModified: dashboardSettings.cfg_dashboardFontSize = value
                }

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

            // A page of the settings dialog cannot store anything by itself, so
            // say where a rename is kept - the same reason the language hint
            // exists under the picker.
            PlasmaComponents3.Label {
                objectName: "namesHint"
                text: Loc.t("Click an entity name to rename it. Apply keeps the names.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
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
                model: dashboardSettings.groupRows

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
                                PlasmaComponents3.ToolTip.text: Loc.t("Accent color:")
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
                            objectName: "tileRowCard"
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
                                    // Asked for by number, not by the text it
                                    // holds: the list of tiles is read as a table,
                                    // and a block that measured itself to its own
                                    // name - short «Кухня», long «Свет в ванной» -
                                    // moved the three dropdowns beside it to a new
                                    // place in every row. The elided labels below
                                    // take whatever width it is given.
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                                    // And it gives way first, and to a small width:
                                    // the name is cut with an ellipsis before the
                                    // controls of the row are pushed past the edge
                                    // of a window dragged narrow.
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 4

                                    // A click on the name edits it. The name is
                                    // the entity's, not this tile's: it follows
                                    // the entity into every group and into the
                                    // device list, and Apply stores it.
                                    Item {
                                        objectName: "tileNameArea"
                                        Layout.fillWidth: true
                                        implicitHeight: Math.max(nameLabel.implicitHeight,
                                                                 nameEditor.implicitHeight)

                                        PlasmaComponents3.Label {
                                            id: nameLabel
                                            objectName: "tileNameLabel"
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            visible: dashboardSettings.renamingEntity
                                                !== tileRowDelegate.modelData.entityId
                                            text: tileRowDelegate.modelData.name
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: nameMouse
                                            anchors.fill: parent
                                            visible: nameLabel.visible
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: dashboardSettings.renamingEntity =
                                                tileRowDelegate.modelData.entityId
                                            PlasmaComponents3.ToolTip.visible: containsMouse && nameLabel.visible
                                            PlasmaComponents3.ToolTip.text: Loc.t("Click to rename")
                                        }

                                        PlasmaComponents3.TextField {
                                            id: nameEditor
                                            objectName: "tileNameField"
                                            anchors.fill: parent
                                            visible: dashboardSettings.renamingEntity
                                                === tileRowDelegate.modelData.entityId
                                            text: tileRowDelegate.modelData.alias
                                            placeholderText: tileRowDelegate.modelData.haName
                                            focus: visible
                                            selectByMouse: true
                                            // Enter or a click away saves; the
                                            // row is never left in a half-typed
                                            // state.
                                            onEditingFinished: {
                                                dashboardSettings.setEntityName(
                                                    tileRowDelegate.modelData.entityId, text);
                                                dashboardSettings.renamingEntity = "";
                                            }
                                            Keys.onEscapePressed: {
                                                // Hand the typed text back first, so a save
                                                // that still follows the focus change writes
                                                // what was already there.
                                                text = tileRowDelegate.modelData.alias;
                                                dashboardSettings.renamingEntity = "";
                                            }
                                            onVisibleChanged: if (visible) selectAll()
                                        }
                                    }
                                    PlasmaComponents3.Label {
                                        objectName: "tileNameSubtitle"
                                        text: tileRowDelegate.modelData.subtitle || ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                                        color: Kirigami.Theme.disabledTextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Controls.ComboBox {
                                    objectName: "tileSizeCombo"
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8

                                    Layout.fillWidth: true
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                                    readonly property var sizeOptions: [
                                        { value: "small", label: Loc.t("1 column") },
                                        { value: "medium", label: Loc.t("2 columns") },
                                        { value: "wide", label: Loc.t("Full width") }
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
                                    objectName: "tileContentCombo"
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9

                                    Layout.fillWidth: true
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
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
                                    objectName: "tileGroupCombo"
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9

                                    Layout.fillWidth: true
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
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

                                // The place of the reset button is kept on every
                                // row, renamed or not. A row that carries one
                                // control more takes that width from the fields
                                // which fill the row, and the columns of the list
                                // stop lining up under each other.
                                Item {
                                    Layout.preferredWidth: tileNameReset.implicitWidth
                                    Layout.preferredHeight: tileNameReset.implicitHeight

                                    PlasmaComponents3.ToolButton {
                                        id: tileNameReset
                                        objectName: "tileNameReset"
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon.name: "edit-undo-symbolic"
                                        visible: tileRowDelegate.modelData.hasAlias === true
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        PlasmaComponents3.ToolTip.text: Loc.t("Use the Home Assistant name")
                                        onClicked: dashboardSettings.setEntityName(
                                            tileRowDelegate.modelData.entityId, "")
                                    }
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
                            fontFamily: dashboardSettings.cfg_dashboardFontFamily
                            fontSize: dashboardSettings.cfg_dashboardFontSize
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
                text: Loc.t("Accent color:")
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
