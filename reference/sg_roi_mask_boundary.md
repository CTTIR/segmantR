# Object boundaries of a mask

Object boundaries of a mask

## Usage

``` r
sg_roi_mask_boundary(mask, width = 1L, call = rlang::caller_env())
```

## Arguments

- mask:

  An `sg_roi_mask`.

- width:

  Integer boundary thickness in pixels. Default `1`.

- call:

  The calling environment, for error reporting.

## Value

A logical matrix marking boundary pixels (where a 4-neighbour has a
different value).

## See also

Other masks:
[`sg_roi_mask()`](https://cttir.github.io/segmantR/reference/sg_roi_mask.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stack.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stats.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
m <- sg_roi_mask(sg_roi_project(sg_roi_frame(c(10, 10)), lyr), "labelled")
sg_roi_mask_boundary(m) * 1L
#>       [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#>  [1,]    0    0    0    0    0    0    0    0    0     0
#>  [2,]    0    0    0    0    0    0    0    0    0     0
#>  [3,]    0    0    1    1    1    1    1    1    0     0
#>  [4,]    0    0    1    0    0    0    0    1    0     0
#>  [5,]    0    0    1    0    0    0    0    1    0     0
#>  [6,]    0    0    1    0    0    0    0    1    0     0
#>  [7,]    0    0    1    0    0    0    0    1    0     0
#>  [8,]    0    0    1    1    1    1    1    1    0     0
#>  [9,]    0    0    0    0    0    0    0    0    0     0
#> [10,]    0    0    0    0    0    0    0    0    0     0
```
