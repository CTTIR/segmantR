# Cellpose cell segmentation

Segments cells using the Cellpose deep learning model via `reticulate`.
Requires a working Python installation with `cellpose` installed. Use
[`sg_setup_python()`](https://cttir.github.io/segmantR/reference/sg_setup_python.md)
to configure the environment.

## Usage

``` r
sg_segment_cellpose(
  image,
  model = c("cyto3", "cyto2", "nuclei", "tissuenet", "livecell", "custom"),
  channels = list(cytoplasm = 0L, nucleus = 1L),
  diameter = NULL,
  flow_threshold = 0.4,
  cellprob_threshold = 0,
  custom_model_path = NULL,
  batch_size = 8L,
  tile = TRUE
)
```

## Arguments

- image:

  An `sg_image` object.

- model:

  Character string specifying the Cellpose model. One of `"cyto3"`
  (default), `"cyto2"`, `"nuclei"`, `"tissuenet"`, `"livecell"`, or
  `"custom"`.

- channels:

  A named list with elements `cytoplasm` and `nucleus`, each an integer
  channel index (0-based, following Cellpose convention). Default is
  `list(cytoplasm = 0L, nucleus = 1L)`.

- diameter:

  Numeric or `NULL`. Estimated cell diameter in pixels. If `NULL`,
  Cellpose estimates the diameter automatically.

- flow_threshold:

  Numeric; flow error threshold for mask filtering. Default is `0.4`.

- cellprob_threshold:

  Numeric; cell probability threshold. Default is `0.0`.

- custom_model_path:

  Character string or `NULL`. Path to a custom-trained Cellpose model.
  Required when `model = "custom"`.

- batch_size:

  Integer; number of images to process in parallel on the GPU. Default
  is `8L`.

- tile:

  Logical; if `TRUE` (default), large images are processed in tiles to
  reduce memory usage.

## Value

An `sg_mask` object with labelled cell regions.

## Examples

``` r
# \donttest{
pixels <- array(runif(300), dim = c(10, 10, 3))
img <- new_sg_image(pixels, channels = c("R", "G", "B"))
# Requires Python + cellpose:
# mask <- sg_segment_cellpose(img, model = "cyto3")
# }
```
