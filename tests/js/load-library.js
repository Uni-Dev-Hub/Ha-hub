// The libraries under test are ECMAScript modules that the QML package imports
// directly, while these tests are CommonJS. This loads a module into a vm
// sandbox instead, translating the handful of ESM forms the package uses:
//
//   import * as T from "../l10n/translations.mjs";
//   import { translate } from "../l10n/translations.mjs";
//   import ru from "./catalogs/ru.js";
//   export function tr() {} / export var X = 1 / export default { ... }
//
// Dependencies are loaded the same way, so a catalog file ends up as the value
// the importing module sees.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const ROOT = path.join(__dirname, "..", "..");

function loadLibrary(relativePath) {
    let source = fs.readFileSync(path.join(ROOT, relativePath), "utf8");
    source = source.replace(/^\.pragma library\s*/m, "");
    const context = { console, __defaultExport: undefined };
    vm.createContext(context);

    const star = [...source.matchAll(/^import\s+\*\s+as\s+(\w+)\s+from\s+"([^"]+)";?\s*$/gm)];
    const named = [...source.matchAll(/^import\s+\{([^}]+)\}\s+from\s+"([^"]+)";?\s*$/gm)];
    const dflt = [...source.matchAll(/^import\s+(\w+)\s+from\s+"([^"]+)";?\s*$/gm)];
    source = source.replace(/^import\s+(?:\*\s+as\s+\w+|\{[^}]+\}|\w+)\s+from\s+"[^"]+";?\s*$/gm, "");

    for (const [, alias, spec] of star) {
        context[alias] = loadLibrary(path.join(path.dirname(relativePath), spec));
    }
    for (const [, name, spec] of dflt) {
        context[name] = loadLibrary(path.join(path.dirname(relativePath), spec)).default;
    }
    for (const [, names, spec] of named) {
        const dep = loadLibrary(path.join(path.dirname(relativePath), spec));
        for (const name of names.split(",").map(s => s.trim()).filter(Boolean)) {
            context[name] = dep[name];
        }
    }

    // Inline `export function/var` become plain declarations; the trailing
    // `export { ... };` block is dropped (the declarations are already global
    // here), and `export default` lands on the context as `.default`.
    source = source.replace(/^export\s+(?=(?:async\s+)?(?:function|var|let|const)\b)/gm, "");
    source = source.replace(/^export\s*\{[^}]*\};?\s*$/gm, "");
    source = source.replace(/^export\s+default\s+/gm, "__defaultExport = ");
    vm.runInContext(source, context, { filename: relativePath });
    context.default = context.__defaultExport;
    return context;
}

module.exports = { loadLibrary, ROOT };
