# Read a square multichannel field around a point

Converts a centre in physical units (for example micrometres) to pixels
and reads a square window of `round(size / pixel_size)` pixels in each
requested channel. The top-left pixel is
`round(centre / pixel_size) - n %/% 2`, so a field is reproducible from
its centre, size and pixel size alone.

## Usage

``` r
sg_read_field(path, channels, centre, size, pixel_size = 1, fill = 0)
```

## Arguments

- path:

  Path to the image file.

- channels:

  Channel names or numbers.

- centre:

  Numeric `c(x, y)` in physical units, or a data frame whose first row
  has columns `x` and `y`.

- size:

  Field width in physical units.

- pixel_size:

  Physical size of one pixel.

- fill:

  Value used outside the image.

## Value

A list of class `sg_field` with `channels` (named list of `n` x `n`
matrices), `x0`, `y0`, `n`, `pixel_size`, `centre`, `size` and `extent`
(`c(xmin, xmax, ymin, ymax)` of the pixel edges in physical units).

## See also

[`sg_read_fields()`](https://cttir.github.io/segmantR/dev/reference/sg_read_fields.md),
[`sg_read_window()`](https://cttir.github.io/segmantR/dev/reference/sg_read_window.md)

## Examples

``` r
f <- tempfile(fileext = ".tif")
planes <- list(matrix(1:100, 10, 10), matrix(101:200, 10, 10))
invisible(tiff::writeTIFF(lapply(planes, function(p) p / 255), f,
                          bits.per.sample = 8L))
fld <- sg_read_field(f, c("ch1", "ch2"), centre = c(2.5, 2.5), size = 2,
                     pixel_size = 0.5)
fld$channels$ch2
#>      [,1] [,2] [,3] [,4]
#> [1,]  134  144  154  164
#> [2,]  135  145  155  165
#> [3,]  136  146  156  166
#> [4,]  137  147  157  167
```
