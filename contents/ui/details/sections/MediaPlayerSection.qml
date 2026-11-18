import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: mediaSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property bool isPlaying: eObj && eObj.state === "playing"
    readonly property real volumeLevel: attrs.volume_level !== undefined ? attrs.volume_level : 0.5
    readonly property bool isMuted: attrs.is_volume_muted === true

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: mediaCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: mediaCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("MEDIA & AUDIO")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "audio-speakers-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.highlightColor
            }
        }

        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: attrs.media_title || (mediaSec.isPlaying ? Loc.t("Playing") : Loc.t("Stopped"))
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                visible: attrs.media_artist !== undefined && attrs.media_artist.length > 0
                text: attrs.media_artist || ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.mediumSpacing

            PlasmaComponents3.ToolButton {
                icon.name: "media-skip-backward"
                onClicked: { if (haManager) haManager.callService("media_player", "media_previous_track", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                icon.name: mediaSec.isPlaying ? "media-playback-pause" : "media-playback-start"
                text: mediaSec.isPlaying ? Loc.t("Pause") : Loc.t("Play")
                highlighted: true
                onClicked: { if (haManager) haManager.callService("media_player", "media_play_pause", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.ToolButton {
                icon.name: "media-skip-forward"
                onClicked: { if (haManager) haManager.callService("media_player", "media_next_track", detailsPage.cleanId, {}); }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                icon.name: mediaSec.isMuted ? "audio-volume-muted" : "audio-volume-high"
                onClicked: {
                    if (haManager) haManager.callService("media_player", "volume_mute", detailsPage.cleanId, { is_volume_muted: !mediaSec.isMuted });
                }
            }

            Controls.Slider {
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                value: mediaSec.volumeLevel
                onMoved: {
                    if (haManager) haManager.callService("media_player", "volume_set", detailsPage.cleanId, { volume_level: value });
                }
            }

            PlasmaComponents3.Label {
                text: Math.round(mediaSec.volumeLevel * 100) + "%"
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            }
        }
    }
}
