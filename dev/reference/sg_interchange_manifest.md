# Build an interchange manifest

Describes an image, mask or segmentation run with the shared coordinate
convention, plane, pixel size, legend, review state, protocol reference,
runtime and asset inventory. The result conforms to
`inst/schema/segmantR-interchange-v1/manifest.schema.json`.

## Usage

``` r
sg_interchange_manifest(
  x,
  ...,
  image = NULL,
  assets = list(),
  conversions = list(),
  kind = NULL
)
```

## Arguments

- x:

  An `sg_image`, `sg_mask`, `sg_run`, or a named list with `image`,
  `mask`, `run` and/or `measurements`.

- ...:

  Reserved; must be empty.

- image:

  Optional `sg_image` the mask belongs to.

- assets:

  Asset records (`role`, `path`, `media_type`, `size_bytes`, `sha256`),
  normally filled by
  [`sg_export_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_export_interchange.md).

- conversions:

  Conversion records (`from`, `to`, `fidelity`, `notes`).

- kind:

  Optional manifest kind override.

## Value

An `sg_manifest` list.

## Examples

``` r
m <- sg_example_mask("fluorescence_nuclei")
man <- sg_interchange_manifest(m)
man$mask$label_count
#> [1] 15
man$coordinate_convention$y_axis
#> [1] "down"
```
