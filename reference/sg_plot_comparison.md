# Side-by-side comparison of two masks

Shows two segmentation masks next to each other using faceted panels.
Cells are coloured by their label; the labels of the two masks are
independent, so equal colours do not mark matching cells.

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

  An `sg_image` object, or `NULL`. Currently not drawn; use
  [`sg_plot_overlay()`](https://cttir.github.io/segmantR/reference/sg_plot_overlay.md)
  to show a mask on its image.

- labels:

  Character vector of two different panel titles (default
  `c("Method A", "Method B")`).

## Value

A `ggplot2` object.

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
reference <- sg_example_mask("fluorescence_nuclei")
otsu <- sg_segment_threshold(img, min_area = 5)
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
sg_plot_comparison(reference, otsu, labels = c("Reference", "Otsu"))
```
