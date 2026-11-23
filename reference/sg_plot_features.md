# Scatter plot of cell features

Produces a scatter plot of two numeric cell features, with optional
colour and faceting variables.

## Usage

``` r
sg_plot_features(
  features,
  x = "area",
  y = "mean_intensity",
  color = NULL,
  facet = NULL
)
```

## Arguments

- features:

  A data frame of cell features with one row per cell, for example from
  [`sg_extract_features()`](https://cttir.github.io/segmantR/reference/sg_extract_features.md).

- x:

  Character, column name for the x-axis (default `"area"`).

- y:

  Character, column name for the y-axis (default `"mean_intensity"`).
  [`sg_extract_features()`](https://cttir.github.io/segmantR/reference/sg_extract_features.md)
  names intensity columns after the channel (for example `"ch1_mean"`),
  so pass that name for its output.

- color:

  Character column name for point colour, or `NULL`.

- facet:

  Character column name for faceting, or `NULL`.

## Value

A `ggplot2` object.

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
mask <- sg_example_mask("fluorescence_nuclei")
feat <- sg_extract_features(img, mask,
                            features = c("intensity", "morphology"))
#> ✔ Extracted intensity, morphology features for 15 cells.
sg_plot_features(feat, x = "area", y = "DAPI_mean",
                 color = "circularity")
```
