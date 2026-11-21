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

    // Hands the language saved in Settings to the Loc singleton: the applet's
    // engine has its own Loc, and LanguageBridge lives in its own file's
    // context, where Plasma's `Plasmoid` is not visible - so the configuration
    // is handed to it from here.
    //
    // The configuration is asked again every time the popup opens, because the
    // map Plasma hands out notifies nothing: the settings dialog runs in a
    // process of its own and writes the file, and the running applet hears
    // nothing about it. Asking at the moment the language is looked at is what
    // makes a language chosen in Settings reach a widget that was never
    // restarted.
    Components.LanguageBridge {
        id: appletLanguageBridge
        configuration: Plasmoid.configuration
    }

    onExpandedChanged: {
        if (root.expanded)
            appletLanguageBridge.recheck()
    }

    Services.HAManager {
        id: haManagerService
        host: Plasmoid.configuration.host || ""
        port: Plasmoid.configuration.port || 8123
        useSsl: Plasmoid.configuration.useSsl || false
        serverName: Plasmoid.configuration.serverName || "Home Assistant"
        // The names the user gave entities. Every view asks the manager for a
        // name, so one binding renames the tiles, the device list and the cards.
        entityAliases: Plasmoid.configuration.entityAliases || "{}"
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
