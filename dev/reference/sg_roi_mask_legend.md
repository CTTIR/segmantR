# Legend of a mask

Legend of a mask

## Usage

``` r
sg_roi_mask_legend(mask, call = rlang::caller_env())
```

## Arguments

- mask:

  An `sg_roi_mask`.

- call:

  The calling environment, for error reporting.

## Value

The mask's legend
[tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
(`value`, `label`, `layer`, `roi_id`, `n_px`, `colour`).

## See also

Other masks:
[`sg_roi_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask.md),
[`sg_roi_mask_boundary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_boundary.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stack.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stats.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
sg_roi_mask_legend(sg_roi_mask(proj, "labelled"))
#> # A tibble: 1 × 6
#>   value label  layer  roi_id         n_px colour 
#>   <int> <chr>  <chr>  <chr>         <int> <chr>  
#> 1     1 tissue tissue roi_000000029    36 #999999
```
