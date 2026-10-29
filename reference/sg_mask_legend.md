# Effective legend of a mask

Returns the stored legend or, when none is stored, a deterministic
legend with one row per positive label. Generated object ids are
UUID-shaped strings derived from the image binding, the label content
and the label value, so the same mask always yields the same ids. Use
`sg_mask_legend(mask, materialise = TRUE)` to store the legend in the
mask so ids stay stable through later edits.

## Usage

``` r
sg_mask_legend(mask, materialise = FALSE)
```

## Arguments

- mask:

  An `sg_mask` object.

- materialise:

  Logical; if `TRUE`, return the mask with the legend stored instead of
  the legend table.

## Value

A tibble with columns `label`, `object_id`, `class`, `name`, or the
updated mask when `materialise = TRUE`.

## Examples

``` r
labels <- matrix(0L, 6, 6)
labels[2:3, 2:3] <- 1L
labels[5:6, 5:6] <- 2L
sg_mask_legend(new_sg_mask(labels, image_id = "img-1"))
#> # A tibble: 2 × 4
#>   label object_id                            class name 
#>   <int> <chr>                                <chr> <chr>
#> 1     1 a0a18c86-7a9d-8d35-87ce-eabb0ed07327 NA    NA   
#> 2     2 7bb2644b-2ebf-8b16-b548-93c6b4f73bce NA    NA   
```
