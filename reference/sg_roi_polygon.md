# Create a polygon ROI

Create a polygon ROI

## Usage

``` r
sg_roi_polygon(
  coords,
  label,
  level = 0L,
  hole = NULL,
  ...,
  call = rlang::caller_env()
)
```

## Arguments

- coords:

  Either a two-column numeric matrix of exterior-ring vertices, or a
  list of such matrices where the first is the exterior ring and any
  others are holes. Rings are closed automatically.

- label:

  Single string class label.

- level:

  Integer pyramid level the coordinates refer to. Default `0`.

- hole:

  Optional list of two-column matrices giving additional holes, combined
  with any holes supplied via `coords`.

- ...:

  Additional named attributes stored on the ROI. The reserved names
  `author`, `source`, and `id` set those fields; all others become user
  attributes.

- call:

  The calling environment, for error reporting.

## Value

An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md) with
`POLYGON` geometry.

## See also

Other rois:
[`sg_roi_area()`](https://cttir.github.io/segmantR/reference/sg_roi_area.md),
[`sg_roi_bbox()`](https://cttir.github.io/segmantR/reference/sg_roi_bbox.md),
[`sg_roi_centroid()`](https://cttir.github.io/segmantR/reference/sg_roi_centroid.md),
[`sg_roi_circle()`](https://cttir.github.io/segmantR/reference/sg_roi_circle.md),
[`sg_roi_ellipse()`](https://cttir.github.io/segmantR/reference/sg_roi_ellipse.md),
[`sg_roi_freehand()`](https://cttir.github.io/segmantR/reference/sg_roi_freehand.md),
[`sg_roi_from_geojson()`](https://cttir.github.io/segmantR/reference/sg_roi_from_geojson.md),
[`sg_roi_from_sf()`](https://cttir.github.io/segmantR/reference/sg_roi_from_sf.md),
[`sg_roi_point()`](https://cttir.github.io/segmantR/reference/sg_roi_point.md),
[`sg_roi_rect()`](https://cttir.github.io/segmantR/reference/sg_roi_rect.md)

## Examples

``` r
sq <- matrix(c(0, 0, 10, 0, 10, 10, 0, 10), ncol = 2, byrow = TRUE)
r <- sg_roi_polygon(sq, label = "region")
```
