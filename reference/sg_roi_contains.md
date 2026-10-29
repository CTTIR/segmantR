# Test whether points fall inside an ROI

Test whether points fall inside an ROI

## Usage

``` r
sg_roi_contains(roi, x, y, call = rlang::caller_env())
```

## Arguments

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md).

- x, y:

  Numeric coordinate vectors of equal length.

- call:

  The calling environment, for error reporting.

## Value

A logical vector of length `length(x)`.

## See also

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/reference/sg_roi_buffer.md),
[`sg_roi_check_containment()`](https://cttir.github.io/segmantR/reference/sg_roi_check_containment.md),
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_check_geometry.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/reference/sg_roi_clamp.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/reference/sg_roi_distance.md),
[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_fix_geometry.md),
[`sg_roi_flip_y()`](https://cttir.github.io/segmantR/reference/sg_roi_flip_y.md),
[`sg_roi_overlaps()`](https://cttir.github.io/segmantR/reference/sg_roi_overlaps.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/reference/sg_roi_ring.md),
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/reference/sg_roi_rois_overlap.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/reference/sg_roi_transform.md)

## Examples

``` r
sg_roi_contains(sg_roi_rect(0, 0, 10, 10, label = "a"), c(5, 20), c(5, 20))
#> [1]  TRUE FALSE
```
