# Threshold-based cell segmentation

Segments cells in an `sg_image` by applying a global or local intensity
threshold, followed by morphological cleanup and connected-component
labelling with size filtering.

## Usage

``` r
sg_segment_threshold(
  image,
  channel = 1L,
  method = c("otsu", "adaptive", "triangle"),
  block_size = 51L,
  offset = 0.05,
  morphology = list(open = 5L, fill_holes = TRUE),
  min_area = 50L,
  max_area = 5000L
)
```

## Arguments

- image:

  An `sg_image` object.

- channel:

  Integer index of the image channel to threshold. Default is `1L`.

- method:

  Character string specifying the thresholding method. One of `"otsu"`
  (default), `"adaptive"`, or `"triangle"`.

- block_size:

  Integer block size for adaptive thresholding. Must be a positive odd
  integer. Only used when `method = "adaptive"`. Default is `51L`.

- offset:

  Numeric offset subtracted from the local mean in adaptive
  thresholding. Default is `0.05`.

- morphology:

  A named list controlling morphological cleanup:

  `open`

  :   Integer; structuring element size for opening (erosion then
      dilation). Set to `0L` to skip. Default `5L`.

  `fill_holes`

  :   Logical; whether to fill holes inside objects. Default `TRUE`.

- min_area:

  Integer; minimum object area in pixels. Objects smaller than this are
  removed. Default is `50L`.

- max_area:

  Integer; maximum object area in pixels. Objects larger than this are
  removed. Default is `5000L`.

## Value

An `sg_mask` object with labelled cell regions.

## Examples

``` r
set.seed(42)
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
mask <- sg_segment_threshold(img, method = "otsu")
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 0 objects via threshold (otsu).
print(mask)
#> <sg_mask>: 20 x 20, 0 cells
#> Method: threshold:otsu
```
