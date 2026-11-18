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
export var LANGUAGES = [
    { code: "en", label: "English" },
    { code: "ru", label: "Русский" },
    { code: "kk", label: "Қазақша" },
    { code: "uk", label: "Українська" },
    { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" },
    { code: "fr", label: "Français" },
    { code: "tr", label: "Türkçe" },
    { code: "zh", label: "中文" }
];

export var CATALOGS = {
    en: {},
    ru: {},
    kk: {},
    uk: {},
    de: {},
    es: {},
    fr: {},
    tr: {},
    zh: {}
};

// Kept in sync by Loc.qml so that plain helper functions (which have no QML
// property access) can translate without threading lang through everywhere.
var currentLang = "en";

export function setLanguage(lang) {
    currentLang = lang || "en";
}

export function language() {
    return currentLang;
}

// "ru-Cyrl-RU" -> "ru" (when supported), unknown -> "en".
export function normalizeLanguage(tag) {
    if (!tag) return "en";
    var base = tag.split("-")[0].toLowerCase();
    for (var i = 0; i < LANGUAGES.length; i++) {
        if (LANGUAGES[i].code === base) return base;
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
