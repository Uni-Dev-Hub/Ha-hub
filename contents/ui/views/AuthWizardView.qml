import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../../l10n"

Item {
    id: authWizardRoot

    property var haManager: null
    property string setupStep: "WELCOME"
    property string selectedHost: "homeassistant.local"
    property int selectedPort: 8123
    property string selectedServerName: "Home Assistant"

    ColumnLayout {
        visible: authWizardRoot.setupStep === "WELCOME"
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 1.5
        width: parent.width * 0.90

        Kirigami.Icon {
            source: "network-server-symbolic"
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            Layout.alignment: Qt.AlignHCenter
        }

        PlasmaComponents3.Label {
            text: Loc.t("Welcome to HA-Hub")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.25
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            text: Loc.t("Select your Home Assistant server in local network:")
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: haManager && haManager.isSearching
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.BusyIndicator {
                running: parent.visible
                implicitWidth: Kirigami.Units.gridUnit * 1.5
                implicitHeight: Kirigami.Units.gridUnit * 1.5
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                text: Loc.t("Searching for servers in network...")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ColumnLayout {
            visible: haManager && !haManager.isSearching && haManager.discoveredServers && haManager.discoveredServers.length > 0
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: Loc.t("Found servers:")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
            }

            Repeater {
                model: haManager ? haManager.discoveredServers : []
                delegate: PlasmaComponents3.ItemDelegate {
                    Layout.fillWidth: true
                    onClicked: {
                        authWizardRoot.selectedHost = modelData.host;
                        authWizardRoot.selectedPort = modelData.port || 8123;
                        authWizardRoot.selectedServerName = modelData.name;
                        authWizardRoot.setupStep = "TOKEN_INPUT";
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "network-server-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }

                        PlasmaComponents3.Label {
                            text: modelData.name + " (" + modelData.host + ":" + (modelData.port || 8123) + ")"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Kirigami.Icon {
                            source: "go-next-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: haManager && !haManager.isSearching && (!haManager.discoveredServers || haManager.discoveredServers.length === 0)
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: Loc.t("No servers found in local network")
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                text: Loc.t("Retry Search")
                icon.name: "view-refresh-symbolic"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    if (haManager) haManager.runAutoDiscovery();
                }
            }
        }

        Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

        PlasmaComponents3.Button {
            text: Loc.t("Enter Host / IP manually")
            icon.name: "edit-rename"
            Layout.fillWidth: true
            onClicked: {
                authWizardRoot.selectedHost = (haManager && haManager.host && haManager.host.length > 0) ? haManager.host : "homeassistant.local";
                authWizardRoot.selectedPort = (haManager && haManager.port > 0) ? haManager.port : 8123;
                authWizardRoot.selectedServerName = "Home Assistant";
                authWizardRoot.setupStep = "TOKEN_INPUT";
            }
        }
    }

    ColumnLayout {
        visible: authWizardRoot.setupStep === "TOKEN_INPUT"
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 1.2
        width: parent.width * 0.92

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.ToolButton {
                icon.name: "go-previous"
                text: Loc.t("Back to list")
                display: PlasmaComponents3.AbstractButton.TextBesideIcon
                Layout.alignment: Qt.AlignLeft
                onClicked: authWizardRoot.setupStep = "WELCOME"
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: serverCardRow.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: 8
            color: Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
            border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
            border.width: 1

            RowLayout {
                id: serverCardRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "security-high-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    PlasmaComponents3.Label {
                        text: authWizardRoot.selectedServerName
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.Label {
                        text: authWizardRoot.selectedHost + ":" + authWizardRoot.selectedPort
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            visible: haManager && (haManager.state === "ERROR" || haManager.state === "AUTHENTICATING")
            text: haManager ? haManager.connectionStatus : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
            color: (haManager && haManager.state === "ERROR") ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        PlasmaComponents3.BusyIndicator {
            visible: haManager && haManager.state === "AUTHENTICATING"
            Layout.alignment: Qt.AlignHCenter
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                PlasmaComponents3.TextField {
                    id: manualHostInput
                    placeholderText: "IP / homeassistant.local"
                    Layout.fillWidth: true
                    text: authWizardRoot.selectedHost
                    onTextChanged: authWizardRoot.selectedHost = text
                }

                PlasmaComponents3.TextField {
                    id: manualPortInput
                    placeholderText: "8123"
                    implicitWidth: Kirigami.Units.gridUnit * 3.8
                    text: authWizardRoot.selectedPort.toString()
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: {
                        var p = parseInt(text);
                        if (p > 0) authWizardRoot.selectedPort = p;
                    }
                }
            }

            PlasmaComponents3.TextField {
                id: tokenInput
                placeholderText: Loc.t("Enter Long-Lived Access Token (eyJ...)")
                echoMode: TextInput.Password
                Layout.fillWidth: true
                text: haManager ? (haManager.accessToken || "") : ""
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                PlasmaComponents3.ToolButton {
                    text: Loc.t("Get token in HA Profile")
                    icon.name: "internet-services"
                    display: PlasmaComponents3.AbstractButton.TextBesideIcon
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                    onClicked: {
                        var proto = sslCheckBox.checked ? "https://" : "http://";
                        var targetHost = authWizardRoot.selectedHost || "homeassistant.local";
                        var targetPort = authWizardRoot.selectedPort || 8123;
                        Qt.openUrlExternally(proto + targetHost + ":" + targetPort + "/profile/security");
                    }
                }
            }

            PlasmaComponents3.CheckBox {
                id: sslCheckBox
                text: Loc.t("Use SSL (wss://)")
                checked: haManager ? haManager.useSsl : false
            }

            PlasmaComponents3.Button {
                text: (haManager && haManager.state === "AUTHENTICATING") ? Loc.t("Cancel") : Loc.t("Log In")
                icon.name: (haManager && haManager.state === "AUTHENTICATING") ? "process-stop-symbolic" : "dialog-ok-apply"
                highlighted: true
                Layout.fillWidth: true
                onClicked: {
                    if (!haManager) return;
                    if (haManager.state === "AUTHENTICATING") {
                        haManager.disconnectFromHA();
                    } else {
                        var p = parseInt(manualPortInput.text) || authWizardRoot.selectedPort || 8123;
                        haManager.connectWithParams(authWizardRoot.selectedHost, p, tokenInput.text, sslCheckBox.checked);
                    }
                }
            }
        }
    }
}
