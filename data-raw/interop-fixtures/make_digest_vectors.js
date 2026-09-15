// Independent canonical-JSON and SHA-256 reference vectors for segmantR.
//   node data-raw/interop-fixtures/make_digest_vectors.js > tests/testthat/fixtures/digest/vectors.json
// Canonical form: object keys sorted by code point, no whitespace,
// JSON.stringify string escaping and ECMAScript number formatting.
const crypto = require("crypto");
function canon(v) {
  if (v === null || typeof v !== "object") return JSON.stringify(v);
  if (Array.isArray(v)) return "[" + v.map(canon).join(",") + "]";
  const keys = Object.keys(v).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  return "{" + keys.map(k => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}";
}
const sha = s => crypto.createHash("sha256").update(Buffer.from(s, "utf8")).digest("hex");
const cases = {
  numbers: [0, 1, -1, 0.1, 0.5, 1.5, 1e-7, 1e-6, 1.5e-6, 123456.789, 1e21, 1e20,
            2.5e300, -0.000123, 5e-324, 0.1 + 0.2],
  strings: ["plain", "quote\"back\\slash", "tab\tnew\nline", "ctl\u0001\u001f",
            "µm² unicode", "slash/kept"],
  object: {b: 1, a: [true, false, null], "Z": {y: 2, x: "1"}, "ä": 0.25},
  integrity: {format_version: "1.0", files: [
    {path: "manifest.json", size_bytes: 1234, sha256: "0".repeat(64)},
    {path: "mask.tif", size_bytes: 99, sha256: "a".repeat(64)}
  ]},
  empty: {o: {}, a: []}
};
const out = {};
for (const [name, value] of Object.entries(cases)) {
  const c = canon(value);
  out[name] = {value: value, canonical: c, sha256: sha(c)};
}
out._generator = {node: process.version};
process.stdout.write(JSON.stringify(out, null, 1) + "\n");
