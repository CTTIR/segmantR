# Read many square fields, for example cell galleries

Reads one
[`sg_read_field()`](https://cttir.github.io/segmantR/reference/sg_read_field.md)
per row of a table of centres. Each row names its image through
`source`, looked up in `paths`.

## Usage

``` r
sg_read_fields(
  centres,
  paths,
  channels = character(0),
  size,
  pixel_size = 1,
  fill = 0,
  x = "x",
  y = "y",
  source = NULL,
  id = NULL,
  channel_columns = NULL,
  key_prefix = ""
)
```

## Arguments

- centres:

  Data frame with centre coordinates and the image key.

- paths:

  Named character vector or list: image key to file path, or a single
  path used for all rows when `source` is `NULL`.

- channels:

  Channel names or numbers read for every field.

- size, pixel_size, fill:

  As in
  [`sg_read_field()`](https://cttir.github.io/segmantR/reference/sg_read_field.md).

- x, y, source:

  Column names of the centre coordinates and image key.

- id:

  Optional column used to name the fields.

- channel_columns:

  Optional columns of `centres` naming further channels to read for each
  row (for example a row-specific marker).

- key_prefix:

  Prefix added to the `source` values before looking them up in `paths`.

## Value

A named list of `sg_field` objects in row order; each carries the table
row (as a one-row data frame) in `row`.

## See also

[`sg_read_field()`](https://cttir.github.io/segmantR/reference/sg_read_field.md)

## Examples

``` r
f <- tempfile(fileext = ".tif")
planes <- list(matrix(1:100, 10, 10), matrix(101:200, 10, 10))
invisible(tiff::writeTIFF(lapply(planes, function(p) p / 255), f,
                          bits.per.sample = 8L))
cells <- data.frame(id = c("a", "b"), x = c(2.5, 4), y = c(2.5, 3))
fields <- sg_read_fields(cells, f, channels = c("ch1", "ch2"), size = 2,
                         pixel_size = 0.5, id = "id")
fields$b$channels$ch2
#>      [,1] [,2] [,3] [,4]
#> [1,]  165  175  185  195
#> [2,]  166  176  186  196
#> [3,]  167  177  187  197
#> [4,]  168  178  188  198
```
