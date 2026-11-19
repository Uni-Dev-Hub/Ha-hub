pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

// Shared filter strip for the entity pickers (favorites & dashboard):
// free-text search plus two drop-down lists - entity type and area - each
// entry carrying the number of entities it would leave visible. Drop-downs
// rather than a row of buttons: a HA instance easily has 20 domains and the
// buttons did not fit into the settings dialog.
ColumnLayout {
    id: filterBar

    property alias searchText: searchField.text
    property string selectedDomain: "all"
    property string selectedArea: "all"

    // { domain: count } — only domains present in the current list.
    property var domainCounts: ({})
    // [{ id: "kitchen", name: "Kitchen" }, ...]
    property var areaOptions: []

    readonly property var sortedDomains: {
        var keys = Object.keys(domainCounts || {});
        keys.sort(function(a, b) { return a.localeCompare(b); });
        return keys;
    }
    readonly property int totalCount: {
        var sum = 0;
        var keys = Object.keys(domainCounts || {});
        for (var i = 0; i < keys.length; i++) sum += domainCounts[keys[i]];
        return sum;
    }

    readonly property var domainOptions: {
        var result = [{
            id: "all",
            label: Loc.t("All") + " (" + filterBar.totalCount + ")",
            icon: "view-list-symbolic"
        }];
        var domains = filterBar.sortedDomains;
        for (var i = 0; i < domains.length; i++) {
            result.push({
                id: domains[i],
                label: domains[i] + " (" + (filterBar.domainCounts[domains[i]] || 0) + ")",
                icon: HAHelpers.getDomainIcon(domains[i])
            });
        }
        return result;
    }

    readonly property var areaChoice: [{ id: "all", name: Loc.t("All areas") }].concat(filterBar.areaOptions)

    function indexOfId(options, id) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].id === id) return i;
        }
        return 0;
    }

    function optionIcon(options, index) {
        var item = options && index >= 0 && index < options.length ? options[index] : null;
        return item && item.icon ? item.icon : "";
    }

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Controls.TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: Loc.t("Search entities…")
        }

        Controls.ComboBox {
            id: domainCombo
            visible: filterBar.sortedDomains.length > 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            Layout.minimumWidth: Kirigami.Units.gridUnit * 7
            model: filterBar.domainOptions
            textRole: "label"
            currentIndex: filterBar.indexOfId(filterBar.domainOptions, filterBar.selectedDomain, "label")
            onActivated: {
                var item = model[currentIndex];
                filterBar.selectedDomain = item ? item.id : "all";
            }

            // Icon of the current entity type, then its label.
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: filterBar.optionIcon(domainCombo.model, domainCombo.currentIndex)
                    visible: source.length > 0
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                }

                Controls.Label {
                    text: domainCombo.currentText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Controls.ComboBox {
            id: areaCombo
            visible: filterBar.areaOptions.length > 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            Layout.minimumWidth: Kirigami.Units.gridUnit * 7
            model: filterBar.areaChoice
            textRole: "name"
            currentIndex: filterBar.indexOfId(filterBar.areaChoice, filterBar.selectedArea, "name")
            onActivated: {
                var item = model[currentIndex];
                filterBar.selectedArea = item ? item.id : "all";
            }
        }
    }
}
