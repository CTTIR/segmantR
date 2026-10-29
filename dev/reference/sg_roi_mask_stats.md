# Per-value statistics of a mask

Per-value statistics of a mask

## Usage

``` r
sg_roi_mask_stats(mask, pixel_size = NULL, call = rlang::caller_env())
```

## Arguments

- mask:

  An `sg_roi_mask`.

- pixel_size:

  Optional numeric `c(x, y)` physical pixel size for physical area at
  the mask's level (scale level-zero calibration before use on a coarser
  mask). When `NULL`, `area_physical` is `NA`.

- call:

  The calling environment, for error reporting.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per mask value: `value`, `label`, `n_px`, `area_px`,
`area_physical`, `frac_total`, bounding box (`bbox_xmin`, `bbox_ymin`,
`bbox_xmax`, `bbox_ymax`), and centroid (`centroid_x`, `centroid_y`). A
0-row tibble when the mask is empty.

## See also

Other masks:
[`sg_roi_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask.md),
[`sg_roi_mask_boundary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_boundary.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stack.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
sg_roi_mask_stats(sg_roi_mask(proj, "labelled"))
#> # A tibble: 1 × 12
#>   value label   n_px area_px area_physical frac_total bbox_xmin bbox_ymin
#>   <int> <chr>  <int>   <dbl>         <dbl>      <dbl>     <dbl>     <dbl>
#> 1     1 tissue    36      36            NA       0.09         2         2
#> # ℹ 4 more variables: bbox_xmax <dbl>, bbox_ymax <dbl>, centroid_x <dbl>,
#> #   centroid_y <dbl>
```
