# segmantR interoperability, migration and security notes

This document describes the contracts segmantR offers to partner software
(qupflowR — working title of the QuPath workflow kit: qupathR —, annotatR,
QuPath with the StarDist extension). It is installed with the package:
`system.file("interop", "INTEROP.md", package = "segmantR")`.

## 1. Versions

| Item | Value | Where |
|---|---|---|
| R API version | `1.0.0` | `sg_interchange_capabilities()$api_version` |
| Interchange schema family | `segmantR-interchange-v1`, schema version `1.0.0` | `inst/schema/segmantR-interchange-v1/` |
| Protocol schema | `segmantR-protocol-v1` | `protocol.schema.json`, `inst/protocols/*.json` |
| QuPath run description | `segmantR-qupath-run-v1`, template version `1.0.0` | `qupath-run.schema.json`, `inst/qupath/*.groovy` |
| Model card | `segmantR-model-card-v1` | `model-card.schema.json` |
| Control service | `segmantR-control-v1` — **planned, not implemented** | `sg_control_capabilities()` |

Semantic versioning: a new **major** version (schema family `-v2`, schema
version `2.x`, protocol id suffix `.v2`) is a breaking change and is refused
by readers of the previous major version (`PROTOCOL_MISMATCH`). Minor
versions add optional fields; unknown fields outside `extensions` are
validation errors, so producers put vendor data only in `extensions`.
Protocol ids carry their major version (`threshold.otsu.v1` has version
`1.y.z`); a changed algorithm or default that alters results gets a new
minor or major version, never a silent change.

## 2. Capability status

| Profile | Status | Evidence / reason |
|---|---|---|
| I0 neutral files (manifest, integer TIFF, GeoJSON, legend, measurements, inventory) | supported | tests with independent tifffile, Node/Python digest and QuPath 0.7.0 fixtures |
| I1 protocols and run envelopes | supported | exact synthetic oracles, direct-vs-declarative identity, fresh R process |
| models (bundles) | supported | tamper/traversal/corrupt/legacy tests |
| datasets | supported | leakage, exclusion and tile integrity tests |
| QuPath programs | planned | headless runs verified in the opt-in lane; GUI Script Editor session and a qupflowR consumer not verified |
| StarDist via QuPath | planned | parameter map checked against extension 0.6.0; no partner consumer |
| StarDist via Python | unavailable unless `stardist` + `tensorflow` are installed | checked at the point of use |
| control service | planned | not implemented |
| partner contracts qupflowR / annotatR | planned | no consumer exists yet |

`sg_interchange_capabilities()` reports the live status. Nothing is reported
as `supported` without tests, and the partner contract becomes `supported`
only with a real qupflowR/annotatR consumer and QuPath/StarDist evidence.

## 3. Data invariants

* **Arrays**: `[y, x, channel]`; the first array row is the top image row.
  A two-dimensional array is one channel. Hyperspectral cubes use the same
  order with bands as channels (`[y, x, band]`), identical to annotatR.
* **Coordinates**: full-resolution pixel grid, origin top-left, x right,
  y down, unit px. Array cell `[r, c]` covers `[c-1, c) x [r-1, r)` before
  the image `origin` (`x`, `y`, `downsample`) is applied; the pixel centre is
  at half-integers. GeoJSON uses these image coordinates (no CRS).
* **Planes**: `level`, `series`, `c`, `z`, `t` are zero-based; `c = null`
  means all channels. Image and mask planes must agree; unknown planes are
  rejected, never set to 0.
* **Masks**: integer, background `0`. `instance` = one connected object per
  positive id; `labelled` = class codes; `binary` = 0/1. Dtype in files is
  the smallest unsigned integer type (uint8/uint16/uint32). Every positive
  label present in the mask must be in the legend.
* **Identity**: images have a declared `id` or `sha256:<16 hex>` of their
  pixels; objects have a legend `object_id` that follows the object through
  corrections, exports, QuPath import and export. Label values are not
  identities (QuPath exports number labels by object-id order). Absolute
  paths are never identities and never written to manifests.
* **Revisions**: `sg_mask_revision()` = SHA-256 over the canonical JSON
  `{"labels": <array digest>, "legend": [{"class", "label", "object_id"}],
  "mask_type"}`; the array digest covers dims and row-major little-endian
  int32 values. The QuPath templates compute the same revision in Groovy;
  the evidence lane verifies that both agree.
* **Measurements**: long format `image_id, object_id, label, name,
  namespace (stored|dynamic|derived), value, value_state, unit, provider_id`.
  `value_state` distinguishes `finite`, `missing`, `nan`, `pos_inf`,
  `neg_inf`; only finite values carry a number.
* **Inventories**: `integrity.json` lists every file except itself, sorted
  by UTF-8 path, with `size_bytes` and `sha256`; the bundle digest is the
  SHA-256 of its canonical JSON (keys sorted by code point, no whitespace,
  ECMAScript number format). Model archives use `checksums.sha256`.

### Canonical number correction boundary

The numeric serializer correction in the development version retains the
existing canonical JSON contract: shortest round-tripping ECMAScript decimal
strings for the exact binary64 input, with `.` as the decimal separator.
Digits are generated by exact integer-limb arithmetic and rounded explicitly
to nearest with ties to even; platform printf rounding and R source-literal
parsing do not define the serializer contract.
For example, the binary64 value represented by `1000000000000000128` must
serialize as `1000000000000000100`. Earlier versions emitted the longer integer
form and could choose excess digits on some platforms. This correction does
not change the schema or reinterpret numeric values, but changes canonical
bytes and derived digests wherever the previous output was incorrect.

Keep original bundles and their receipts immutable. Re-export affected
manifests, protocols or model records as new versioned artifacts, recording
both source and corrected digests in the caller's migration record. Do not
patch checksums to bypass an integrity or expected-revision failure. Correctly
canonicalized historical data retains its bytes; the existing independent
fixture and digest expectations remain unchanged. The generator and exact
binary64 test vectors under `data-raw/interop-fixtures/` and
`tests/testthat/fixtures/canonical-numbers/` specify the correction boundary.

## 4. Protocols and runtimes

Protocols are JSON data. The delegate is chosen from a fixed whitelist and
each parameter declares type, bounds, unit, nullability, calibration
requirement and its mapping to the delegate argument. Unknown parameters,
out-of-range values, ambiguous channel selections and missing calibration
are errors. The run envelope records the protocol digest, effective
parameters and their digest, the exact delegate arguments, input digests,
output revision, seed policy and runtime, so a direct call with the recorded
arguments reproduces the mask.

Core protocols run in R without Python, EBImage, QuPath or vendor SDKs and
process one plane in memory (limit 4,194,304 pixels). `propagate.voronoi.v1`
always uses the pure-R engine so results do not depend on EBImage.
DNN protocols check their backend at the point of use; a missing backend
gives `CAPABILITY_UNAVAILABLE` (or a run with `status = "unavailable"`), never
a fallback. DNN predictions are staged. Mesmer requires calibration (no
implicit 0.5 um/px). Cellpose 3.x is supported (its `eval()` tiles
internally).

## 5. Hyperspectral value semantics

`value_semantics` is one of `unknown`, `intensity`, `raw`, `reflectance`,
`radiance`, `absorbance`, `probability`. It is declared, never inferred.
`sg_read_envi()` returns stored values and records gain, offset,
reflectance scale factor and nodata without applying them. Datasets refuse
mixed semantics. `ratio` and `normalized_difference` require declared
semantics and produce `unknown`. Band selection is by index, name,
wavelength (with tolerance) or the registered operations `band_mean`,
`ratio`, `normalized_difference`; there are no free expressions. Manifests
record the bands and wavelengths read, `calibration_digest`,
`transform_digest` and the bytes read. Printing, plotting and app start do
not read cube files. Cubert and TIVITA data enter through neutral ENVI/TIFF
exports; no vendor SDK is required.

## 6. Models and licenses

Bundles never contain Python environments. Weights are embedded under
`weights/` (relative structure kept) or referenced by relative, hashed paths
next to the archive. The model card names purpose, data domain, channels,
target pixel size, value semantics, normalisation, limitations, license and
evaluation metrics with the dataset digest. License information is copied
from the caller; segmantR does not assert licenses for third-party weights
(for example the StarDist `.pb` models used in the QuPath evidence are
distributed with their own license file by the QuPath/StarDist authors).

## 7. Security boundaries

* No evaluation of R, Python, shell or Groovy code from user text, protocol
  files, `run.json`, manifests or comments; no DOM/CSS control; no private
  QuPath or Shiny internals.
* All bundle, archive and `run.json` paths are relative, normalised and
  checked against traversal and symbolic-link escapes (`PATH_OUTSIDE_ROOT`,
  `ARCHIVE_UNSAFE`); archive entry counts and sizes are limited.
* RDS is deserialised only with `trust_rds = TRUE`, and for bundles only
  after the neutral representation has been verified.
* Destinations are never overwritten unless they are segmantR bundles and
  `overwrite = TRUE`; reviewed masks are never replaced without the expected
  revision and an explicit overwrite decision.
* segmantR never starts QuPath or Java. The Groovy templates read only
  `run.json` and the files it names, verify SHA-256 digests, image size,
  calibration, plane and channels, refuse id collisions, and save project
  data only with `save_policy = "project"`.

## 8. QuPath round trip

1. `sg_export_qupath(mask, dir, image = img, image_name = ...)` or
   `sg_export_qupath("stardist.2d.v1", dir, image = img, model = "x.pb", ...)`.
2. In QuPath: run `segmantR_import.groovy` or `segmantR_stardist.groovy`
   (Script Editor with `run.json` in `<project>/segmantR/`, or
   `QuPath script --project=... --image=... --args=run.json [--save] <template>`).
3. Export with `segmantR_export.groovy` and `run_export.json` (GeoJSON,
   integer label TIFF, canonical and native measurements, manifest,
   `integrity.json`).
4. `sg_import_qupath(dir)` verifies the inventory, manifest, TIFF digest,
   Groovy-computed revision, GeoJSON/TIFF agreement, object ids and
   measurements, and returns a staged mask.

StarDist parameters are mapped explicitly by `sg_stardist_parameter_map()`;
options the extension cannot honour (for example a non-default
`nms_thresh`) are listed as `unsupported` and refused unless
`allow_unsupported = TRUE`.

## 9. Planned control service (`segmantR-control-v1`)

Not implemented. The planned contract: off by default; loopback only;
random short-lived bearer token with TTL; request size and path limits;
`request_id` on every request, `expected_revision` and idempotency keys on
mutations; typed commands limited to loading, view/plane, protocol
validation and run, mask preview, stage/review/export and closing the own
service; no `/eval` or DOM endpoints; stopping only its own service.

## 10. Migration from segmantR 0.1.0

* Existing calls keep working with unchanged defaults. New object fields
  have defaults for objects created by older versions.
* `sg_export_mask(format = "tiff")` still writes a normalised 16-bit image
  for display; use `sg_export_interchange()` for exact integer labels.
* `sg_export_mask(format = "qupath")` still writes convex-hull polygons; the
  interchange GeoJSON uses exact pixel-edge polygons with stable ids.
* `.segmantR` archives from 0.1.0 load with `integrity = "unverified"`;
  re-package them with `sg_package_model()` to add checksums and cards.
* `sg_read_image()` now returns `[y, x, channel]` for PNG/JPEG (imager) and
  EBImage reads; code that compensated for the old transposition must be
  updated.
* The package no longer probes Python when attached.
