# Test fixtures

Fixtures are independent of the segmantR code paths they test.

| Directory | Produced by | Purpose |
|---|---|---|
| `tiff/` | `data-raw/interop-fixtures/make_tiff_fixtures.py` (Python tifffile, numpy; versions in `expected.json`) | uint8/uint16 (little and big endian, zlib)/uint32 label TIFFs, float32 (rejected as labels), a four-page float64 stack and chunky RGB, with expected values defined in numpy |
| `digest/` | `data-raw/interop-fixtures/make_digest_vectors.js` (Node `JSON.stringify` + `crypto`), integrity vector cross-checked with Python `json`/`hashlib` | canonical JSON and SHA-256 reference vectors |
| `geojson/` | written by hand | polygons with a hole, an L shape, a float triangle and unsupported point/line geometries; expected labels computed by hand with the pixel-centre rule |
| `qupath-0.7.0/` | `data-raw/qupath-evidence/run_evidence.R` with QuPath 0.7.0, qupath-extension-stardist 0.6.0 and `dsb2018_heavy_augment.pb` | `stardist_out/`: headless StarDist export written by `segmantR_stardist.groovy`; `segmantR_bundle/`: the segmantR bundle imported into QuPath; `import_roundtrip_export/`: the QuPath export after import, save and reopening; `nuclei.ome.tif`: the synthetic calibrated image; `run_*.json`; `evidence.json`: steps, exit codes and comparisons |

The QuPath fixtures contain only synthetic data. Object ids are random UUIDs
created by QuPath and change when the evidence run is repeated; tests check
internal consistency, not literal ids.
