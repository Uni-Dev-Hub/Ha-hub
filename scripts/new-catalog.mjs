#!/usr/bin/env node
// Adds a language: writes contents/l10n/catalogs/<code>.js from a list of
// values and registers the language in translations.mjs.
//
//   node scripts/new-catalog.mjs <code> <Label> <values.json>
//
// The values are given in the order of the keys of an existing catalog, which
// saves writing the English source text out again for every language - and is
// also the one way this can go quietly wrong, a value landing on the key beside
// it. So the count has to match exactly, a sample of key/value pairs is printed
// for the eye, and tests/js/translations.test.js then checks that every key the
// code asks for is present, that the %1..%3 placeholders survived, and that no
// catalog holds a key nothing asks for.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const ROOT = path.join(import.meta.dirname, "..");
const DIR = path.join(ROOT, "contents/l10n/catalogs");
const TRANSLATIONS = path.join(ROOT, "contents/l10n/translations.mjs");
const TEMPLATE = "ru.js";                       // any complete catalog: only its keys are used

const [code, label, valuesPath] = process.argv.slice(2);
if (!code || !label || !valuesPath) {
    console.error("usage: new-catalog.mjs <code> <Label> <values.json>");
    process.exit(2);
}

const keys = [...fs.readFileSync(path.join(DIR, TEMPLATE), "utf8")
    .matchAll(/^ {4}("(?:\\.|[^"\\])*"):/gm)].map(m => JSON.parse(m[1]));
const values = JSON.parse(fs.readFileSync(valuesPath, "utf8"));

if (keys.length !== values.length) {
    console.error(`${values.length} values for ${keys.length} keys - the list has to be complete`);
    process.exit(1);
}
if (values.some(v => typeof v !== "string" || !v.trim())) {
    console.error("every value has to be a non-empty string");
    process.exit(1);
}
const placeholders = s => (String(s).match(/%\d/g) || []).sort().join(",");
for (let i = 0; i < keys.length; i++) {
    if (placeholders(keys[i]) !== placeholders(values[i])) {
        console.error(`position ${i}: "${keys[i]}" needs ${placeholders(keys[i])}, value has ${placeholders(values[i])}`);
        process.exit(1);
    }
}

const file = path.join(DIR, `${code}.js`);
if (fs.existsSync(file)) {
    console.error(`${path.basename(file)} already exists - edit it instead of regenerating`);
    process.exit(1);
}

const header = `// ${code} (${label}): the widget's strings in one language. Keys are the
// English source text exactly as the QML and JS ask for them; %1..%3 stay where
// the sentence needs them. A key missing here falls back to the English source,
// so an unfinished translation never breaks the UI.
//
// \`npm test\` (tests/js/translations.test.js) checks that every key the code asks
// for is here, that no catalog holds a key nothing asks for, and that the
// placeholders survive.
export default {
`;
const body = keys.map((k, i) => `    ${JSON.stringify(k)}: ${JSON.stringify(values[i])}`).join(",\n");
fs.writeFileSync(file, `${header}${body}\n};\n`);

// Register the language: LANGUAGES entry, import, CATALOGS entry.
let translations = fs.readFileSync(TRANSLATIONS, "utf8");
if (new RegExp(`\\{ code: "${code}"`).test(translations)) {
    console.log(`${code} is already offered; catalog rewritten`);
} else {
    translations = translations.replace(/(\n)(    \{ code: "zh", label: "中文" \})\n\];/,
        `$1$2,\n    { code: ${JSON.stringify(code)}, label: ${JSON.stringify(label)} }\n];`);
    if (!translations.includes(`{ code: ${JSON.stringify(code)}`)) {
        console.error("could not add the language to LANGUAGES - the block changed shape");
        process.exit(1);
    }
    const ident = code.replace(/[^a-zA-Z]/g, "_") + "Catalog";
    translations = translations.replace(/(import zhCatalog from "\.\/catalogs\/zh\.js";\n)/,
        `$1import ${ident} from "./catalogs/${code}.js";\n`);
    translations = translations.replace(/(\n)    zh: zhCatalog\n\};/,
        `$1    zh: zhCatalog,\n    ${code}: ${ident}\n};`);
    fs.writeFileSync(TRANSLATIONS, translations);
}

// The module has to load, not just look right: a botched insertion above would
// otherwise surface somewhere else as "cannot use import statement outside a
// module", as it did once.
const loaded = await import(pathToFileURL(TRANSLATIONS).href).catch((e) => {
    console.error("translations.mjs no longer loads:", e.message);
    process.exit(1);
});
if (!loaded.CATALOGS[code]) {
    console.error(`${code} is in the catalog directory but not wired into CATALOGS`);
    process.exit(1);
}

console.log(`wrote catalogs/${code}.js (${keys.length} keys), registered ${code} (${label}); ` +
    `module loads, ${loaded.LANGUAGES.length} languages offered`);
const sample = [0, 1, 2, 3, 4, 5, 40, 77, 111, 150, 188, 214, 240, 262, 280, keys.length - 1];
console.log("spot check - key -> value:");
for (const i of [...new Set(sample)]) console.log(`  [${i}] ${keys[i]} -> ${values[i]}`);
