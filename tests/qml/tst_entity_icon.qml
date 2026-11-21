import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../contents/ui/components" as Components
import "../../contents/ui/mdi" as Mdi

// The glyph a tile draws for an entity. Home Assistant stores icons as
// Material Design Icons names ("mdi:lightbulb"), which no icon theme can
// resolve, so those are drawn from the bundled font in contents/fonts/ - and
// everything else, including an MDI name the font lacks, goes to the theme.
TestCase {
    id: entityIconTest
    name: "EntityIcon"
    when: windowShown

    function findByObjectName(item, name, out) {
        out = out || []
        if (!item) return out
        if (item.objectName === name) out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) findByObjectName(item.children[i], name, out)
        return out
    }

    Components.EntityIcon {
        id: mdiIcon
        visible: true
        width: 22
        height: 22
        iconKind: "mdi"
        icon: "ceiling-light"
        fallbackIcon: "brightness-high-symbolic"
    }

    Components.EntityIcon {
        id: themeIcon
        visible: true
        width: 22
        height: 22
        iconKind: "theme"
        icon: "weather-clear-symbolic"
        fallbackIcon: "preferences-system-symbolic"
    }

    Components.EntityIcon {
        id: fontlessIcon
        visible: true
        width: 22
        height: 22
        iconKind: "mdi"
        // Asked for an MDI glyph, but not one the font has - the tile must
        // still show something sensible instead of an empty box.
        icon: "no-such-mdi-icon"
        fallbackIcon: "media-flash-symbolic"
    }

    function test_bundled_font_is_registered() {
        verify(Mdi.MdiFont.loader.source.toString().endsWith("materialdesignicons-webfont.ttf"),
               "the singleton points at the font shipped with the package")
        tryCompare(Mdi.MdiFont, "family", Mdi.MdiFont.loader.name, 5000)
        verify(Mdi.MdiFont.family.length > 0, "the MDI font loaded")
    }

    function test_mdi_name_draws_the_glyph_from_ha() {
        tryCompare(mdiIcon, "isMdi", true, 5000)
        verify(mdiIcon.glyph.length > 0, "the name became a character")
        var glyphs = findByObjectName(mdiIcon, "entityIconGlyph")
        compare(glyphs.length, 1, "the bundled glyph is what gets painted")
        compare(glyphs[0].text, mdiIcon.glyph)
        compare(glyphs[0].font.family, Mdi.MdiFont.family)
        compare(findByObjectName(mdiIcon, "entityIconTheme").length, 0,
                "nothing from the icon theme is drawn beside it")
    }

    function test_theme_name_uses_the_icon_theme() {
        compare(themeIcon.isMdi, false)
        compare(themeIcon.themeSource, "weather-clear-symbolic")
        compare(findByObjectName(themeIcon, "entityIconGlyph").length, 0)
        var icons = findByObjectName(themeIcon, "entityIconTheme")
        compare(icons.length, 1, "the theme icon is the one painter left")
        compare(icons[0].source, "weather-clear-symbolic")
    }

    function test_unknown_glyph_falls_back_to_the_domain_icon() {
        compare(fontlessIcon.isMdi, false, "an MDI name the font lacks is not drawn")
        compare(fontlessIcon.glyph, "")
        compare(fontlessIcon.themeSource, "media-flash-symbolic")
        compare(findByObjectName(fontlessIcon, "entityIconGlyph").length, 0)
        compare(findByObjectName(fontlessIcon, "entityIconTheme")[0].source,
                "media-flash-symbolic")
    }
}
