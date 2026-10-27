# Write a project's ROIs to GeoJSON

Write a project's ROIs to GeoJSON

## Usage

``` r
sg_roi_write_geojson(
  project,
  path,
  layer = NULL,
  level = 0L,
  flip_y = FALSE,
  overwrite = FALSE,
  call = rlang::caller_env()
)
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- path:

  Output file path.

- layer:

  Optional layer filter.

- level:

  Integer pyramid level for the coordinates. Default `0`.

- flip_y:

  Logical; invert the y-axis (for GIS-oriented consumers). Default
  `FALSE` (image orientation preserved). The consequence is documented
  in the interop vignette.

- overwrite:

  Logical; overwrite an existing file. Default `FALSE`.

- call:

  The calling environment, for error reporting.

## Value

The output path, invisibly.

## See also

[`sg_roi_read_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_read_geojson.md),
[`sg_roi_write_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_qupath.md)

Other io:
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_from_geojson.md),
[`sg_roi_read_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_read_geojson.md),
[`sg_roi_read_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_read_qupath.md),
[`sg_roi_write_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_qupath.md)

## Examples

``` r
p <- withr::local_tempfile(fileext = ".geojson")
sg_roi_write_geojson(sg_roi_project(sg_roi_frame(c(20, 20)), sg_roi_layer_add(sg_roi_layer("tissue"), sg_roi_rect(2, 2, 8, 8, "tissue"))), p)
```
