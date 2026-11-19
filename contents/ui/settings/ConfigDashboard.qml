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
import "../../l10n"

Kirigami.ScrollablePage {
    id: dashboardSettings
    title: Loc.t("Dashboard")
    topPadding: Kirigami.Units.smallSpacing

    property string cfg_host: ""
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_showDashboard: false
    property string cfg_dashboardCards: "[]"
    property int cfg_dashboardColumns: 2
    property string cfg_dashboardCardSize: "compact"

    readonly property var cards: {
        var raw = dashboardSettings.cfg_dashboardCards ? dashboardSettings.cfg_dashboardCards.trim() : "";
        if (!raw) return [];
        try {
            var parsed = JSON.parse(raw);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
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

    Component.onCompleted: {
        // HAManager prefers the shared credential store; startAutoConnect()
        // loads from it and connects when credentials exist.
        haManager.startAutoConnect();
    }

    readonly property var existingCardSet: {
        var result = {};
        for (var i = 0; i < cards.length; i++) {
            if (cards[i] && cards[i].entityId) result[cards[i].entityId] = true;
        }
        return result;
    }

    function cardExists(entityId) {
        return !!existingCardSet[entityId];
    }

    function saveCards(list) {
        dashboardSettings.cfg_dashboardCards = JSON.stringify(list || []);
    }

    function addCard(entityId) {
        if (!entityId || cardExists(entityId)) return;
        var next = cards.slice();
        next.push({ entityId: entityId, size: "1x1" });
        saveCards(next);
    }

    function removeCard(index) {
        var next = cards.slice();
        if (index < 0 || index >= next.length) return;
        next.splice(index, 1);
        saveCards(next);
    }

    function moveCard(index, delta) {
        var next = cards.slice();
        var target = index + delta;
        if (index < 0 || index >= next.length || target < 0 || target >= next.length) return;
        var item = next.splice(index, 1)[0];
        next.splice(target, 0, item);
        saveCards(next);
    }

    function setCardSize(index, size) {
        var next = cards.slice();
        if (index < 0 || index >= next.length) return;
        next[index] = { entityId: next[index].entityId, size: size };
        saveCards(next);
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

    // Candidates for the picker: everything selectable that is not on the
    // dashboard yet.
    readonly property var candidateEntities: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        if (!haManager || !haManager.isConnected) return [];
        var source = haManager.userDevicesList || [];
        var result = [];
        for (var i = 0; i < source.length; i++) {
            if (!dashboardSettings.existingCardSet[source[i]]) result.push(source[i]);
        }
        return result;
    }

    readonly property var domainCounts: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        var source = dashboardSettings.candidateEntities || [];
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

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        width: parent.width

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Controls.Switch {
                id: showDashboardSwitch
                Kirigami.FormData.label: Loc.t("Widget Tab:")
                text: Loc.t("Show 'Dashboard' tab")
                checked: dashboardSettings.cfg_showDashboard
                onToggled: dashboardSettings.cfg_showDashboard = checked
            }

            Controls.ComboBox {
                id: columnsCombo
                Kirigami.FormData.label: Loc.t("Grid columns:")
                visible: dashboardSettings.cfg_showDashboard
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                model: [2, 3, 4]
                currentIndex: Math.max(0, model.indexOf(dashboardSettings.cfg_dashboardColumns))
                onActivated: dashboardSettings.cfg_dashboardColumns = currentText
            }

            Controls.ComboBox {
                id: cardSizeCombo
                Kirigami.FormData.label: Loc.t("Card size:")
                visible: dashboardSettings.cfg_showDashboard
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                readonly property var sizeOptions: [
                    { value: "compact", label: Loc.t("Compact") },
                    { value: "normal", label: Loc.t("Normal") }
                ]
                model: sizeOptions
                textRole: "label"
                currentIndex: {
                    for (var i = 0; i < sizeOptions.length; i++) {
                        if (sizeOptions[i].value === dashboardSettings.cfg_dashboardCardSize) return i;
                    }
                    return 0;
                }
                onActivated: dashboardSettings.cfg_dashboardCardSize = sizeOptions[currentIndex].value
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: Loc.t("Dashboard Cards")
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.1
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: Loc.t("%1 cards", dashboardSettings.cards.length)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            PlasmaComponents3.Label {
                visible: dashboardSettings.cards.length === 0
                text: Loc.t("No cards yet. Add an entity below.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            Repeater {
                model: dashboardSettings.cards
                delegate: Rectangle {
                    id: cardRowDelegate
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: cardRow.implicitHeight + Kirigami.Units.smallSpacing * 1.2
                    radius: 8
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.04)
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                    border.width: 1

                    RowLayout {
                        id: cardRow
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "view-grid-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            color: Kirigami.Theme.highlightColor
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            PlasmaComponents3.Label {
                                text: dashboardSettings.entityTitle(cardRowDelegate.modelData.entityId)
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: cardRowDelegate.modelData.entityId || ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Controls.ComboBox {
                            implicitWidth: Kirigami.Units.gridUnit * 5
                            model: ["1x1", "2x1", "1x2", "2x2"]
                            currentIndex: Math.max(0, model.indexOf(cardRowDelegate.modelData.size || "1x1"))
                            onActivated: dashboardSettings.setCardSize(cardRowDelegate.index, currentText)
                        }

                        PlasmaComponents3.ToolButton {
                            icon.name: "arrow-up-symbolic"
                            enabled: cardRowDelegate.index > 0
                            onClicked: dashboardSettings.moveCard(cardRowDelegate.index, -1)
                        }

                        PlasmaComponents3.ToolButton {
                            icon.name: "arrow-down-symbolic"
                            enabled: cardRowDelegate.index < dashboardSettings.cards.length - 1
                            onClicked: dashboardSettings.moveCard(cardRowDelegate.index, 1)
                        }

                        PlasmaComponents3.ToolButton {
                            icon.name: "delete"
                            onClicked: dashboardSettings.removeCard(cardRowDelegate.index)
                        }
                    }
                }
            }
        }

        // ---- Live layout preview -------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: dashboardSettings.cfg_showDashboard && dashboardSettings.cards.length > 0

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
                Layout.preferredHeight: Kirigami.Units.gridUnit * 10
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
                    active: haManager && haManager.isConnected && dashboardSettings.cards.length > 0
                    sourceComponent: Component {
                        Views.DashboardView {
                            haManager: dashboardSettings.managerRef
                            cardsJson: dashboardSettings.cfg_dashboardCards
                            columns: dashboardSettings.cfg_dashboardColumns
                            cardSize: dashboardSettings.cfg_dashboardCardSize
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
                    onClicked: dashboardSettings.addCard(modelData)

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
}
