# Changelog

## segmantR (development version)

- segmantR no longer starts or installs Python by itself. Without a
  configured Python, recent ‘reticulate’ versions download one with
  ‘uv’, and the backend checks (for example
  `sg_protocol_list(check_available = TRUE)` or a StarDist run through
  [`sg_predict_model()`](https://cttir.github.io/segmantR/dev/reference/sg_predict_model.md))
  triggered that. The Cellpose, StarDist and Mesmer backends now count
  as available only when Python is already running, when
  `RETICULATE_PYTHON` or `RETICULATE_PYTHON_ENV` names one, or with
  `options(segmantR.python = TRUE)`; see “Selecting Python” in
  [`?sg_setup_python`](https://cttir.github.io/segmantR/dev/reference/sg_setup_python.md).

- [`sg_segment_threshold()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_threshold.md)
  treats `NA` pixels, such as nodata values, as background. An `NA`
  inside an object used to stop the morphological opening with an error,
  and with `method = "adaptive"` it blanked the part of the image below
  and to the right of it.

- The TIFF reader behind
  [`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md)
  and dataset and training masks reads compressed single-sample uint32
  values from 2^31 as unsigned (they came back negative or `NA`),
  compressed float images (which failed) and compressed palette images
  as their colour indices (as uncompressed ones already were) instead of
  colour map values. Planar-separate multi-sample images, which came
  back with wrong values, and images with fewer than 8 bits per sample
  or compressed 64-bit samples now signal a `DTYPE_MISMATCH` error.

- On R \< 4.5, SHA-256 digests from the ‘openssl’ fallback are plain
  strings like those of
  [`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html) instead
  of carrying the class `"hash"`, and
  [`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html) is
  looked up at run time, so checks on older R no longer report it as a
  missing object.

- [`sg_roi_write_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_qupath.md)
  records the level of the written coordinates as `annotatr_level` in
  the feature metadata, as
  [`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_geojson.md)
  does in its `level` property; it used to record the ROI’s own level.

- A layer style with named colours keeps the colours of labels that are
  not in the layer yet; adding another label first used to drop them, so
  those labels later received palette colours.

- The Macenko stain estimate of
  [`sg_stain_deconvolve()`](https://cttir.github.io/segmantR/dev/reference/sg_stain_deconvolve.md)
  (the default `method`) points the principal axes into the positive
  optical density octant before it measures stain angles. With the
  arbitrary sign of the axes, the stain vectors were wrong for about
  half of simulated H&E images and haematoxylin and eosin were mixed;
  results change for those images.

- [`sg_create_annotation_task()`](https://cttir.github.io/segmantR/dev/reference/sg_create_annotation_task.md)
  with both `region` and `initial_mask` crops the mask to the region
  before scoring patches; the region-relative patches used to be scored
  on the wrong part of the mask.

- Compressed (for example LZW) multi-sample TIFFs such as RGB images are
  read with the integer values of their declared dtype, as uncompressed
  ones are; they came back scaled to \[0, 1\]. This affects
  [`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md)
  and dataset and training masks stored as TIFF.

- Every exported function has an example. The examples run except where
  they need Python
  ([`sg_setup_python()`](https://cttir.github.io/segmantR/dev/reference/sg_setup_python.md),
  [`sg_train_cellpose()`](https://cttir.github.io/segmantR/dev/reference/sg_train_cellpose.md),
  [`sg_active_learning_loop()`](https://cttir.github.io/segmantR/dev/reference/sg_active_learning_loop.md)
  and the Cellpose, StarDist and Mesmer segmentation calls, which stay
  in `\dontrun{}`); Shiny launches run only in interactive sessions. The
  help topics `example_images` and `example_masks`, which described data
  objects that do not exist, are folded into
  [`?sg_example_image`](https://cttir.github.io/segmantR/dev/reference/sg_example_image.md).
  [`sgCanvasOutput()`](https://cttir.github.io/segmantR/dev/reference/sgCanvasOutput.md)
  and
  [`renderSgCanvas()`](https://cttir.github.io/segmantR/dev/reference/sgCanvasOutput.md)
  explain a missing ‘htmlwidgets’. Unused packages are dropped from
  Suggests.

- The README and `CITATION.cff` no longer cite the Zenodo DOI, which is
  not registered yet; it will be added once the Zenodo record is
  published.

- [`sg_run_app()`](https://cttir.github.io/segmantR/dev/reference/sg_run_app.md)
  restores the previous value of the option `segmantR.app_env` when the
  app stops.

- [`sg_example_image()`](https://cttir.github.io/segmantR/dev/reference/sg_example_image.md)
  and
  [`sg_example_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_example_mask.md)
  no longer reset the caller’s random number stream; the example data
  are unchanged.

- PNG export in
  [`sg_export_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_export_mask.md)
  closes its graphics device when drawing fails.

- [`sg_setup_python()`](https://cttir.github.io/segmantR/dev/reference/sg_setup_python.md)
  installs `cellpose` rather than the `cellpose[gui]` desktop extra when
  `gpu = TRUE`, installs into the environment type it created, and names
  `use_condaenv()` after creating a conda environment.

- A layer created without labels keeps the colour of its style, so the
  first ROI label added with
  [`sg_roi_layer_add()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_add.md)
  receives it instead of a palette colour.

- ROI constructors match the reserved `...` names `author`, `source` and
  `id` exactly; attributes such as `idx` or `source_file` no longer
  overwrite them by partial matching.

- [`sg_roi_intersect()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md)
  and
  [`sg_roi_difference()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md)
  return an ROI with an empty polygon when the result is empty. They
  used to warn about a repaired geometry and return an ROI without
  geometry that broke
  [`sg_roi_area()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_area.md),
  [`sg_roi_centroid()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_centroid.md)
  and layer summaries.

- [`sg_read_envi()`](https://cttir.github.io/segmantR/dev/reference/sg_read_envi.md)
  keeps a matrix when one band is read from a one-row or one-column
  window; it used to drop to a vector and fail.

- uint32 TIFF planes and 4-byte ENVI integers decode the value 2^31 (and
  ENVI int32 -2^31) exactly instead of as `NA`. 8- and 16-bit reading is
  unchanged.

- [`sg_create_annotation_task()`](https://cttir.github.io/segmantR/dev/reference/sg_create_annotation_task.md)
  records the image’s `id` as `image_id` instead of `NA`.

- [`sg_prepare_training_data()`](https://cttir.github.io/segmantR/dev/reference/sg_prepare_training_data.md)
  rounds tile offsets back to pixel indices instead of truncating them,
  so tiles of images with a fractional `downsample` are no longer cut
  one pixel too high or too far left.

- Grouped dataset splits
  ([`sg_dataset_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_dataset_manifest.md),
  [`sg_prepare_training_data()`](https://cttir.github.io/segmantR/dev/reference/sg_prepare_training_data.md))
  no longer leave a requested split empty when there are enough groups
  to fill every split, for example three subjects with
  `split = c(train = 0.8, validation = 0.1, test = 0.1)`.

- [`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_geojson.md)
  records the level of the written coordinates in each feature’s `level`
  property. It used to record the ROI’s own level, so
  [`sg_roi_read_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_read_geojson.md)
  rescaled ROIs drawn at a level other than the export level.

- [`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md)
  accepts bundles whose integer image was exported with `image_tiff`;
  the float64 TIFF planes are restored to integer storage before the
  content digest is checked.

- [`sg_roi_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask.md)
  no longer rasterises right triangles (and other polygons with two
  distinct x and y values) as their bounding rectangle; the rectangle
  fast path now requires four corners and axis-aligned edges.

- The morphological opening in
  [`sg_segment_threshold()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_threshold.md)
  (default `open = 5`) clips its erosion and dilation windows at the
  image edge. Objects touching the border keep their full extent instead
  of losing a band of `open %/% 2` pixels, border objects at least
  `open %/% 2 + 1` pixels thick survive the opening, and images smaller
  than `open` in a dimension (for example 3 x 10 pixels) no longer fail.

- Bilinear upsampling in
  [`sg_preprocess()`](https://cttir.github.io/segmantR/dev/reference/sg_preprocess.md)
  no longer extrapolates at the top and left edges, where it could
  produce values outside the input range (for example negative
  intensities).

- The `"ruifrok"` stain matrix of
  [`sg_stain_deconvolve()`](https://cttir.github.io/segmantR/dev/reference/sg_stain_deconvolve.md)
  (also the Macenko fallback) now holds the haematoxylin and eosin
  vectors; its second vector was the DAB vector, so the `eosin` channel
  measured DAB.

- [`sg_stain_deconvolve()`](https://cttir.github.io/segmantR/dev/reference/sg_stain_deconvolve.md)
  reads stain matrices column-wise, as documented, for the built-in
  Ruifrok vectors, Macenko estimates and user matrices alike; it used to
  mix rows and columns and returned wrong concentrations. Macenko
  estimates put haematoxylin first.

- Morphology features no longer fail on single-pixel cells (shape
  descriptors are `NA` there), which also fixes
  [`sg_filter_cells()`](https://cttir.github.io/segmantR/dev/reference/sg_filter_cells.md)
  and CSV export of such masks. Line-shaped cells get eccentricity 1
  instead of `NA`, so `max_eccentricity` removes them. Solidity uses the
  convex hull of the pixel squares and circularity is capped at 1; both
  could exceed 1 before.

- [`sg_evaluate_segmentation()`](https://cttir.github.io/segmantR/dev/reference/sg_evaluate_segmentation.md)
  reports `ap50` and `ap75` as the instance-segmentation average
  precision TP / (TP + FP + FN) used by Cellpose and StarDist; they
  previously repeated the F1 score.

- [`sg_segment_watershed()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_watershed.md)
  computes the distance transform inside the foreground and floods only
  foreground pixels, level by level along the surface. Previously every
  image came back as one object covering the whole plane, and
  `membrane_channel` had no effect; results change.

- The watershed fix above and the morphological opening fixes change the
  masks of the bundled protocols `watershed.distance.v1`,
  `watershed.h_minima.v1`, `threshold.otsu.v1`, `threshold.triangle.v1`
  and `threshold.adaptive.v1`, although their ids, versions and protocol
  digests are unchanged. Run records tell the results apart by
  `runtime$segmantR_version`.

- Standardize the named v5 package logo across README, documentation
  pages and available application headers, with matching light and dark
  artwork.

- [`sg_image_channels()`](https://cttir.github.io/segmantR/dev/reference/sg_image_channels.md),
  [`sg_read_window()`](https://cttir.github.io/segmantR/dev/reference/sg_read_window.md),
  [`sg_read_field()`](https://cttir.github.io/segmantR/dev/reference/sg_read_field.md)
  and
  [`sg_read_fields()`](https://cttir.github.io/segmantR/dev/reference/sg_read_fields.md)
  read rectangular pixel windows of single channels from multi-channel
  TIFF/QPTIFF images through GDAL;
  [`sg_display_range()`](https://cttir.github.io/segmantR/dev/reference/sg_display_range.md),
  [`sg_slide_display_ranges()`](https://cttir.github.io/segmantR/dev/reference/sg_slide_display_ranges.md)
  and
  [`sg_display_levels()`](https://cttir.github.io/segmantR/dev/reference/sg_display_levels.md)
  derive display ranges from slide samples and from the signal of
  called-positive cells. imager moves to Suggests.

- Adds independent `sg_roi_*` histology annotation objects, layers,
  project provenance, geometry operations, GeoJSON/QuPath exchange and
  integer ROI masks. A metadata-only frame records explicit pyramid
  dimensions and pixel calibration. These APIs do not require
  hyperannotatR (formerly annotatR) or an HSI backend. Existing
  instance-mask APIs remain unchanged. QuPath UUID derivation and legacy
  metadata keys are retained.

- Direct QuPath ROI exports retain imported measurements, metadata,
  image planes and nucleus geometry. ROI mask statistics reject invalid
  physical calibration.

- Added an independent cell annotation canvas adapted from annotatR,
  with rectangle, polygon, freehand, circle, edit and erase tools.
  Corrections preserve image binding, reject overlaps and stale
  revisions, and enter the existing staged review workflow. No
  hyperannotatR dependency is required.

- The
  [`sg_interchange_capabilities()`](https://cttir.github.io/segmantR/dev/reference/sg_interchange_capabilities.md)
  profile `partner_annotatR` is renamed `partner_hyperannotatR` for the
  planned HSI partner contract; its status remains `planned`.

- Physical areas use current array pixel calibration once after
  resampling. Level-0 geometry and OME spacing are unchanged; corrected
  downsampled measurement assets have new digests and require explicit
  revalidation. Resampling rejects nonfinite targets and unsupported
  anisotropic pixels before interpolation.

- PNG mask previews allocate colours for present labels, including
  sparse IDs. Label cleanup avoids unnecessary integer overflow and
  rejects splits that would exhaust the supported label range before
  changing labels.

- Generate canonical numeric digits from the exact binary64 value and
  apply explicit ties-to-even rounding, avoiding platform-dependent
  printf behaviour. Exact binary inputs cover Windows halfway cases and
  display-separator changes.

- Canonical JSON numbers now use the shortest round-tripping decimal for
  large integer-valued doubles, use JSON parsing consistently across
  platforms, and ignore the display decimal separator. Corrected text
  changes digests for affected values; re-export affected manifests as
  new versions rather than rewriting historical checksums. Existing
  authenticated fixtures are unchanged.

- Count and process only present mask labels without phantom feature or
  export rows. Filtering still renumbers retained objects and now maps
  border flags to those output labels. Reject non-finite, fractional,
  negative and out-of-range labels before integer conversion; full
  uint32 IDs above 2147483647 remain unsupported.

- Preserve the exact bytes of authenticated synthetic QuPath fixtures
  during Git checkout, including when automatic CRLF conversion is
  enabled. Existing fixture contents and integrity digests are
  unchanged.

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
