# Read an ENVI cube window into an sg_image

Reads only the requested bands and pixel window by seeking in the data
file (BSQ, BIL or BIP; either byte order). Values are returned as
stored: gain, offset and reflectance scale factors are recorded but
never applied, and `value_semantics` is whatever the caller declares
(default `"unknown"`), so raw counts, reflectance, radiance, intensity
and absorbance are never mixed silently.

## Usage

``` r
sg_read_envi(
  path,
  bands = NULL,
  window = NULL,
  value_semantics = "unknown",
  nodata_to_na = TRUE,
  source_digest = c("full", "header", "none"),
  data_file = NULL
)
```

## Arguments

- path:

  Path to the `.hdr` file or the data file.

- bands:

  Optional 1-based band indices to read (default all).

- window:

  Optional `c(row_min, row_max, col_min, col_max)` (1-based, inclusive).

- value_semantics:

  Declared meaning of the stored values.

- nodata_to_na:

  Replace the header `data ignore value` by `NA`.

- source_digest:

  `"full"` hashes header and data file (identity of the source),
  `"header"` hashes only the header, `"none"` skips hashing.

- data_file:

  Optional explicit data file path.

## Value

An `sg_image` with pixels `[y, x, band]`, a band table, `origin` set to
the window offset, `calibration_digest`, and `metadata$read_accounting`
(`bytes_read`, `bands_read`).

## Examples

``` r
d <- tempfile("envi")
dir.create(d)
writeLines(c("ENVI", "samples = 3", "lines = 2", "bands = 2",
             "data type = 12", "interleave = bip", "byte order = 0",
             "wavelength = {500, 600}"), file.path(d, "cube.hdr"))
writeBin(1:12, file.path(d, "cube"), size = 2L, endian = "little")
img <- sg_read_envi(file.path(d, "cube.hdr"), bands = 2,
                    value_semantics = "raw")
img$pixels
#>      [,1] [,2] [,3]
#> [1,]    2    4    6
#> [2,]    8   10   12
```
