# Downsampled preview of a mask

Nearest-neighbour downsample only (interpolating a label mask would
invent labels that do not exist).

## Usage

``` r
sg_roi_mask_preview(mask, max_dim = 1024L, call = rlang::caller_env())
```

## Arguments

- mask:

  An `sg_roi_mask`.

- max_dim:

  Integer maximum dimension of the preview. Default `1024`.

- call:

  The calling environment, for error reporting.

## Value

A downsampled `sg_roi_mask` with the legend pixel counts recomputed.

## See also

Other masks:
[`sg_roi_mask()`](https://cttir.github.io/segmantR/reference/sg_roi_mask.md),
[`sg_roi_mask_boundary()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_boundary.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stack.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stats.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(20, 20, 80, 80, label = "tissue"))
m <- sg_roi_mask(sg_roi_project(sg_roi_frame(c(100, 100)), lyr), "labelled")
dim(sg_roi_mask_preview(m, max_dim = 25))
#> [1] 25 25
```
