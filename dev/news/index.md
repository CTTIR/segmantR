# Changelog

## segmantR (development version)

All additions are backward compatible: existing functions keep their
signatures and defaults, and objects created by segmantR 0.1.0 remain
valid. See `system.file("interop", "INTEROP.md", package = "segmantR")`
for the contracts, migration notes and security boundaries.

### Interchange (`segmantR-interchange-v1`)

- Public JSON Schema family under `inst/schema/segmantR-interchange-v1/`
  (manifest, image, mask, legend, integrity, GeoJSON profile, run,
  runtime, protocol, capabilities, dataset manifest, model card, QuPath
  `run.json`, StarDist model manifest).
- [`sg_interchange_capabilities()`](https://cttir.github.io/segmantR/dev/reference/sg_interchange_capabilities.md),
  [`sg_interchange_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_interchange_manifest.md),
  [`sg_export_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_export_interchange.md),
  [`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md),
  [`sg_validate_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_validate_interchange.md)
  and
  [`sg_hash_assets()`](https://cttir.github.io/segmantR/dev/reference/sg_hash_assets.md):
  bundles with exact integer label TIFF, pixel-edge GeoJSON with stable
  object ids, legend, canonical long-format measurements (CSV, optional
  Parquet), optional OME-TIFF image and RDS, and a SHA-256
  `integrity.json` inventory whose digest follows the qupflowR bundle
  rule.
- `sg_image` gains optional `id`, `plane`, `origin`, `bands`,
  `value_semantics`, `source_digest`, `transform_digest`, `provenance`;
  `sg_mask` gains `mask_type`, `legend`, `plane`, `origin`, review
  state, `provenance`, `id`.
- Staged/reviewed workflow with content revisions:
  [`sg_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_legend.md),
  [`sg_mask_revision()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_revision.md),
  [`sg_mask_status()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_status.md),
  [`sg_stage_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_review.md),
  [`sg_review_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_review.md),
  [`sg_replace_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_review.md).
  Imports and predictions are staged; reviewed masks are only replaced
  with the expected revision and `overwrite = TRUE`.

### Declarative protocols (`segmantR-protocol-v1`)

- Registry in `inst/protocols/`: `threshold.otsu.v1`,
  `threshold.adaptive.v1`, `threshold.triangle.v1`,
  `watershed.distance.v1`, `watershed.h_minima.v1`,
  `propagate.voronoi.v1`, `postprocess.label-cleanup.v1`, and the
  optional `stardist.2d.v1`, `cellpose.2d.v1`, `mesmer.2d.v1`.
- [`sg_protocol_list()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_list.md),
  [`sg_protocol_schema()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_schema.md),
  [`sg_protocol_get()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_get.md),
  [`sg_protocol_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_validate.md),
  [`sg_protocol_run()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_run.md)
  with schema-valid run envelopes that record the exact delegate call;
  [`sg_cleanup_labels()`](https://cttir.github.io/segmantR/dev/reference/sg_cleanup_labels.md).
- [`sg_select_channel()`](https://cttir.github.io/segmantR/dev/reference/sg_select_channel.md)
  with registered band operations,
  [`sg_read_envi()`](https://cttir.github.io/segmantR/dev/reference/sg_read_envi.md)
  and
  [`sg_envi_info()`](https://cttir.github.io/segmantR/dev/reference/sg_envi_info.md)
  for windowed ENVI reads with explicit value semantics.

### Training, models and prediction

- [`sg_dataset_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_dataset_manifest.md),
  [`sg_prepare_training_data()`](https://cttir.github.io/segmantR/dev/reference/sg_prepare_training_data.md)
  and
  [`sg_validate_training_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_validate_training_manifest.md)
  with grouped, leakage-free splits.
- [`sg_train_stardist()`](https://cttir.github.io/segmantR/dev/reference/sg_train_stardist.md)
  (optional Python runtime, checked after all data checks) and the
  backend-agnostic
  [`sg_predict_model()`](https://cttir.github.io/segmantR/dev/reference/sg_predict_model.md).
- [`sg_package_model()`](https://cttir.github.io/segmantR/dev/reference/sg_package_model.md)
  now writes a versioned `model_card.json`, `runtime.json`,
  `dataset_manifest.json`, `license.json` and `checksums.sha256` with
  relative paths (weights keep their directory structure or are
  referenced by hash);
  [`sg_load_model()`](https://cttir.github.io/segmantR/dev/reference/sg_load_model.md)
  checks entry names, checksums, card version and backend. Archives from
  0.1.0 still load (reported as unverified).

### QuPath and StarDist

- [`sg_export_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_export_qupath.md)/[`sg_import_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_import_qupath.md)
  and readable Groovy templates (`inst/qupath/`) for interactive and
  `QuPath script` runs driven by `run.json`;
  [`sg_stardist_capabilities()`](https://cttir.github.io/segmantR/dev/reference/sg_stardist_capabilities.md),
  [`sg_stardist_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_stardist_manifest.md),
  [`sg_stardist_parameter_map()`](https://cttir.github.io/segmantR/dev/reference/sg_stardist_parameter_map.md).
  Exercised with QuPath 0.7.0 and qupath-extension-stardist 0.6.0 in an
  opt-in test lane.

### Shiny

- [`sg_app()`](https://cttir.github.io/segmantR/dev/reference/sg_app.md)
  builds the app from package code (protocol form from the registry,
  staged review with explicit overwrite, bundle export);
  [`sg_run_app()`](https://cttir.github.io/segmantR/dev/reference/sg_run_app.md)
  launches it.
  [`sg_control_capabilities()`](https://cttir.github.io/segmantR/dev/reference/sg_control_capabilities.md)
  reports the planned control service.

### Changes in behaviour

- Attaching the package no longer initialises Python to list backends;
  optional backends are checked when used.
- [`sg_segment_propagate()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_propagate.md)
  gains `engine`; the default `"auto"` keeps the previous behaviour.
- [`sg_apply_corrections()`](https://cttir.github.io/segmantR/dev/reference/sg_apply_corrections.md)
  and
  [`sg_filter_cells()`](https://cttir.github.io/segmantR/dev/reference/sg_filter_cells.md)
  keep the image binding, legend and review history of the input mask.

### Bug fixes

- `sg_segment_threshold(method = "adaptive")` no longer errors with
  “replacement has length zero”. The internal integral-image lookup now
  treats out-of-range indices as contributing zero, so adaptive
  thresholding works for all images.
- [`sg_read_image()`](https://cttir.github.io/segmantR/dev/reference/sg_read_image.md)
  returned transposed arrays for images read through imager or EBImage
  (both store `[x, y]`); arrays are now `[y, x, channel]`.
- [`sg_preprocess()`](https://cttir.github.io/segmantR/dev/reference/sg_preprocess.md)
  now keeps the history it documents.
- [`sg_segment_cellpose()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_cellpose.md)
  works with Cellpose 3.x, whose
  [`eval()`](https://rdrr.io/r/base/eval.html) no longer accepts `tile`.

## segmantR 0.1.0

- Initial release.
- Classical segmentation: adaptive thresholding, watershed, Voronoi
  propagation.
- Deep learning wrappers: Cellpose, StarDist, Mesmer (via reticulate).
- Human-in-the-loop annotation and correction workflow.
- Custom model training and portable model export (`.segmantR`
  archives).
- Feature extraction: intensity, morphology, texture, location.
- Shiny application with six tabs for interactive segmentation
  workflows.
- Export to GeoJSON, QuPath, CSV, SpatialExperiment.
- Bundled synthetic sample data for demonstrations.
