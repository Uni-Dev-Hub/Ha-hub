pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

// Shared filter strip for the entity pickers (favorites & dashboard):
// free-text search + area selector + scrollable domain chips with counts.
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
            id: areaCombo
            visible: filterBar.areaOptions.length > 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            model: [{ id: "all", name: Loc.t("All areas") }].concat(filterBar.areaOptions)
            textRole: "name"
            currentIndex: 0
            onActivated: {
                var item = model[currentIndex];
                filterBar.selectedArea = item ? item.id : "all";
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: chipsRow.implicitHeight
        visible: filterBar.sortedDomains.length > 0
        contentWidth: chipsRow.implicitWidth
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        RowLayout {
            id: chipsRow
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                flat: false
                checkable: true
                checked: filterBar.selectedDomain === "all"
                text: Loc.t("All") + " (" + filterBar.totalCount + ")"
                onToggled: if (checked) filterBar.selectedDomain = "all"
            }

            Repeater {
                model: filterBar.sortedDomains

                delegate: PlasmaComponents3.Button {
                    required property string modelData
                    flat: false
                    checkable: true
                    checked: filterBar.selectedDomain === modelData
                    text: modelData + " (" + (filterBar.domainCounts[modelData] || 0) + ")"
                    icon.name: HAHelpers.getDomainIcon(modelData)
                    onToggled: if (checked) filterBar.selectedDomain = modelData
                }
            }
        }
    }
}
