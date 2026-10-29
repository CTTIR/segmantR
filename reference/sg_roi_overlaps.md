# Test whether two ROIs intersect

Test whether two ROIs intersect

## Usage

``` r
sg_roi_overlaps(roi1, roi2, call = rlang::caller_env())
```

## Arguments

- roi1, roi2:

  [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md)
  objects.

- call:

  The calling environment, for error reporting.

## Value

A logical scalar.

## See also

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/reference/sg_roi_buffer.md),
[`sg_roi_check_containment()`](https://cttir.github.io/segmantR/reference/sg_roi_check_containment.md),
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_check_geometry.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/reference/sg_roi_clamp.md),
[`sg_roi_contains()`](https://cttir.github.io/segmantR/reference/sg_roi_contains.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/reference/sg_roi_distance.md),
[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_fix_geometry.md),
[`sg_roi_flip_y()`](https://cttir.github.io/segmantR/reference/sg_roi_flip_y.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/reference/sg_roi_ring.md),
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/reference/sg_roi_rois_overlap.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/reference/sg_roi_transform.md)

## Examples

``` r
a <- sg_roi_rect(0, 0, 4, 4, label = "a")
sg_roi_overlaps(a, sg_roi_rect(2, 2, 6, 6, label = "b"))
#> [1] TRUE
sg_roi_overlaps(a, sg_roi_rect(10, 0, 14, 4, label = "c"))
#> [1] FALSE
```
