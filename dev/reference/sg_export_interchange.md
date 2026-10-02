# Export to the neutral interchange format

Writes a bundle directory containing a manifest, the requested
representations and an `integrity.json` inventory with SHA-256 hashes
and relative paths. All representations describe the same envelope: the
integer mask TIFF holds exact labels, the GeoJSON holds exact pixel-edge
polygons in image coordinates with the same object ids, and the
measurements table uses the canonical long format (`value_state`
distinguishes missing, NaN and infinite values). RDS is an optional
R-native optimisation and never the only representation.

## Usage

``` r
sg_export_interchange(
  x,
  destination,
  formats = c("manifest", "mask_tiff", "geojson", "measurements"),
  ...,
  image = NULL,
  object_type = c("detection", "annotation", "cell"),
  overwrite = FALSE
)
```

## Arguments

- x:

  An `sg_mask`, `sg_run`, `sg_image`, or a named list with `image`,
  `mask`, `run`, `measurements`.

- destination:

  Directory to create. It must not exist or be empty; with
  `overwrite = TRUE` an existing segmantR bundle is replaced.

- formats:

  Any of `"manifest"`, `"mask_tiff"`, `"geojson"`, `"measurements"`,
  `"measurements_parquet"`, `"legend"`, `"image_tiff"`, `"run"`,
  `"rds"`. The manifest and integrity inventory are always written.

- ...:

  Reserved; must be empty.

- image:

  Optional `sg_image` for image descriptors, intensity measurements and
  `"image_tiff"`.

- object_type:

  QuPath object type for GeoJSON features (`"detection"`, `"annotation"`
  or `"cell"`).

- overwrite:

  Logical; replace an existing segmantR bundle.

## Value

An `sg_interchange_bundle` (invisibly) with `path`, `manifest` and
`bundle_digest`.

## Examples

``` r
m <- sg_example_mask("fluorescence_nuclei")
img <- sg_example_image("fluorescence_nuclei")
out <- sg_export_interchange(m, tempfile("bundle"), image = img)
list.files(out$path)
#> [1] "integrity.json"   "manifest.json"    "mask.legend.json" "mask.tif"        
#> [5] "measurements.csv" "objects.geojson" 
out$bundle_digest
#> [1] "sha256:fee434822dcfda6fd59c49de697fbe95919b231abb0ed3bb134be756c0257605"
```
