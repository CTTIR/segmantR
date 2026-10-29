# Create a circular ROI

The circle is approximated by a regular polygon of `n_seg` segments.

## Usage

``` r
sg_roi_circle(
  x,
  y,
  r,
  label,
  level = 0L,
  n_seg = 64L,
  ...,
  call = rlang::caller_env()
)
```

## Arguments

- x, y:

  Numeric centre coordinates in image pixels.

- r:

  Positive numeric radius in pixels.

- label:

  Single string class label.

- level:

  Integer pyramid level the coordinates refer to. Default `0`.

- n_seg:

  Integer number of polygon segments approximating the circle.

- ...:

  Additional named attributes stored on the ROI. The reserved names
  `author`, `source`, and `id` set those fields; all others become user
  attributes.

- call:

  The calling environment, for error reporting.

## Value

An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md) with
`POLYGON` geometry and `attributes$shape = "circle"`, so exports can
flag the polygon as an approximation.

## See also

Other rois:
[`sg_roi_area()`](https://cttir.github.io/segmantR/reference/sg_roi_area.md),
[`sg_roi_bbox()`](https://cttir.github.io/segmantR/reference/sg_roi_bbox.md),
[`sg_roi_centroid()`](https://cttir.github.io/segmantR/reference/sg_roi_centroid.md),
[`sg_roi_ellipse()`](https://cttir.github.io/segmantR/reference/sg_roi_ellipse.md),
[`sg_roi_freehand()`](https://cttir.github.io/segmantR/reference/sg_roi_freehand.md),
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_from_geojson.md),
[`sg_roi_from_sf()`](https://cttir.github.io/segmantR/reference/sg_roi_from_sf.md),
[`sg_roi_point()`](https://cttir.github.io/segmantR/reference/sg_roi_point.md),
[`sg_roi_polygon()`](https://cttir.github.io/segmantR/reference/sg_roi_polygon.md),
[`sg_roi_rect()`](https://cttir.github.io/segmantR/reference/sg_roi_rect.md)

## Examples

``` r
r <- sg_roi_circle(50, 50, r = 10, label = "nucleus")
```
