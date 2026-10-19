# Transform an ROI between pyramid levels using real image dimensions

Unlike
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rescale.md)
(which assumes a power-of-two pyramid), this uses the actual level
dimensions of an
[sg_roi_frame](https://cttir.github.io/segmantR/reference/sg_roi.html),
so it is exact for pyramids with any downsampling ratio.

## Usage

``` r
sg_roi_transform(roi, from_level, to_level, img, call = rlang::caller_env())
```

## Arguments

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md).

- from_level, to_level:

  Integer source and target pyramid levels.

- img:

  The
  [sg_roi_frame](https://cttir.github.io/segmantR/reference/sg_roi.html)
  whose pyramid defines the level dimensions.

- call:

  The calling environment, for error reporting.

## Value

An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md)
with coordinates at `to_level`. Exactly invertible.

## See also

[`sg_roi_rescale()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rescale.md)

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
[`sg_roi_setops`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_snap.md)

## Examples

``` r
img <- sg_roi_frame(c(100, 100), list(c(100, 100), c(50, 50), c(25, 25)))
r <- sg_roi_rect(0, 0, 100, 100, label = "a")
sg_roi_transform(r, from_level = 0, to_level = 2, img = img)
#> <sg_roi> a (POLYGON)
#> id: "roi_000000033"  |  level: 2  |  source: manual
#> bbox: [0, 0] - [25, 25]
```
