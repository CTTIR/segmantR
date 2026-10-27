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
[`sg_roi_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stack.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stats.md)
