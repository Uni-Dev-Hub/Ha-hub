pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "network-server-symbolic"
        source: "settings/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Favorite devices")
        icon: "starred-symbolic"
        source: "settings/ConfigFavorites.qml"
    }
}
