# Clean up a label mask

Applies the `postprocess.label-cleanup.v1` rules to an `sg_mask` in a
fixed order: handling of disconnected label parts, hole filling,
separation of touching objects, border removal, area filtering and
relabelling. The legend (object ids, classes) follows the labels.

## Usage

``` r
sg_cleanup_labels(
  mask,
  min_area = 0L,
  max_area = NULL,
  min_area_um2 = NULL,
  max_area_um2 = NULL,
  fill_holes = FALSE,
  connectivity = 4L,
  border = c("keep", "remove"),
  touching = c("keep", "separate"),
  disconnected = c("keep", "split", "keep_largest"),
  relabel = c("value", "raster", "none"),
  pixel_size = NULL
)
```

## Arguments

- mask:

  An `sg_mask` object.

- min_area:

  Minimum object area in pixels (full-resolution pixels for downsampled
  masks are not assumed; areas are array pixels).

- max_area:

  Maximum object area in pixels, or `NULL` for no limit.

- min_area_um2, max_area_um2:

  Area limits in square micrometres; require `pixel_size`.

- fill_holes:

  Logical; fill background holes enclosed by one label.

- connectivity:

  `4L` or `8L`; used for hole detection and disconnected-part handling.

- border:

  `"keep"` or `"remove"` objects touching the array border.

- touching:

  `"keep"` or `"separate"`; `"separate"` sets contact pixels of the
  higher label to background (4-neighbourhood).

- disconnected:

  `"keep"`, `"split"` (new labels for extra parts) or `"keep_largest"`
  for labels consisting of several parts.

- relabel:

  `"value"` (1..N keeping order), `"raster"` (1..N by first appearance)
  or `"none"`.

- pixel_size:

  Optional list with `x` and `y` in micrometres.

## Value

A new `sg_mask`. Masks derived from staged or reviewed masks are staged.

## Examples

``` r
labels <- matrix(0L, 12, 12)
labels[2:4, 2:4] <- 1L
labels[7:11, 7:11] <- 2L
labels[9, 9] <- 0L
out <- sg_cleanup_labels(new_sg_mask(labels), min_area = 10L,
                         fill_holes = TRUE)
out$n_cells
#> [1] 1
```
