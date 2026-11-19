import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../services" as Services
import "components" as Components
import "../code/ha_helpers.mjs" as HAHelpers
import "../l10n"

PlasmoidItem {
    id: root

    // Settings -> Appearance: which icon the panel/tray shows.
    readonly property var trayIcon: HAHelpers.resolveIconChoice(
        Plasmoid.configuration.trayIconMode || "auto",
        Plasmoid.configuration.trayIconName || "",
        Plasmoid.configuration.trayIconPath || "",
        "network-server-symbolic", "network-offline",
        haManagerService ? haManagerService.isConnected : false)

    Plasmoid.icon: trayIcon.path.length > 0 ? trayIcon.path
        : (trayIcon.name.length > 0 ? trayIcon.name : "network-server-symbolic")
    Plasmoid.title: "HA-Hub"

    toolTipMainText: (haManagerService && haManagerService.isConnected)
        ? (haManagerService.serverName || "Home Assistant")
        : "HA-Hub"

    toolTipSubText: {
        if (!haManagerService) return Loc.t("Disconnected");
        if (!haManagerService.isConnected) {
            return haManagerService.connectionStatus || Loc.t("Disconnected");
        }
        return Loc.t("Connected (%1:%2)", haManagerService.host, haManagerService.port);
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
            haManagerService.connectionStatus = Loc.t("Auto-connect is disabled in settings");
        }
    }

    compactRepresentation: CompactRepresentation {
        haManager: haManagerService
        preferredIconName: root.trayIcon.name
        preferredImagePath: root.trayIcon.path
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: FullRepresentation {
        haManager: haManagerService
        favoriteEntities: root.favoriteEntities
        onConfigureRequested: root.openConfiguration()
    }
}
