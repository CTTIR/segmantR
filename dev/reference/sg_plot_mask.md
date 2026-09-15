# Render a mask as a coloured image

Assigns colours to cell regions based on cell ID, area, circularity, or
cluster membership.

## Usage

``` r
sg_plot_mask(
  mask,
  color_by = c("id", "area", "circularity", "cluster"),
  features = NULL,
  palette = "viridis"
)
```

## Arguments

- mask:

  An `sg_mask` object.

- color_by:

  Character, one of `"id"`, `"area"`, `"circularity"`, or `"cluster"`.

- features:

  A data frame of cell features (required when `color_by` is `"area"`,
  `"circularity"`, or `"cluster"`). Must contain a `cell_id` column.

- palette:

  Character, name of a viridis palette (default `"viridis"`).

## Value

A `ggplot2` object.

## Examples

``` r
labels <- matrix(c(0L, 1L, 1L, 2L, 2L, 0L, 3L, 3L, 0L), 3, 3)
mask <- new_sg_mask(labels)
p <- sg_plot_mask(mask)
p
```
