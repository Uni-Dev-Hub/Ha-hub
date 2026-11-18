import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../services" as Services
import "components" as Components

PlasmoidItem {
    id: root

    Plasmoid.icon: (haManagerService && haManagerService.isConnected) ? "network-server-symbolic" : "network-offline"
    Plasmoid.title: "HA-Hub"

    toolTipMainText: (haManagerService && haManagerService.isConnected)
        ? (haManagerService.serverName || "Home Assistant")
        : "HA-Hub"

    toolTipSubText: {
        if (!haManagerService) return i18n("Disconnected");
        if (!haManagerService.isConnected) {
            return haManagerService.connectionStatus || i18n("Disconnected");
        }
        return i18n("Connected (%1:%2)", haManagerService.host, haManagerService.port);
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
        serverName: Plasmoid.configuration.serverName || "Home Assistant"
    }

    Component.onCompleted: {
        if (Plasmoid.configuration.autoConnect !== false) {
            haManagerService.startAutoConnect();
        } else {
            haManagerService.connectionStatus = i18n("Auto-connect is disabled in settings");
        }
    }

    compactRepresentation: CompactRepresentation {
        haManager: haManagerService
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: FullRepresentation {
        haManager: haManagerService
        favoriteEntities: root.favoriteEntities
        onConfigureRequested: root.openConfiguration()
    }
}
