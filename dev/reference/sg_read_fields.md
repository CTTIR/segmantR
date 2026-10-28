# Read many square fields, for example cell galleries

Reads one
[`sg_read_field()`](https://cttir.github.io/segmantR/dev/reference/sg_read_field.md)
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
  [`sg_read_field()`](https://cttir.github.io/segmantR/dev/reference/sg_read_field.md).

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

[`sg_read_field()`](https://cttir.github.io/segmantR/dev/reference/sg_read_field.md)
