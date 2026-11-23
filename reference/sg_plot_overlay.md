# Overlay cell boundaries on an image

Renders a single image channel as a greyscale raster and overlays cell
outlines from a segmentation mask. Outlines follow the pixel edges
between a cell and its surroundings, so they stay sharp at any image
size.

## Usage

``` r
sg_plot_overlay(
  image,
  mask = NULL,
  channel = 1L,
  outline_color = "#FF00FF",
  outline_width = 1,
  fill_alpha = 0,
  label_cells = FALSE,
  highlight = NULL
)
```

## Arguments

- image:

  An `sg_image` object.

- mask:

  An `sg_mask` object with the same height and width as `image`, or
  `NULL` to show the image only.

- channel:

  Integer, which channel to display (default `1L`).

- outline_color:

  Character, colour for cell outlines, fills and labels (default
  `"#FF00FF"`).

- outline_width:

  Numeric, width of the outline strokes (default `1`). The width is in
  absolute units, as `linewidth` in 'ggplot2': reduce it (for example to
  `0.3`) for large images with many small cells.

- fill_alpha:

  Numeric in \[0, 1\], fill opacity for cell regions (default `0`,
  outlines only).

- label_cells:

  Logical, whether to draw cell-ID labels at centroids (default
  `FALSE`).

- highlight:

  Integer vector of cell IDs to highlight, or `NULL` for all cells.

## Value

A `ggplot2` object.

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
mask <- sg_example_mask("fluorescence_nuclei")
sg_plot_overlay(img, mask)


# Fill and label two selected cells
sg_plot_overlay(img, mask, fill_alpha = 0.3, label_cells = TRUE,
                highlight = c(1L, 5L))
```
