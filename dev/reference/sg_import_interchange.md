# Import interchange data

Reads a segmantR interchange bundle or a single GeoJSON, integer TIFF,
measurement CSV or RDS file, verifies it and returns a report with the
imported objects. Imported masks are always **staged**; they never
replace reviewed data (see
[`sg_replace_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_review.md)).

## Usage

``` r
sg_import_interchange(
  path,
  format = "auto",
  expected_digest = NULL,
  ...,
  shape_yx = NULL,
  image = NULL,
  origin = NULL,
  trust_rds = FALSE,
  error = TRUE
)
```

## Arguments

- path:

  A bundle directory, its `manifest.json`, or a `.geojson`, `.json`,
  `.tif`/`.tiff`, `.csv` or `.rds` file.

- format:

  `"auto"`, `"bundle"`, `"geojson"`, `"mask_tiff"`, `"measurements"` or
  `"rds"`.

- expected_digest:

  Optional bundle digest (`"sha256:<hex>"`) the inventory must match.

- ...:

  Reserved; must be empty.

- shape_yx:

  Image shape needed to rasterise a standalone GeoJSON.

- image:

  Optional `sg_image` providing shape, origin, plane and id for
  standalone files.

- origin:

  Optional origin list for standalone GeoJSON.

- trust_rds:

  Logical; RDS files are only deserialised when `TRUE` (after integrity
  checks for bundles).

- error:

  Logical; if `FALSE`, failed checks are reported instead of signalled.

## Value

An `sg_import_report` list with `ok`, `format`, `checks` (tibble),
`mask` (staged `sg_mask` or `NULL`), `image`, `measurements`, `features`
(parsed GeoJSON features), `manifest`, `bundle_digest`, `conversions`
and `error`.

## Details

Bundle checks: inventory (missing, extra, duplicate, resized or modified
files, unsafe paths, symbolic links), optional `expected_digest`, schema
family and major version, JSON Schema, asset hashes, TIFF dtype, shape
and orientation, background code, label legend completeness, plane
consistency, content digest and revision, GeoJSON object ids and exact
geometry agreement with the TIFF, and measurement object ids.

## Examples

``` r
m <- sg_example_mask("fluorescence_nuclei")
b <- sg_export_interchange(m, tempfile("bundle"))
rep <- sg_import_interchange(b$path, expected_digest = b$bundle_digest)
rep$ok
#> [1] TRUE
sg_mask_status(rep$mask)$status
#> [1] "staged"
```
