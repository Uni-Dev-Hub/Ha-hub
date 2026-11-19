pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid
import "../l10n"

ConfigModel {
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
        name: Loc.t("Appearance")
        icon: "preferences-desktop-theme-global"
        source: "settings/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: Loc.t("Favorite Devices")
        icon: "starred-symbolic"
        source: "settings/ConfigFavorites.qml"
    }
}
