# Flip an ROI's y-axis

Convert between image orientation (top-left origin, y down) and GIS
orientation (bottom-left origin, y up). Self-inverse.

## Usage

``` r
sg_roi_flip_y(roi, height, call = rlang::caller_env())
```

## Arguments

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md).

- height:

  Numeric image height in pixels at the ROI's reference level.

- call:

  The calling environment, for error reporting.

## Value

An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md)
with the y-axis flipped.

## See also

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_buffer.md),
[`sg_roi_check_containment()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_containment.md),
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_geometry.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_clamp.md),
[`sg_roi_contains()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_contains.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_distance.md),
[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_fix_geometry.md),
[`sg_roi_overlaps()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_overlaps.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_ring.md),
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois_overlap.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_transform.md)

## Examples

``` r
sg_roi_flip_y(sg_roi_rect(0, 0, 10, 5, label = "a"), height = 100)
#> <sg_roi> a (POLYGON)
#> id: "roi_000000012"  |  level: 0  |  source: manual
#> bbox: [0, 95] - [10, 100]
```
