# Ring (annulus) along an ROI margin

Build a band straddling an ROI's boundary – the natural shape for a
"penumbra" region along an injury or wound margin. The ring extends
`outer` units outside the boundary and `inner` units inside it, formed
as the set difference of the outward and inward buffers.

## Usage

``` r
sg_roi_ring(
  roi,
  outer,
  inner = 0,
  label = roi$label,
  call = rlang::caller_env()
)
```

## Arguments

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md).

- outer:

  Non-negative outward width (dilation) of the ring.

- inner:

  Non-negative inward width (erosion) of the ring. Default `0`, a purely
  external band.

- label:

  Label for the derived ring ROI. Default the source ROI's label.

- call:

  The calling environment, for error reporting.

## Value

A derived
[sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md) (an
annulus) with `source = "derived"`.

## See also

[`sg_roi_buffer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_buffer.md),
[`sg_roi_difference()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md)

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
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois_overlap.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_transform.md)

## Examples

``` r
inj <- sg_roi_rect(10, 10, 20, 20, label = "injury")
sg_roi_ring(inj, outer = 3, label = "penumbra")
#> <sg_roi> penumbra (POLYGON)
#> id: "roi_000000044"  |  level: 0  |  source: derived
#> bbox: [7, 7] - [23, 23]
```
