# ROI area

ROI area

## Usage

``` r
sg_roi_area(
  roi,
  level = 0L,
  units = c("px", "physical"),
  call = rlang::caller_env()
)
```

## Arguments

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md).

- level:

  Integer pyramid level at which to express the area. Default `0`.

- units:

  Either `"px"` (pixels squared, the default) or `"physical"`. Physical
  units require a `pixel_size` attribute on the ROI.

- call:

  The calling environment, for error reporting.

## Value

A numeric scalar area, or `NA_real_` for non-areal geometry (points,
lines).

## See also

Other rois:
[`sg_roi_bbox()`](https://cttir.github.io/segmantR/reference/sg_roi_bbox.md),
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
sg_roi_area(sg_roi_rect(0, 0, 10, 5, label = "a"))
#> [1] 50
```
