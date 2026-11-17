import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../services" as Services
import "components" as Components

PlasmoidItem {
    id: root

    Plasmoid.icon: Qt.resolvedUrl("../icons/home.svg")
    Plasmoid.title: "HA-Hub"

    // On the desktop we draw our own rounded, theme-tinted background so the
    // corner radius setting actually applies. In a panel popup Plasma draws the frame.
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
        || Plasmoid.formFactor === PlasmaCore.Types.MediaCenter
    Plasmoid.backgroundHints: onDesktop ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground

    // Keep the full view even when the widget is made small on the desktop
    switchWidth: Kirigami.Units.gridUnit * 9
    switchHeight: Kirigami.Units.gridUnit * 8

    toolTipMainText: (haManagerService && haManagerService.isConnected)
        ? (haManagerService.serverName || "Home Assistant")
        : "HA-Hub"

    toolTipSubText: {
        if (!haManagerService) return i18n("Disconnected");
        if (!haManagerService.isConnected) return haManagerService.connectionStatus || i18n("Disconnected");
        return i18n("Connected · %1 entities", haManagerService.entityCount);
    }

    readonly property string desktopEntityId: Plasmoid.configuration.desktopEntityId || ""
    readonly property string favoriteEntities: Plasmoid.configuration.favoriteEntities || ""

    function openConfiguration() {
        try {
            if (typeof Plasmoid.internalAction === "function") {
                var configAction = Plasmoid.internalAction("configure");
                if (configAction && typeof configAction.trigger === "function") {
                    configAction.trigger();
                    return;
                }
            }

            if (Plasmoid.contextualActions && Plasmoid.contextualActions.length > 0) {
                for (var i = 0; i < Plasmoid.contextualActions.length; i++) {
                    var act = Plasmoid.contextualActions[i];
                    if (act && (act.objectName === "configure" || (act.text && act.text.toLowerCase().indexOf("config") !== -1))) {
                        if (typeof act.trigger === "function") {
                            act.trigger();
                            return;
                        }
                    }
                }
            }
        } catch (e) {
            console.warn("HA-hub: Error opening settings:", e);
        }
    }

    Services.HAManager {
        id: haManagerService
        host: Plasmoid.configuration.host || ""
        port: Plasmoid.configuration.port || 8123
        useSsl: Plasmoid.configuration.useSsl || false
        accessToken: Plasmoid.configuration.accessToken || ""
        serverName: Plasmoid.configuration.serverName || "Home Assistant"
    }

    Component.onCompleted: {
        haManagerService.startAutoConnect();
    }

    compactRepresentation: CompactRepresentation {
        haManager: haManagerService
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: FullRepresentation {
        haManager: haManagerService
        drawOwnBackground: root.onDesktop
        favoriteEntities: root.favoriteEntities
        onConfigureRequested: root.openConfiguration()
    }
}
