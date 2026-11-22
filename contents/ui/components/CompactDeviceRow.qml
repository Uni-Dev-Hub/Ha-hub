import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

// "Righe": dense one-line list item.
PlasmaComponents3.ItemDelegate {
    id: rowRoot

    property string entityId: ""
    property var haManager: null
    property int cornerRadius: 10

    signal openDetailsRequested(string entId)

    EntityState {
        id: ent
        entityId: rowRoot.entityId
        haManager: rowRoot.haManager
    }

    implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.3)
    leftPadding: Kirigami.Units.smallSpacing * 1.5
    rightPadding: Kirigami.Units.smallSpacing
    topPadding: 0
    bottomPadding: 0

    background: Rectangle {
        radius: Math.min(rowRoot.cornerRadius, height / 2)
        color: rowRoot.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.08)
             : ent.isOn ? Qt.alpha(Kirigami.Theme.highlightColor, 0.14)
             : Qt.alpha(Kirigami.Theme.textColor, 0.03)
        border.width: 1
        border.color: rowRoot.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.35) : Qt.alpha(Kirigami.Theme.textColor, 0.06)
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    }

    onClicked: if (ent.cleanId) rowRoot.openDetailsRequested(ent.cleanId)

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 1.5

        EntityIcon {
            source: ent.iconUrl
            active: ent.isOn
            unavailable: ent.isUnavailable
            interactive: ent.isToggleable || ent.isActionable || ent.hasQuickToggle
            onClicked: ent.toggle()
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            PlasmaComponents3.Label {
                text: ent.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.fillWidth: true
                color: ent.isUnavailable ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
            }

            PlasmaComponents3.Label {
                text: {
                    var parts = [];
                    if (ent.areaName) parts.push(ent.areaName);
                    if (!ent.isValueEntity) parts.push(ent.statusText);
                    return parts.join(" · ");
                }
                visible: text.length > 0
                font: Kirigami.Theme.smallFont
                color: ent.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.fillWidth: true
            }
        }

        // Value pill for sensors / climate
        Rectangle {
            visible: ent.isValueEntity
            implicitHeight: valueLabel.implicitHeight + Kirigami.Units.smallSpacing
            implicitWidth: Math.min(valueLabel.implicitWidth + Kirigami.Units.largeSpacing, rowRoot.width * 0.4)
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.07)
            Layout.alignment: Qt.AlignVCenter

            PlasmaComponents3.Label {
                id: valueLabel
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Kirigami.Units.smallSpacing * 2)
                elide: Text.ElideRight
                text: ent.statusText
                font.weight: Font.DemiBold
                color: ent.isUnavailable ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
            }
        }

        PlasmaComponents3.ToolButton {
            visible: (rowRoot.hovered || ent.isFavorite) && rowRoot.width > Kirigami.Units.gridUnit * 14
            icon.name: ent.isFavorite ? "starred-symbolic" : "non-starred-symbolic"
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: ent.isFavorite ? i18n("Remove from favorites") : i18n("Add to favorites")
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: ent.toggleFavorite()
        }

        PlasmaComponents3.Switch {
            visible: ent.isToggleable
            enabled: !ent.isUnavailable
            onToggled: ent.setOn(checked)
            // Survives the user's click, follows HA's real state afterwards
            Binding on checked { value: ent.isOn; restoreMode: Binding.RestoreNone }
        }

        PlasmaComponents3.ToolButton {
            visible: ent.isActionable || ent.hasQuickToggle
            enabled: !ent.isUnavailable
            icon.name: ent.isActionable ? "media-playback-start-symbolic" : ent.quickToggleIcon
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: ent.isActionable ? i18n("Run") : ent.quickToggleTooltip
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: ent.isActionable ? ent.activate() : ent.quickToggle()
        }
    }
}
