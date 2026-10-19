# Create a point ROI

Create a point ROI

## Usage

``` r
sg_roi_point(x, y, label, level = 0L, ..., call = rlang::caller_env())
```

## Arguments

- x, y:

  Numeric coordinates of the point, in image pixels.

- label:

  Single string class label.

- level:

  Integer pyramid level the coordinates refer to. Default `0`.

- ...:

  Additional named attributes stored on the ROI. The reserved names
  `author`, `source`, and `id` set those fields; all others become user
  attributes.

- call:

  The calling environment, for error reporting.

## Value

An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md)
with `POINT` geometry.

## See also

[`sg_roi_rect()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rect.md),
[`sg_roi_polygon()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_polygon.md)

Other rois:
[`sg_roi_area()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_area.md),
[`sg_roi_bbox()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_bbox.md),
[`sg_roi_centroid()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_centroid.md),
[`sg_roi_circle()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_circle.md),
[`sg_roi_ellipse()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_ellipse.md),
[`sg_roi_freehand()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_freehand.md),
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_from_geojson.md),
[`sg_roi_from_sf()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_from_sf.md),
[`sg_roi_polygon()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_polygon.md),
[`sg_roi_rect()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rect.md)

## Examples

``` r
r <- sg_roi_point(10, 20, label = "cell")
sg_roi_centroid(r)
#> [1] 10 20
```
