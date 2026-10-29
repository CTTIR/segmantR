# ROI bounding box

ROI bounding box

## Usage

``` r
sg_roi_bbox(roi, call = rlang::caller_env())
```

## Arguments

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md).

- call:

  The calling environment, for error reporting.

## Value

A numeric vector `c(xmin, ymin, xmax, ymax)` in the ROI's stored
coordinates.

## See also

Other rois:
[`sg_roi_area()`](https://cttir.github.io/segmantR/reference/sg_roi_area.md),
[`sg_roi_centroid()`](https://cttir.github.io/segmantR/reference/sg_roi_centroid.md),
[`sg_roi_circle()`](https://cttir.github.io/segmantR/reference/sg_roi_circle.md),
[`sg_roi_ellipse()`](https://cttir.github.io/segmantR/reference/sg_roi_ellipse.md),
[`sg_roi_freehand()`](https://cttir.github.io/segmantR/reference/sg_roi_freehand.md),
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_from_geojson.md),
[`sg_roi_from_sf()`](https://cttir.github.io/segmantR/reference/sg_roi_from_sf.md),
[`sg_roi_point()`](https://cttir.github.io/segmantR/reference/sg_roi_point.md),
[`sg_roi_polygon()`](https://cttir.github.io/segmantR/reference/sg_roi_polygon.md),
[`sg_roi_rect()`](https://cttir.github.io/segmantR/reference/sg_roi_rect.md)

## Examples

``` r
sg_roi_bbox(sg_roi_circle(50, 50, 10, label = "a"))
#> [1] 40 40 60 60
```
