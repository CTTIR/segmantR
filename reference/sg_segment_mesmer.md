# Mesmer (DeepCell) cell segmentation

Segments cells using the Mesmer deep learning model from the DeepCell
library via `reticulate`. Mesmer is designed for multiplexed tissue
imaging and can segment both nuclear and whole-cell compartments.

## Usage

``` r
sg_segment_mesmer(
  image,
  compartment = c("whole-cell", "nuclear", "both"),
  image_mpp = NULL
)
```

## Arguments

- image:

  An `sg_image` object. Must have at least two channels: a nuclear
  channel (first) and a membrane/cytoplasm channel (second).

- compartment:

  Character string specifying which compartment to segment. One of
  `"whole-cell"` (default), `"nuclear"`, or `"both"`.

- image_mpp:

  Numeric scalar or `NULL`. Microns per pixel of the input image. If
  `NULL`, the value is taken from the image resolution metadata; if that
  is also unavailable, `0.5` is used as a default.

## Value

An `sg_mask` object (for `"whole-cell"` or `"nuclear"`) or a named list
of two `sg_mask` objects (for `"both"`).

## Details

Requires a working Python installation with `deepcell` installed.

## Examples

``` r
# \donttest{
pixels <- array(runif(200), dim = c(10, 10, 2))
img <- new_sg_image(pixels, channels = c("nuclear", "membrane"))
# Requires Python + deepcell:
# mask <- sg_segment_mesmer(img, compartment = "whole-cell")
# }
```
