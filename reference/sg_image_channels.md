# List the channels of a multi-page microscopy TIFF

Reads the directory structure of a (Q)PTIFF, OME-TIFF or plain
multi-page TIFF through GDAL and returns one row per full-resolution
channel plane. Channel names come from the per-plane image description
(`<Biomarker>`, then `<Name>`, as written by PhenoCycler/Vectra QPTIFF
files), from the `Channel Name` attributes of OME-XML on the first
plane, or default to `ch1`, `ch2`, .... Reduced-resolution pages
(overviews, thumbnails, label and macro images) are left out: a plane
belongs to the channel set when it has one band and the size of the
first plane.

## Usage

``` r
sg_image_channels(path)
```

## Arguments

- path:

  Path to the image file.

## Value

A data frame with columns `channel` (1-based channel number), `name`,
`directory` (1-based TIFF directory), `width`, `height`, `block_width`,
`block_height`, `datatype` and `dsn` (the GDAL dataset name of the
plane).

## See also

[`sg_read_window()`](https://cttir.github.io/segmantR/reference/sg_read_window.md),
[`sg_read_field()`](https://cttir.github.io/segmantR/reference/sg_read_field.md)

## Examples

``` r
f <- tempfile(fileext = ".tif")
planes <- list(matrix(1:100, 10, 10), matrix(101:200, 10, 10))
invisible(tiff::writeTIFF(lapply(planes, function(p) p / 255), f,
                          bits.per.sample = 8L))
sg_image_channels(f)[, c("channel", "name", "width", "height")]
#>   channel name width height
#> 1       1  ch1    10     10
#> 2       2  ch2    10     10
```
