# Set operations on ROIs

Combine ROIs geometrically. Each accepts several
[sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md) via
`...`, or a single
[sg_roi_layer](https://cttir.github.io/segmantR/reference/sg_roi.html).
Multi-part results are returned as one ROI with `MULTIPOLYGON` geometry
(the return type is always a single
[sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md)).

## Usage

``` r
sg_roi_union(..., call = rlang::caller_env())

sg_roi_intersect(..., call = rlang::caller_env())

sg_roi_difference(..., call = rlang::caller_env())

sg_roi_symdiff(..., call = rlang::caller_env())
```

## Arguments

- ...:

  Two or more
  [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md), or
  a single
  [sg_roi_layer](https://cttir.github.io/segmantR/reference/sg_roi.html).

- call:

  The calling environment, for error reporting.

## Value

A single
[sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md) with
`source = "derived"`.

## See also

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_buffer.md),
[`sg_roi_check_containment()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_containment.md),
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_geometry.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_clamp.md),
[`sg_roi_contains()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_contains.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_distance.md),
[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_fix_geometry.md),
[`sg_roi_flip_y()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_flip_y.md),
[`sg_roi_overlaps()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_overlaps.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_ring.md),
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois_overlap.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_transform.md)

## Examples

``` r
a <- sg_roi_rect(0, 0, 6, 6, label = "x")
b <- sg_roi_rect(4, 4, 10, 10, label = "x")
sg_roi_area(sg_roi_intersect(a, b))
#> [1] 4
```
