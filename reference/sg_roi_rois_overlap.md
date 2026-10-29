# Pairwise ROI overlaps within a layer

Pairwise ROI overlaps within a layer

## Usage

``` r
sg_roi_rois_overlap(layer, call = rlang::caller_env())
```

## Arguments

- layer:

  An
  [sg_roi_layer](https://cttir.github.io/segmantR/reference/sg_roi_layer.md).

- call:

  The calling environment, for error reporting.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `id_a`, `id_b` (character), `overlap_px` (double, level-0
pixels), and `jaccard` (double). A 0-row tibble with these columns when
no ROIs overlap.

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
[`sg_roi_overlaps()`](https://cttir.github.io/segmantR/reference/sg_roi_overlaps.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/reference/sg_roi_ring.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/reference/sg_roi_transform.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("cells"),
                        sg_roi_rect(0, 0, 4, 4, label = "cell"))
lyr <- sg_roi_layer_add(lyr, sg_roi_rect(2, 2, 6, 6, label = "cell"))
sg_roi_rois_overlap(lyr)
#> # A tibble: 1 × 4
#>   id_a          id_b          overlap_px jaccard
#>   <chr>         <chr>              <dbl>   <dbl>
#> 1 roi_000000046 roi_000000047          4   0.143
```
