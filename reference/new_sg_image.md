# Create a new sg_image object

Constructor for the `sg_image` S3 class, which represents a
multi-channel image with associated metadata.

## Usage

``` r
new_sg_image(pixels, channels = NULL, resolution = NULL, metadata = list())
```

## Arguments

- pixels:

  Numeric array of dimensions H x W (grayscale) or H x W x C
  (multi-channel).

- channels:

  Character vector of channel names. If `NULL`, defaults to `ch1`,
  `ch2`, etc.

- resolution:

  Named list with `x_um` and `y_um` (microns per pixel).

- metadata:

  Named list of additional image metadata.

## Value

An object of class `sg_image`.

## Examples

``` r
pixels <- matrix(runif(100), nrow = 10, ncol = 10)
img <- new_sg_image(pixels)
print(img)
#> <sg_image>: 10 x 10 (1 channel)
```
