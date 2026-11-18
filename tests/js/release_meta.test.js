const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.join(__dirname, "..", "..");
const meta = JSON.parse(fs.readFileSync(path.join(root, "metadata.json"), "utf8"));
const changelog = fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8");

test("metadata version is a stable semver without pre-release suffix", () => {
    assert.match(meta.KPlugin.Version, /^\d+\.\d+\.\d+$/, "version must not carry -beta/-rc suffixes");
});

test("CHANGELOG latest section matches metadata version", () => {
    const m = changelog.match(/^## \[(\d+\.\d+\.\d+)\]/m);
    assert.ok(m, "CHANGELOG must start with a versioned section");
    assert.equal(m[1], meta.KPlugin.Version);
});

test("packaging script derives name from metadata version", () => {
    const script = fs.readFileSync(path.join(root, "scripts", "make-plasmoid.sh"), "utf8");
    // The artifact name must contain the version read from metadata.json.
    assert.match(script, /\$\{ID\}-\$\{VERSION\}\.plasmoid/);
    assert.match(script, /KPlugin\.Version/);
});
