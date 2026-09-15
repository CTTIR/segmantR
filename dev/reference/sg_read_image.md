# Read an image file

Reads TIFF, PNG, or JPEG image files and returns an `sg_image` object.
Dispatches to
[`EBImage::readImage()`](https://rdrr.io/pkg/EBImage/man/io.html) when
available, otherwise uses
[`imager::load.image()`](https://rdrr.io/pkg/imager/man/load.image.html).
The returned pixel array is always ordered `[y, x, channel]`, and the
object records the SHA-256 digest of the file in `source_digest` plus
its base name (never the full path) in `metadata$source_name`.

## Usage

``` r
sg_read_image(path, ...)
```

## Arguments

- path:

  Character string, path to the image file.

- ...:

  Additional arguments passed to the underlying reader.

## Value

An `sg_image` object.

## Examples

``` r
# \donttest{
# img <- sg_read_image("path/to/image.tiff")
# }
```
