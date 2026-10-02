# segmantR (development version)

* Count and process only present mask labels without phantom feature or export
  rows. Filtering still renumbers retained objects and now maps border flags to
  those output labels. Reject non-finite, fractional,
  negative and out-of-range labels before integer conversion; full uint32 IDs
  above 2147483647 remain unsupported.

* Preserve the exact bytes of authenticated synthetic QuPath fixtures during
  Git checkout, including when automatic CRLF conversion is enabled. Existing
  fixture contents and integrity digests are unchanged.

All additions are backward compatible: existing functions keep their
signatures and defaults, and objects created by segmantR 0.1.0 remain valid.
See `system.file("interop", "INTEROP.md", package = "segmantR")` for the
contracts, migration notes and security boundaries.

## Interchange (`segmantR-interchange-v1`)

* Public JSON Schema family under `inst/schema/segmantR-interchange-v1/`
  (manifest, image, mask, legend, integrity, GeoJSON profile, run, runtime,
  protocol, capabilities, dataset manifest, model card, QuPath `run.json`,
  StarDist model manifest).
* `sg_interchange_capabilities()`, `sg_interchange_manifest()`,
  `sg_export_interchange()`, `sg_import_interchange()`,
  `sg_validate_interchange()` and `sg_hash_assets()`: bundles with exact
  integer label TIFF, pixel-edge GeoJSON with stable object ids, legend,
  canonical long-format measurements (CSV, optional Parquet), optional
  OME-TIFF image and RDS, and a SHA-256 `integrity.json` inventory whose
  digest follows the qupflowR bundle rule.
* `sg_image` gains optional `id`, `plane`, `origin`, `bands`,
  `value_semantics`, `source_digest`, `transform_digest`, `provenance`;
  `sg_mask` gains `mask_type`, `legend`, `plane`, `origin`, review state,
  `provenance`, `id`.
* Staged/reviewed workflow with content revisions: `sg_mask_legend()`,
  `sg_mask_revision()`, `sg_mask_status()`, `sg_stage_mask()`,
  `sg_review_mask()`, `sg_replace_mask()`. Imports and predictions are staged;
  reviewed masks are only replaced with the expected revision and
  `overwrite = TRUE`.

## Declarative protocols (`segmantR-protocol-v1`)

* Registry in `inst/protocols/`: `threshold.otsu.v1`,
  `threshold.adaptive.v1`, `threshold.triangle.v1`, `watershed.distance.v1`,
  `watershed.h_minima.v1`, `propagate.voronoi.v1`,
  `postprocess.label-cleanup.v1`, and the optional `stardist.2d.v1`,
  `cellpose.2d.v1`, `mesmer.2d.v1`.
* `sg_protocol_list()`, `sg_protocol_schema()`, `sg_protocol_get()`,
  `sg_protocol_validate()`, `sg_protocol_run()` with schema-valid run
  envelopes that record the exact delegate call; `sg_cleanup_labels()`.
* `sg_select_channel()` with registered band operations, `sg_read_envi()`
  and `sg_envi_info()` for windowed ENVI reads with explicit value semantics.

## Training, models and prediction

* `sg_dataset_manifest()`, `sg_prepare_training_data()` and
  `sg_validate_training_manifest()` with grouped, leakage-free splits.
* `sg_train_stardist()` (optional Python runtime, checked after all data
  checks) and the backend-agnostic `sg_predict_model()`.
* `sg_package_model()` now writes a versioned `model_card.json`,
  `runtime.json`, `dataset_manifest.json`, `license.json` and
  `checksums.sha256` with relative paths (weights keep their directory
  structure or are referenced by hash); `sg_load_model()` checks entry
  names, checksums, card version and backend. Archives from 0.1.0 still load
  (reported as unverified).

## QuPath and StarDist

* `sg_export_qupath()`/`sg_import_qupath()` and readable Groovy templates
  (`inst/qupath/`) for interactive and `QuPath script` runs driven by
  `run.json`; `sg_stardist_capabilities()`, `sg_stardist_manifest()`,
  `sg_stardist_parameter_map()`. Exercised with QuPath 0.7.0 and
  qupath-extension-stardist 0.6.0 in an opt-in test lane.

## Shiny

* `sg_app()` builds the app from package code (protocol form from the
  registry, staged review with explicit overwrite, bundle export);
  `sg_run_app()` launches it. `sg_control_capabilities()` reports the planned
  control service.

## Changes in behaviour

* Attaching the package no longer initialises Python to list backends;
  optional backends are checked when used.
* `sg_segment_propagate()` gains `engine`; the default `"auto"` keeps the
  previous behaviour.
* `sg_apply_corrections()` and `sg_filter_cells()` keep the image binding,
  legend and review history of the input mask.

## Bug fixes

* `sg_segment_threshold(method = "adaptive")` no longer errors with
  "replacement has length zero". The internal integral-image lookup now
  treats out-of-range indices as contributing zero, so adaptive
  thresholding works for all images.
* `sg_read_image()` returned transposed arrays for images read through
  imager or EBImage (both store `[x, y]`); arrays are now `[y, x, channel]`.
* `sg_preprocess()` now keeps the history it documents.
* `sg_segment_cellpose()` works with Cellpose 3.x, whose `eval()` no longer
  accepts `tile`.

# segmantR 0.1.0

* Initial release.
* Classical segmentation: adaptive thresholding, watershed, Voronoi propagation.
* Deep learning wrappers: Cellpose, StarDist, Mesmer (via reticulate).
* Human-in-the-loop annotation and correction workflow.
* Custom model training and portable model export (`.segmantR` archives).
* Feature extraction: intensity, morphology, texture, location.
* Shiny application with six tabs for interactive segmentation workflows.
* Export to GeoJSON, QuPath, CSV, SpatialExperiment.
* Bundled synthetic sample data for demonstrations.
