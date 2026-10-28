# segmantR (development version)

* `sg_import_interchange()` accepts bundles whose integer image was
  exported with `image_tiff`; the float64 TIFF planes are restored to
  integer storage before the content digest is checked.

* `sg_roi_mask()` no longer rasterises right triangles (and other
  polygons with two distinct x and y values) as their bounding rectangle;
  the rectangle fast path now requires four corners and axis-aligned edges.

* The morphological opening in `sg_segment_threshold()` (default
  `open = 5`) dilates up to the image edge, so objects touching the
  border keep their full extent instead of losing a band of
  `open %/% 2` pixels.

* Bilinear upsampling in `sg_preprocess()` no longer extrapolates at the
  top and left edges, where it could produce values outside the input
  range (for example negative intensities).

* The `"ruifrok"` stain matrix of `sg_stain_deconvolve()` (also the
  Macenko fallback) now holds the haematoxylin and eosin vectors; its
  second vector was the DAB vector, so the `eosin` channel measured DAB.

* `sg_stain_deconvolve()` reads stain matrices column-wise, as documented,
  for the built-in Ruifrok vectors, Macenko estimates and user matrices
  alike; it used to mix rows and columns and returned wrong
  concentrations. Macenko estimates put haematoxylin first.

* Morphology features no longer fail on single-pixel cells (shape
  descriptors are `NA` there), which also fixes `sg_filter_cells()` and
  CSV export of such masks. Line-shaped cells get eccentricity 1 instead
  of `NA`, so `max_eccentricity` removes them. Solidity uses the convex
  hull of the pixel squares and circularity is capped at 1; both could
  exceed 1 before.

* `sg_evaluate_segmentation()` reports `ap50` and `ap75` as the
  instance-segmentation average precision TP / (TP + FP + FN) used by
  Cellpose and StarDist; they previously repeated the F1 score.

* `sg_segment_watershed()` computes the distance transform inside the
  foreground and floods only foreground pixels, level by level along the
  surface. Previously every image came back as one object covering the
  whole plane, and `membrane_channel` had no effect; results change.

* Standardize the named v5 package logo across README, documentation pages
  and available application headers, with matching light and dark artwork.

* `sg_image_channels()`, `sg_read_window()`, `sg_read_field()` and
  `sg_read_fields()` read rectangular pixel windows of single channels from
  multi-channel TIFF/QPTIFF images through GDAL; `sg_display_range()`,
  `sg_slide_display_ranges()` and `sg_display_levels()` derive display
  ranges from slide samples and from the signal of called-positive cells.
  imager moves to Suggests.
* Adds independent `sg_roi_*` histology annotation objects, layers, project
  provenance, geometry operations, GeoJSON/QuPath exchange and integer ROI masks.
  A metadata-only frame records explicit pyramid dimensions and pixel calibration.
  These APIs do not require hyperannotatR (formerly annotatR) or an HSI backend.
  Existing instance-mask APIs remain unchanged. QuPath UUID derivation and legacy
  metadata keys are retained.
* Direct QuPath ROI exports retain imported measurements, metadata, image planes
  and nucleus geometry. ROI mask statistics reject invalid physical calibration.

* Added an independent cell annotation canvas adapted from annotatR, with
  rectangle, polygon, freehand, circle, edit and erase tools. Corrections
  preserve image binding, reject overlaps and stale revisions, and enter
  the existing staged review workflow. No hyperannotatR dependency is required.

* The `sg_interchange_capabilities()` profile `partner_annotatR` is renamed
  `partner_hyperannotatR` for the planned HSI partner contract; its status
  remains `planned`.

* Physical areas use current array pixel calibration once after resampling.
  Level-0 geometry and OME spacing are unchanged; corrected downsampled
  measurement assets have new digests and require explicit revalidation.
  Resampling rejects nonfinite targets and unsupported anisotropic pixels
  before interpolation.

* PNG mask previews allocate colors for present labels, including sparse IDs.
  Label cleanup avoids unnecessary integer overflow and rejects splits that
  would exhaust the supported label range before changing labels.

* Generate canonical numeric digits from the exact binary64 value and apply
  explicit ties-to-even rounding, avoiding platform-dependent printf behavior.
  Exact binary inputs cover Windows halfway cases and display-separator changes.

* Canonical JSON numbers now use the shortest round-tripping decimal for
  large integer-valued doubles, use JSON parsing consistently across platforms,
  and ignore the display decimal separator. Corrected text changes digests for
  affected values; re-export affected manifests as new versions rather than
  rewriting historical checksums. Existing authenticated fixtures are unchanged.

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
