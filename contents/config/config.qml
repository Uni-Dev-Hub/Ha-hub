pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid
import "../l10n"
import "../ui/components" as Components

ConfigModel {
    // The names below are translated, and this file is loaded by the settings
    // dialog's engine, which starts in the language of the system and is told
    // nothing else: the pages learn the language the widget was configured to
    // from their own bridge, which is of no use to a list built next door. So
    // the list needs one too - hung off a property, because everything written
    // in the body of a ConfigModel is taken as one of its categories.
    //
    // Where the configuration cannot be seen from here the bridge stays quiet
    // and the names keep the system language, which is what they did before.
    property QtObject languageBridge: Components.LanguageBridge {
        configuration: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
            ? Plasmoid.configuration : null
    }

    ConfigCategory {
        name: Loc.t("General")
        icon: "network-server-symbolic"
        source: "settings/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: Loc.t("Dashboard")
        icon: "view-grid-symbolic"
        source: "settings/ConfigDashboard.qml"
    }
    ConfigCategory {
        name: Loc.t("Favorite Devices")
        icon: "starred-symbolic"
        source: "settings/ConfigFavorites.qml"
    }
    ConfigCategory {
        name: Loc.t("Appearance")
        icon: "preferences-desktop-theme-global"
        source: "settings/ConfigAppearance.qml"
    }
}
