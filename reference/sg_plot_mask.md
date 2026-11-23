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
  `"circularity"`, or `"cluster"`), for example from
  [`sg_extract_features()`](https://cttir.github.io/segmantR/reference/sg_extract_features.md).
  Must contain a `cell_id` column and a column named like `color_by`.
  Numeric columns are drawn with a continuous colour scale; character,
  factor and logical columns (such as cluster names) with a discrete
  one.

- palette:

  Character, name of a viridis palette (default `"viridis"`).

## Value

A `ggplot2` object.

## Details

Background pixels are dark grey; cell colours skip the darkest fifth of
the palette so that every cell stands out against it. With
`color_by = "id"` the legend lists every cell and is therefore hidden
for masks with more than 20 cells.

## Examples

``` r
mask <- sg_example_mask("fluorescence_nuclei")
sg_plot_mask(mask)


# Colour by a measured feature
img <- sg_example_image("fluorescence_nuclei")
feat <- sg_extract_features(img, mask, features = "morphology")
#> ✔ Extracted morphology features for 15 cells.
sg_plot_mask(mask, color_by = "area", features = feat)
```
