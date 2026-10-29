# Read ROIs from a QuPath GeoJSON file

Reads QuPath 0.4+ exports (a FeatureCollection or a bare feature array)
and the legacy annotatR 0.1 dialect. `classification.name` (or the
joined `names` of a derived class, e.g. `"Tumor: Positive"`) becomes the
ROI label, the classification colour the layer style colour, and
features without a classification are labelled `"unclassified"`.
Everything else QuPath carries is kept, never invented, under each ROI's
`attributes$qupath`: the object id and type, name, measurements (with
explicit `value_state`), the image plane (zero-based `c`, `z`, `t`;
`c = NA` for all channels), metadata, a nucleus geometry, and
`roi_native = "ellipse"` with `geometry_fidelity = "approximated"` for
polygonised ellipses. An segmantR id stored in
`metadata.annotatr_roi_id` is restored as the ROI id.

## Usage

``` r
sg_roi_read_qupath(
  path,
  layer_name = "qupath",
  level = 0L,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Path to a QuPath GeoJSON file.

- layer_name:

  Layer name for the imported ROIs. Default `"qupath"`.

- level:

  Integer level to record on the ROIs. Default `0`.

- call:

  The calling environment, for error reporting.

## Value

An
[sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md).

## See also

Other io:
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_from_geojson.md),
[`sg_roi_read_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_read_geojson.md),
[`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_geojson.md),
[`sg_roi_write_qupath()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_write_qupath.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
p <- tempfile(fileext = ".geojson")
sg_roi_write_qupath(sg_roi_project(sg_roi_frame(c(20, 20)), lyr), p)
sg_roi_layer_n(sg_roi_read_qupath(p))
#> [1] 1
```
