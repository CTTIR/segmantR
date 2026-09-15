# Side-by-side comparison of two masks

Shows two segmentation masks (and optionally the source image) next to
each other using faceted panels.

## Usage

``` r
sg_plot_comparison(
  mask_a,
  mask_b,
  image = NULL,
  labels = c("Method A", "Method B")
)
```

## Arguments

- mask_a:

  An `sg_mask` object (left panel).

- mask_b:

  An `sg_mask` object (right panel).

- image:

  An `sg_image` object, or `NULL`.

- labels:

  Character vector of length 2 giving panel titles (default
  `c("Method A", "Method B")`).

## Value

A `ggplot2` object.

## Examples

``` r
m1 <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2, 2))
m2 <- new_sg_mask(matrix(c(0L, 0L, 1L, 1L), 2, 2))
p <- sg_plot_comparison(m1, m2)
p
```
