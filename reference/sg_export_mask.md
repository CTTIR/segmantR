# Export mask to file

Writes a segmentation mask to disk in one of several formats.

## Usage

``` r
sg_export_mask(
  mask,
  path,
  format = c("tiff", "png", "geojson", "qupath", "csv")
)
```

## Arguments

- mask:

  An `sg_mask` object.

- path:

  Character. Output file path.

- format:

  Character. Export format: `"tiff"` (default), `"png"`, `"geojson"`,
  `"qupath"`, or `"csv"`.

## Value

The output file path, returned invisibly.

## Examples

``` r
# \donttest{
labels <- matrix(0L, nrow = 10, ncol = 10)
labels[3:8, 3:8] <- 1L
mask <- new_sg_mask(labels)
tmp <- tempfile(fileext = ".csv")
sg_export_mask(mask, tmp, format = "csv")
#> ✔ Mask exported to /tmp/RtmpqbK4bt/file21fe2125767e.csv ("csv").
# }
```
