# Read ROIs from a GeoJSON file

Read ROIs from a GeoJSON file

## Usage

``` r
sg_roi_read_geojson(
  path,
  layer_name = NULL,
  level = 0L,
  flip_y = FALSE,
  height = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Path to a GeoJSON file.

- layer_name:

  Layer name for the imported ROIs; taken from the features' `layer`
  property when `NULL`.

- level:

  Integer level to record when a feature has no `level` property.

- flip_y:

  Logical; invert the y-axis on read. Default `FALSE`.

- height:

  Image height in pixels, required when `flip_y = TRUE`.

- call:

  The calling environment, for error reporting.

## Value

A named list of
[sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md)
objects (one per distinct `layer` property), or a single
[sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md)
when `layer_name` is supplied.

## See also

Other io:
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_from_geojson.md),
[`sg_roi_read_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_read_qupath.md),
[`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_geojson.md),
[`sg_roi_write_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_qupath.md)
