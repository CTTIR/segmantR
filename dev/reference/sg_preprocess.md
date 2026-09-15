# Preprocess an image

Applies a chain of preprocessing steps to an `sg_image` object,
including optional stain normalisation, denoising, and contrast
enhancement.

## Usage

``` r
sg_preprocess(
  image,
  stain_normalize = c("none", "macenko", "reinhard", "vahadane"),
  denoise = FALSE,
  contrast = c("none", "clahe", "stretch"),
  target_resolution = NULL
)
```

## Arguments

- image:

  An `sg_image` object.

- stain_normalize:

  Character string specifying the stain normalisation method. One of
  `"none"` (default), `"macenko"`, `"reinhard"`, or `"vahadane"`.

- denoise:

  Logical; if `TRUE`, a simple mean filter is applied for denoising.
  Default is `FALSE`.

- contrast:

  Character string specifying contrast enhancement. One of `"none"`
  (default), `"clahe"`, or `"stretch"`.

- target_resolution:

  Numeric scalar or `NULL`. If not `NULL`, the image is resampled to
  this target resolution (microns per pixel) using bilinear
  interpolation.

## Value

A new `sg_image` object with its `history` field updated to record the
preprocessing steps applied.

## Examples

``` r
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
img2 <- sg_preprocess(img)
img3 <- sg_preprocess(img, contrast = "stretch", denoise = TRUE)
```
