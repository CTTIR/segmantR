# Convert a GeoJSON feature to an ROI

Turn a single parsed GeoJSON feature (a list with `geometry` and
optional `properties`) into an
[sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md). Useful
for consuming interactive drawing output.

## Usage

``` r
sg_roi_from_geojson(
  feature,
  label = NULL,
  level = 0L,
  source = "manual",
  call = rlang::caller_env()
)
```

## Arguments

- feature:

  A parsed GeoJSON feature: a list with a `geometry` element (`type` and
  `coordinates`) and optional `properties`.

- label:

  Single string class label; taken from `properties$label` when `NULL`.

- level:

  Integer pyramid level. Default `0`.

- source:

  Provenance source string. Default `"manual"`.

- call:

  The calling environment, for error reporting.

## Value

An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md).

## See also

Other io:
[`sg_roi_read_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_read_geojson.md),
[`sg_roi_read_qupath()`](https://cttir.github.io/segmantR/reference/sg_roi_read_qupath.md),
[`sg_roi_write_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_write_geojson.md),
[`sg_roi_write_qupath()`](https://cttir.github.io/segmantR/reference/sg_roi_write_qupath.md)

Other rois:
[`sg_roi_area()`](https://cttir.github.io/segmantR/reference/sg_roi_area.md),
[`sg_roi_bbox()`](https://cttir.github.io/segmantR/reference/sg_roi_bbox.md),
[`sg_roi_centroid()`](https://cttir.github.io/segmantR/reference/sg_roi_centroid.md),
[`sg_roi_circle()`](https://cttir.github.io/segmantR/reference/sg_roi_circle.md),
[`sg_roi_ellipse()`](https://cttir.github.io/segmantR/reference/sg_roi_ellipse.md),
[`sg_roi_freehand()`](https://cttir.github.io/segmantR/reference/sg_roi_freehand.md),
[`sg_roi_from_sf()`](https://cttir.github.io/segmantR/reference/sg_roi_from_sf.md),
[`sg_roi_point()`](https://cttir.github.io/segmantR/reference/sg_roi_point.md),
[`sg_roi_polygon()`](https://cttir.github.io/segmantR/reference/sg_roi_polygon.md),
[`sg_roi_rect()`](https://cttir.github.io/segmantR/reference/sg_roi_rect.md)

## Examples

``` r
feat <- list(geometry = list(type = "Polygon",
  coordinates = list(list(c(0, 0), c(4, 0), c(4, 4), c(0, 4), c(0, 0)))))
sg_roi_from_geojson(feat, label = "region")
#> <sg_roi> region (POLYGON)
#> id: "roi_000000020"  |  level: 0  |  source: manual
#> bbox: [0, 0] - [4, 4]
```
