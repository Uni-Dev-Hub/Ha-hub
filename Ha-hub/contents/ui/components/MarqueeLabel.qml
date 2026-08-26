import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: marqueeRoot

    property string text: ""
    property color color: Kirigami.Theme.textColor
    property bool isBold: false

    clip: true
    implicitHeight: innerLabel.implicitHeight
    implicitWidth: innerLabel.implicitWidth

    readonly property bool isOverflowing: marqueeRoot.width > 0 && innerLabel.implicitWidth > marqueeRoot.width

    function restartAnimation() {
        marqueeAnim.stop();
        innerLabel.x = 0;
        if (marqueeRoot.isOverflowing && marqueeRoot.visible) {
            marqueeAnim.start();
        }
    }

    onWidthChanged: marqueeRoot.restartAnimation()
    onImplicitWidthChanged: marqueeRoot.restartAnimation()
    onTextChanged: marqueeRoot.restartAnimation()
    onVisibleChanged: marqueeRoot.restartAnimation()

    PlasmaComponents3.Label {
        id: innerLabel
        text: marqueeRoot.text
        color: marqueeRoot.color
        font.bold: marqueeRoot.isBold
        font.pointSize: Qt.application.font.pointSize * 1.05
        x: 0
        y: 0

        SequentialAnimation on x {
            id: marqueeAnim
            running: false
            loops: Animation.Infinite

            PauseAnimation { duration: 2500 }

            NumberAnimation {
                to: -(innerLabel.implicitWidth - marqueeRoot.width + 12)
                duration: Math.max(2500, (innerLabel.implicitWidth - marqueeRoot.width) * 35)
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: 1500 }

            NumberAnimation {
                to: 0
                duration: 600
                easing.type: Easing.InOutQuad
            }
        }
    }
}
