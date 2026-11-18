import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: lightSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property var colorModes: attrs.supported_color_modes || []

    readonly property bool supportsColorTemp: colorModes.indexOf("color_temp") !== -1
    readonly property bool supportsColor: colorModes.indexOf("rgb") !== -1 || colorModes.indexOf("hs") !== -1 || colorModes.indexOf("xy") !== -1 || colorModes.indexOf("rgbw") !== -1 || colorModes.indexOf("rgbww") !== -1
    readonly property bool supportsEffects: attrs.effect_list !== undefined && Array.isArray(attrs.effect_list) && attrs.effect_list.length > 0

    readonly property int minKelvin: attrs.min_color_temp_kelvin || 2200
    readonly property int maxKelvin: attrs.max_color_temp_kelvin || 6500
    readonly property int currentKelvin: attrs.color_temp_kelvin || Math.round((minKelvin + maxKelvin) / 2)

    property real currentHue: (attrs.hs_color && attrs.hs_color.length > 0) ? (attrs.hs_color[0] / 360.0) : 0.0
    property real currentSat: (attrs.hs_color && attrs.hs_color.length > 1) ? (attrs.hs_color[1] / 100.0) : 1.0

    Timer {
        id: colorThrottleTimer
        interval: 40
        repeat: false
        property var pendingRgb: null
        onTriggered: {
            if (pendingRgb && haManager) {
                haManager.callService("light", "turn_on", detailsPage.cleanId, { rgb_color: pendingRgb });
            }
        }
    }

    function scheduleColorChange(rgb) {
        colorThrottleTimer.pendingRgb = rgb;
        if (!colorThrottleTimer.running) {
            colorThrottleTimer.start();
        }
    }

    function hsvToRgb(h, s, v) {
        var r, g, b;
        var i = Math.floor(h * 6);
        var f = h * 6 - i;
        var p = v * (1 - s);
        var q = v * (1 - f * s);
        var t = v * (1 - (1 - f) * s);
        switch (i % 6) {
            case 0: r = v; g = t; b = p; break;
            case 1: r = q; g = v; b = p; break;
            case 2: r = p; g = v; b = t; break;
            case 3: r = p; g = q; b = v; break;
            case 4: r = t; g = p; b = v; break;
            case 5: r = v; g = p; b = q; break;
        }
        return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
    }

    readonly property color activeLightColor: {
        if (attrs.rgb_color && attrs.rgb_color.length >= 3) {
            return Qt.rgba(attrs.rgb_color[0]/255, attrs.rgb_color[1]/255, attrs.rgb_color[2]/255, 1.0);
        }
        var rgb = lightSec.hsvToRgb(lightSec.currentHue, lightSec.currentSat, 1.0);
        return Qt.rgba(rgb[0]/255, rgb[1]/255, rgb[2]/255, 1.0);
    }

    readonly property var colorPresets: [
        { name: "Warm", r: 255, g: 214, b: 170, color: "#FFD6AA" },
        { name: "Daylight", r: 255, g: 250, b: 244, color: "#FFFAF4" },
        { name: "Cold", r: 212, g: 235, b: 255, color: "#D4EBFF" },
        { name: "Red", r: 255, g: 59, b: 48, color: "#FF3B30" },
        { name: "Orange", r: 255, g: 149, b: 0, color: "#FF9500" },
        { name: "Yellow", r: 255, g: 204, b: 0, color: "#FFCC00" },
        { name: "Green", r: 52, g: 199, b: 89, color: "#34C759" },
        { name: "Cyan", r: 0, g: 199, b: 190, color: "#00C7BE" },
        { name: "Blue", r: 0, g: 122, b: 255, color: "#007AFF" },
        { name: "Purple", r: 175, g: 82, b: 222, color: "#AF52DE" },
        { name: "Pink", r: 255, g: 45, b: 85, color: "#FF2D55" }
    ]

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: lightCol.implicitHeight + Kirigami.Units.smallSpacing * 2.2

    ColumnLayout {
        id: lightCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.4
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("BRIGHTNESS & COLOR")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 14
                implicitHeight: 14
                radius: 7
                color: lightSec.activeLightColor
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.3)
                border.width: 1
            }

            PlasmaComponents3.Label {
                text: {
                    if (!detailsPage.isTurnedOn) return Loc.t("Off");
                    var b = attrs.brightness !== undefined ? attrs.brightness : 255;
                    return Math.round((b / 255) * 100) + "%";
                }
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.1
                color: Kirigami.Theme.textColor
            }
        }

        Controls.Slider {
            Layout.fillWidth: true
            from: 1
            to: 255
            value: attrs.brightness !== undefined ? attrs.brightness : 255
            onMoved: {
                if (haManager) {
                    haManager.callService("light", "turn_on", detailsPage.cleanId, { brightness: Math.round(value) });
                }
            }
        }

        Item {
            visible: lightSec.supportsColor
            id: wheelContainer
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 110
            implicitHeight: 110

            Canvas {
                id: wheelCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d");
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = Math.min(cx, cy) - 2;
                    ctx.clearRect(0, 0, width, height);

                    for (var angle = 0; angle < 360; angle += 3) {
                        var startRad = (angle - 1.5) * Math.PI / 180;
                        var endRad = (angle + 3) * Math.PI / 180;
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.arc(cx, cy, r, startRad, endRad);
                        ctx.closePath();

                        var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                        grad.addColorStop(0, '#FFFFFF');
                        grad.addColorStop(1, 'hsl(' + angle + ', 100%, 50%)');
                        ctx.fillStyle = grad;
                        ctx.fill();
                    }
                }
            }

            Rectangle {
                id: colorMarker
                readonly property real cx: wheelContainer.width / 2
                readonly property real cy: wheelContainer.height / 2
                readonly property real wheelRadius: Math.min(cx, cy) - 2
                readonly property real angleRad: lightSec.currentHue * 2 * Math.PI

                x: cx + Math.cos(angleRad) * (lightSec.currentSat * wheelRadius) - width / 2
                y: cy + Math.sin(angleRad) * (lightSec.currentSat * wheelRadius) - height / 2
                width: 14
                height: 14
                radius: 7
                color: lightSec.activeLightColor
                border.color: "white"
                border.width: 2
            }

            MouseArea {
                id: wheelMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function pickColor(mx, my) {
                    var cx = wheelContainer.width / 2;
                    var cy = wheelContainer.height / 2;
                    var r = Math.min(cx, cy) - 2;

                    var dx = mx - cx;
                    var dy = my - cy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    var sat = Math.max(0.0, Math.min(1.0, dist / r));

                    var angleRad = Math.atan2(dy, dx);
                    var angleDeg = (angleRad * 180 / Math.PI + 360) % 360;
                    var hue = angleDeg / 360.0;

                    lightSec.currentHue = hue;
                    lightSec.currentSat = sat;

                    var rgb = lightSec.hsvToRgb(hue, sat, 1.0);
                    lightSec.scheduleColorChange(rgb);
                }

                onPressed: function(mouse) { pickColor(mouse.x, mouse.y); }
                onPositionChanged: function(mouse) { if (pressed) pickColor(mouse.x, mouse.y); }
            }
        }

        Flow {
            visible: lightSec.supportsColor
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: lightSec.colorPresets
                delegate: Rectangle {
                    required property var modelData
                    width: 20
                    height: 20
                    radius: 10
                    color: modelData.color
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (haManager) {
                                haManager.callService("light", "turn_on", detailsPage.cleanId, { rgb_color: [modelData.r, modelData.g, modelData.b] });
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: lightSec.supportsColorTemp
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: Loc.t("White Temperature")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.80
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: lightSec.currentKelvin + " K"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.80
                }
            }

            Controls.Slider {
                Layout.fillWidth: true
                from: lightSec.minKelvin
                to: lightSec.maxKelvin
                value: lightSec.currentKelvin
                onMoved: {
                    if (haManager) {
                        haManager.callService("light", "turn_on", detailsPage.cleanId, { color_temp_kelvin: Math.round(value) });
                    }
                }
            }
        }

        ColumnLayout {
            visible: lightSec.supportsEffects
            Layout.fillWidth: true
            spacing: 2

            PlasmaComponents3.Label {
                text: Loc.t("Light Effect")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.80
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.ComboBox {
                Layout.fillWidth: true
                model: attrs.effect_list || []
                currentIndex: model ? model.indexOf(attrs.effect) : 0
                onActivated: {
                    if (haManager) haManager.callService("light", "turn_on", detailsPage.cleanId, { effect: currentText });
                }
            }
        }
    }
}
