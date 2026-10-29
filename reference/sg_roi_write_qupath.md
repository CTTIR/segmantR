# Write a project's ROIs as QuPath GeoJSON

The default `dialect = "qupath"` writes what QuPath 0.4 and later read
natively (verified with QuPath 0.7.0): `objectType`, `classification`
with an `[r, g, b]` colour, `isLocked` for locked ROIs, a deterministic
UUID per ROI as the feature id (QuPath replaces non-UUID ids), and
segmantR's own ROI id, layer, source and level in `properties.metadata`.
`dialect = "legacy"` writes the annotatR 0.1 form (`object_type`, signed
`colorRGB`), which QuPath still reads with a deprecation warning.

## Usage

``` r
sg_roi_write_qupath(
  project,
  path,
  layer = NULL,
  level = 0L,
  overwrite = FALSE,
  dialect = c("qupath", "legacy"),
  call = rlang::caller_env()
)
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md).

- path:

  Output file path.

- layer:

  Optional layer filter.

- level:

  Integer pyramid level for the coordinates. Default `0`. It is recorded
  as `annotatr_level` in the feature metadata of the `"qupath"` dialect.

- overwrite:

  Logical; overwrite an existing file. Default `FALSE`.

- dialect:

  `"qupath"` (default) or `"legacy"`.

- call:

  The calling environment, for error reporting.

## Value

The output path, invisibly.

## Details

QuPath keeps one colour per classification name, so identical labels
with different layer colours collapse to the first colour QuPath sees.

## See also

[`sg_roi_read_qupath()`](https://cttir.github.io/segmantR/reference/sg_roi_read_qupath.md),
[`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_write_geojson.md)

Other io:
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_from_geojson.md),
[`sg_roi_read_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_read_geojson.md),
[`sg_roi_read_qupath()`](https://cttir.github.io/segmantR/reference/sg_roi_read_qupath.md),
[`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_write_geojson.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
p <- tempfile(fileext = ".geojson")
sg_roi_write_qupath(proj, p)
```
