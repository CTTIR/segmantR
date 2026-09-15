# Export segmantR objects or a StarDist protocol for QuPath

Writes a QuPath program directory: a declarative `run.json` (schema
`segmantR-qupath-run-v1`), the readable Groovy templates, the resources
they bind (a neutral interchange bundle or a hashed model copy), a
`run_export.json` for the way back, `checksums.sha256` and a `README.md`
with the interactive and command-line invocations. segmantR never starts
QuPath, Java or Groovy itself.

## Usage

``` r
sg_export_qupath(
  x,
  destination,
  ...,
  image = NULL,
  image_name = NULL,
  model = NULL,
  region_policy = c("whole_image", "selected_annotations", "all_annotations"),
  save_policy = c("none", "project"),
  object_type = c("detection", "annotation", "cell"),
  require_calibration = TRUE,
  min_qupath_version = "0.5.0",
  allow_unsupported = FALSE,
  overwrite = FALSE
)
```

## Arguments

- x:

  An `sg_mask`, `sg_run`, list with `mask`/`image`, or a StarDist
  protocol id / `sg_protocol`.

- destination:

  Output directory (must not exist or be empty).

- ...:

  Protocol parameter overrides for the `stardist` task.

- image:

  `sg_image` describing the QuPath image (size, pixel size, plane,
  channels). Required for the `stardist` task.

- image_name:

  Name of the image in the QuPath project (checked by the templates);
  `NULL` skips the name check.

- model:

  StarDist model file/directory or `sg_trained_model` for the `stardist`
  task.

- region_policy:

  `"whole_image"`, `"selected_annotations"` or `"all_annotations"`.

- save_policy:

  `"none"` (default) or `"project"`.

- object_type:

  QuPath object type for imported or exported objects.

- require_calibration:

  Logical; templates refuse uncalibrated images.

- min_qupath_version:

  Minimum QuPath version written to `run.json`.

- allow_unsupported:

  Logical; allow non-default parameters that the QuPath extension cannot
  honour (they are still listed).

- overwrite:

  Logical; replace an existing program directory created by segmantR.

## Value

An `sg_qupath_program` (invisibly) with `path`, `task`, `run` (parsed
`run.json`) and `commands` (headless command lines).

## Details

- For an `sg_mask`, `sg_run` or list with a mask, the task is `import`:
  the mask is exported with
  [`sg_export_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_export_interchange.md)
  into `bundle/` (integer TIFF, exact GeoJSON with object ids, legend,
  measurements) and `segmantR_import.groovy` adds the objects to the
  open image after checking size, calibration, plane, SHA-256 and id
  collisions.

- For a StarDist protocol (`"stardist.2d.v1"` or an `sg_protocol`), the
  task is `stardist`: parameters are mapped with
  [`sg_stardist_parameter_map()`](https://cttir.github.io/segmantR/dev/reference/sg_stardist_parameter_map.md)
  (unsupported non-default options are errors unless
  `allow_unsupported = TRUE`, and are always listed in `run.json`), the
  model is copied into `models/` and its digest is recorded for
  verification by the template.

## Examples

``` r
m <- sg_example_mask("fluorescence_nuclei")
img <- sg_example_image("fluorescence_nuclei")
prog <- sg_export_qupath(m, tempfile("qupath"), image = img,
                         require_calibration = FALSE)
prog$commands[["import"]]
#> [1] "QuPath script --project=<project.qpproj> --image=\"<image name>\" --args=run.json segmantR_import.groovy"
```
