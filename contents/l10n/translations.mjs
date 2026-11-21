// Lightweight translation layer for HA-Hub (ECMAScript module, shared
// singleton per QML engine).
//
// Keys are the original English UI strings with %1..%3 placeholders.
// Languages missing a key fall back to the English source text, so a partial
// translation never breaks the UI. The QML singleton Loc.qml exposes this to
// components and keeps the active language in sync with Plasmoid.configuration.
//
// To add a language: append it to LANGUAGES and add a CATALOGS entry.

// Display labels are intentionally in the language they name (autonyms).
import ruCatalog from "./catalogs/ru.js";
import kkCatalog from "./catalogs/kk.js";
import ukCatalog from "./catalogs/uk.js";
import deCatalog from "./catalogs/de.js";
import esCatalog from "./catalogs/es.js";
import frCatalog from "./catalogs/fr.js";
import trCatalog from "./catalogs/tr.js";
import zhCatalog from "./catalogs/zh.js";
import beCatalog from "./catalogs/be.js";
import plCatalog from "./catalogs/pl.js";
import csCatalog from "./catalogs/cs.js";
import skCatalog from "./catalogs/sk.js";


export var LANGUAGES = [
    { code: "en", label: "English" },
    { code: "ru", label: "Русский" },
    { code: "kk", label: "Қазақша" },
    { code: "uk", label: "Українська" },
    { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" },
    { code: "fr", label: "Français" },
    { code: "tr", label: "Türkçe" },
    { code: "zh", label: "中文" },
    { code: "be", label: "Беларуская" },
    { code: "pl", label: "Polski" },
    { code: "cs", label: "Čeština" },
    { code: "sk", label: "Slovenčina" }

];

export var CATALOGS = {
    // English is the source language: keys map to themselves implicitly.
    en: {},
    ru: ruCatalog,
    kk: kkCatalog,
    uk: ukCatalog,
    de: deCatalog,
    es: esCatalog,
    fr: frCatalog,
    tr: trCatalog,
    zh: zhCatalog,
    be: beCatalog,
    pl: plCatalog,
    cs: csCatalog,
    sk: skCatalog

};


// Strings asked for by Home Assistant's own value rather than by this code:
// the climate card hands whatever `hvac_action` the integration reports
// straight to the catalog. An action missing here is shown as Home Assistant
// spells it, which is the intended fallback; the list exists so the tests can
// tell this vocabulary from a key that was simply left behind.
export var EXTERNAL_KEYS = [
    "off", "auto", "fan", "heating", "cooling", "drying", "preheating", "fan_only"
];

// Kept in sync by Loc.qml so that plain helper functions (which have no QML
// property access) can translate without threading lang through everywhere.
var currentLang = "en";

export function setLanguage(lang) {
    currentLang = lang || "en";
}

export function language() {
    return currentLang;
}

// A system locale arrives as a language tag - "ru-RU", "zh-TW", "sr-Latn-RS",
// "ca-ES-valencia" - and the most specific catalog available wins. The tag is
// tried whole, then with one subtag less at a time, so "pt-BR" finds pt_BR and
// "pt-PT" is left with plain pt; the last candidate is the bare language.
// Subtags that do not spell a catalog code the way we write it (Chinese
// "Hant", Valencian "valencia") are named in SUBTAG_ALIASES.
var SUBTAG_ALIASES = {
    "zh-hant": "zh_TW", "zh-tw": "zh_TW", "zh-hk": "zh_TW", "zh-mo": "zh_TW",
    "zh-hans": "zh", "zh-cn": "zh", "zh-sg": "zh", "zh-my": "zh",
    "pt-br": "pt_BR",
    "sr-latn": "sr_Latn", "sr-me-latn": "sr_Latn", "sr-rs-latn": "sr_Latn",
    "sr-cyrl": "sr", "sr-rs": "sr",
    "ca-valencia": "ca_VA", "ca-es-valencia": "ca_VA",
    "en-gb": "en", "en-us": "en", "en-au": "en", "en-ca": "en"
};

var supportedTags = null;
function matchTable() {
    if (supportedTags) return supportedTags;
    supportedTags = {};
    for (var i = 0; i < LANGUAGES.length; i++) {
        var code = LANGUAGES[i].code;
        supportedTags[code.toLowerCase().replace(/_/g, "-")] = code;
    }
    for (var tag in SUBTAG_ALIASES) {
        // An alias only means something while the language it aims at is offered.
        if (supportedTags[SUBTAG_ALIASES[tag].toLowerCase().replace(/_/g, "-")]) {
            supportedTags[tag] = SUBTAG_ALIASES[tag];
        }
    }
    return supportedTags;
}

// Rebuilt when the language list changes, so a catalog added later is matched.
export function resetLanguageMatching() {
    supportedTags = null;
}

export function normalizeLanguage(tag) {
    if (!tag) return "en";
    var parts = String(tag).toLowerCase().replace(/_/g, "-").split("-");
    var table = matchTable();
    for (var cut = parts.length; cut > 0; cut--) {
        var found = table[parts.slice(0, cut).join("-")];
        if (found) return found;
    }
    return "en";
}

export function translate(lang, text, args) {
    if (text === undefined || text === null) return "";
    var out = text;
    var cat = CATALOGS[lang || currentLang];
    if (cat && cat[text]) out = cat[text];
    if (!args || args.length === 0) return out;
    for (var i = 0; i < args.length; i++) {
        var value = (args[i] === undefined || args[i] === null) ? "" : String(args[i]);
        out = out.split("%" + (i + 1)).join(value);
    }
    return out;
}

// Translate with the currently active language.
export function tr(text, args) {
    return translate(currentLang, text, args);
}
