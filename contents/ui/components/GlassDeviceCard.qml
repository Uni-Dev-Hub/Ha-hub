import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

// "Card": Liquid Glass style. Everything is derived from Kirigami.Theme,
// so the card follows the system color scheme live.
PlasmaComponents3.ItemDelegate {
    id: cardRoot

    property string entityId: ""
    property var haManager: null
    property int cornerRadius: 16

    signal openDetailsRequested(string entId)

    EntityState {
        id: ent
        entityId: cardRoot.entityId
        haManager: cardRoot.haManager
    }

    readonly property color tint: ent.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

    padding: Kirigami.Units.largeSpacing
    topPadding: Kirigami.Units.largeSpacing
    bottomPadding: Kirigami.Units.smallSpacing * 1.5

    background: Item {
        // Soft drop shadow
        MultiEffect {
            source: glass
            anchors.fill: glass
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.8
            shadowVerticalOffset: 3
            shadowOpacity: cardRoot.hovered ? 0.45 : 0.28
            autoPaddingEnabled: true
        }

        // Glass body: translucent vertical gradient
        Rectangle {
            id: glass
            anchors.fill: parent
            radius: cardRoot.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(cardRoot.tint, ent.isOn ? 0.42 : (cardRoot.hovered ? 0.16 : 0.11)) }
                GradientStop { position: 1.0; color: Qt.alpha(cardRoot.tint, ent.isOn ? 0.18 : 0.03) }
            }
            border.width: 1
            border.color: Qt.alpha(ent.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor,
                                   ent.isOn ? 0.75 : (cardRoot.hovered ? 0.24 : 0.14))
        }

        // Specular sheen on the upper half
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            anchors.bottomMargin: parent.height * 0.5
            radius: cardRoot.cornerRadius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, cardRoot.hovered ? 0.13 : 0.08) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        // Thin bright rim along the top edge
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - cardRoot.cornerRadius * 2
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    scale: pressed ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

    onClicked: if (ent.cleanId) cardRoot.openDetailsRequested(ent.cleanId)

    contentItem: ColumnLayout {
        spacing: Math.round(Kirigami.Units.smallSpacing / 2)
        clip: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            EntityIcon {
                source: ent.iconUrl
                active: ent.isOn
                unavailable: ent.isUnavailable
                circular: true
                iconSize: Kirigami.Units.iconSizes.smallMedium
                interactive: ent.isToggleable || ent.isActionable || ent.hasQuickToggle
                onClicked: ent.toggle()
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents3.ToolButton {
                icon.name: ent.isFavorite ? "starred-symbolic" : "non-starred-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                visible: cardRoot.hovered || ent.isFavorite
                opacity: ent.isFavorite ? 0.9 : 0.6
                text: ent.isFavorite ? i18n("Remove from favorites") : i18n("Add to favorites")
                PlasmaComponents3.ToolTip.text: text
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: ent.toggleFavorite()
            }

            PlasmaComponents3.Switch {
                visible: ent.isToggleable
                enabled: !ent.isUnavailable
                onToggled: ent.setOn(checked)
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

        Item { Layout.fillHeight: true }

        // Big value for sensors, title for everything else
        PlasmaComponents3.Label {
            visible: ent.isValueEntity
            text: ent.statusText
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.45
            font.weight: Font.Bold
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.fillWidth: true
            color: ent.isUnavailable ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
        }

        PlasmaComponents3.Label {
            text: ent.title
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: ent.isValueEntity ? 1 : 2
            elide: Text.ElideRight
            Layout.fillWidth: true
            color: ent.isUnavailable ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
        }

        PlasmaComponents3.Label {
            text: {
                var parts = [];
                if (!ent.isValueEntity) parts.push(ent.statusText);
                if (ent.areaName) parts.push(ent.areaName);
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
}
