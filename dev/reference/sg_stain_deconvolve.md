# Separate H&E stain channels by colour deconvolution

Applies colour deconvolution to an H&E-stained image to separate the
haematoxylin and eosin channels.

## Usage

``` r
sg_stain_deconvolve(image, method = c("macenko", "ruifrok"), stains = NULL)
```

## Arguments

- image:

  An `sg_image` object with at least 3 colour channels (RGB).

- method:

  Character string specifying the deconvolution method. One of
  `"macenko"` (default), which estimates the two stain vectors from the
  image, or `"ruifrok"`, which uses the fixed haematoxylin and eosin
  vectors of Ruifrok and Johnston (2001).

- stains:

  Optional 3x3 numeric matrix whose columns are the stain vectors
  (optical density in R, G and B) for haematoxylin, eosin and the
  residual channel, in that order. If `NULL`, stain vectors are
  estimated from the image using the specified `method`.

## Value

A named list of `sg_image` objects, one per stain channel. Typically
`hematoxylin` and `eosin`, plus `residual`.

## Examples

``` r
# Requires a colour image
pixels <- array(runif(300), dim = c(10, 10, 3))
img <- new_sg_image(pixels, channels = c("R", "G", "B"))
stains <- sg_stain_deconvolve(img)
names(stains)
#> [1] "hematoxylin" "eosin"       "residual"   
```
