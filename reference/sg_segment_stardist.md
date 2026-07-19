# StarDist cell segmentation

Segments cells (typically nuclei) using the StarDist deep learning model
via `reticulate`. Requires a working Python installation with `stardist`
and `tensorflow` installed. Use
[`sg_setup_python()`](https://cttir.github.io/segmantR/reference/sg_setup_python.md)
to configure the environment.

## Usage

``` r
sg_segment_stardist(
  image,
  model = c("2D_versatile_fluo", "2D_versatile_he", "2D_paper_dsb2018", "custom"),
  channel = 1L,
  prob_thresh = 0.5,
  nms_thresh = 0.4,
  scale = NULL,
  custom_model_path = NULL,
  n_tiles = NULL
)
```

## Arguments

- image:

  An `sg_image` object.

- model:

  Character string specifying the StarDist model. One of
  `"2D_versatile_fluo"` (default), `"2D_versatile_he"`,
  `"2D_paper_dsb2018"`, or `"custom"`.

- channel:

  Integer index of the image channel to segment. Default is `1L`.

- prob_thresh:

  Numeric; object probability threshold. Objects with probability below
  this value are discarded. Default is `0.5`.

- nms_thresh:

  Numeric; non-maximum suppression overlap threshold. Overlapping
  detections above this threshold are merged. Default is `0.4`.

- scale:

  Numeric vector of length 1 or 2, or `NULL`. Scaling factor applied to
  the image before prediction. If `NULL`, no scaling is applied.

- custom_model_path:

  Character string or `NULL`. Path to a custom-trained StarDist model
  directory. Required when `model = "custom"`.

- n_tiles:

  Integer vector of length 2 or `NULL`. Number of tiles in each
  dimension for processing large images. If `NULL`, StarDist determines
  tiling automatically.

## Value

An `sg_mask` object with labelled cell regions.

## Examples

``` r
# \donttest{
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
# Requires Python + stardist:
# mask <- sg_segment_stardist(img, model = "2D_versatile_fluo")
# }
```
