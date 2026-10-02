// Independent binary64 inputs and ECMAScript JSON number strings.
// node data-raw/interop-fixtures/make_number_vectors.js > tests/testthat/fixtures/canonical-numbers/ieee754.json
// --extended adds every decimal exponent and 4096 seeded bit patterns.
const extended = process.argv.includes('--extended');
const rows = new Map();
function addBits(bits, group) {
  const bytes = Buffer.alloc(8);
  bytes.writeBigUInt64LE(BigInt.asUintN(64, bits));
  const value = bytes.readDoubleLE();
  if (!Number.isFinite(value)) return;
  const hex = bytes.toString('hex');
  if (!rows.has(hex)) rows.set(hex, {hex, expected: JSON.stringify(value), group});
}
function around(value, group) {
  const bytes = Buffer.alloc(8);
  bytes.writeDoubleLE(value);
  const bits = bytes.readBigUInt64LE();
  for (let delta = -2n; delta <= 2n; delta++) addBits(bits + delta, group);
}
for (const value of [0, -0, Number.MIN_VALUE, Number.MAX_VALUE,
  Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, 0.1 + 0.2, 2.5e300,
  1000000000000000128, 1e23, 333333333.33333329, 1424953923781206.25]) {
  around(value, 'boundary');
}
const exponents = extended ? Array.from({length: 632}, (_, i) => i - 323) :
  [-323, -308, -100, -23, -22, -21, -7, -6, -5, -1, 0, 1, 6, 15, 16, 17,
    18, 19, 20, 21, 22, 23, 24, 100, 300, 308];
for (const exponent of exponents) around(Number('1e' + exponent), 'decimal_exponent');
for (const exponent of [-1074, -1073, -1023, -1022, -1021, -53, -52, -1, 0, 1,
  51, 52, 53, 54, 63, 64, 65, 1022, 1023]) {
  around(2 ** exponent, 'binary_exponent');
}
let state = 0x6a09e667f3bcc909n;
for (let i = 0; i < (extended ? 4096 : 256); i++) {
  state = BigInt.asUintN(64, state ^ (state << 13n));
  state = BigInt.asUintN(64, state ^ (state >> 7n));
  state = BigInt.asUintN(64, state ^ (state << 17n));
  addBits(state, 'seeded_bits');
}
console.log(JSON.stringify({generator: 'Node ' + process.version,
  endianness: 'little', encoding: 'IEEE754 binary64', vectors: [...rows.values()]}, null, 2));
