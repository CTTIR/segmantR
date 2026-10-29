# Read a rectangular pixel window of one channel

Reads `height` rows and `width` columns of one channel plane starting at
the 0-based pixel offset (`x0`, `y0`). Only the image blocks that cover
the window are decoded, so windows of very large whole-slide files are
cheap. Parts of the window outside the image are filled with `fill`,
which makes fields at the slide edge keep their nominal size.

## Usage

``` r
sg_read_window(path, channel, x0, y0, width, height = width, fill = 0)
```

## Arguments

- path:

  Path to the image file.

- channel:

  Channel number (as in
  [`sg_image_channels()`](https://cttir.github.io/segmantR/reference/sg_image_channels.md))
  or channel name.

- x0, y0:

  0-based column and row of the top-left pixel; may be negative.

- width, height:

  Window size in pixels.

- fill:

  Value used outside the image.

## Value

A numeric matrix with `height` rows and `width` columns (`[y, x]`), with
attributes `x0`, `y0` and `channel` (the name).

## See also

[`sg_read_field()`](https://cttir.github.io/segmantR/reference/sg_read_field.md),
[`sg_image_channels()`](https://cttir.github.io/segmantR/reference/sg_image_channels.md)

## Examples

``` r
f <- tempfile(fileext = ".tif")
plane <- matrix(0:11, nrow = 3, byrow = TRUE)
invisible(tiff::writeTIFF(plane / 255, f, bits.per.sample = 8L))
sg_read_window(f, 1, x0 = 1, y0 = 0, width = 2, height = 2)
#>      [,1] [,2]
#> [1,]    1    2
#> [2,]    5    6
#> attr(,"x0")
#> [1] 1
#> attr(,"y0")
#> [1] 0
#> attr(,"channel")
#> [1] "ch1"
```
