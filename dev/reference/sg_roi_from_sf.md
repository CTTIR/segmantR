# Create an ROI from an existing sf geometry

Create an ROI from an existing sf geometry

## Usage

``` r
sg_roi_from_sf(geometry, label, level = 0L, ..., call = rlang::caller_env())
```

## Arguments

- geometry:

  An `sf`, `sfc`, or `sfg` geometry in image pixel coordinates.

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
wrapping the supplied geometry.

## See also

Other rois:
[`sg_roi_area()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_area.md),
[`sg_roi_bbox()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_bbox.md),
[`sg_roi_centroid()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_centroid.md),
[`sg_roi_circle()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_circle.md),
[`sg_roi_ellipse()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_ellipse.md),
[`sg_roi_freehand()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_freehand.md),
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_from_geojson.md),
[`sg_roi_point()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_point.md),
[`sg_roi_polygon()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_polygon.md),
[`sg_roi_rect()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rect.md)

## Examples

``` r
g <- sf::st_point(c(3, 4))
r <- sg_roi_from_sf(g, label = "imported", source = "imported")
```
