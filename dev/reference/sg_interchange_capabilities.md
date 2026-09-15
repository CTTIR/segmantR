# Interchange capability report

Describes what this installation of segmantR can exchange: schema and
API versions, interoperability profiles with their status
(`"supported"`, `"planned"` or `"unavailable"`), file formats,
protocols, optional backends and limits. Optional Python backends are
only probed when `check_backends = TRUE`; QuPath is detected from
installation files without starting it.

## Usage

``` r
sg_interchange_capabilities(check_backends = FALSE)
```

## Arguments

- check_backends:

  Logical; probe optional Python backends (initialises Python through
  reticulate).

## Value

An `sg_capabilities` list conforming to `capabilities.schema.json`, with
a `digest` over its content.

## Details

Profiles: `I0` neutral files (manifest, integer TIFF masks, GeoJSON,
measurements, integrity inventory); `I1` versioned protocols and run
envelopes; `models` model bundles with runtime and checksums;
`qupath_programs` Groovy templates and `run.json`; `stardist_qupath` the
StarDist extension adapter; `control` the local control service
(`segmantR-control-v1`); `partner_qupflowR` and `partner_annotatR` the
partner contracts, which stay `planned` until a real consumer and QuPath
evidence exist.

## Examples

``` r
caps <- sg_interchange_capabilities()
caps$profiles$I0$status
#> [1] "supported"
caps$schema
#> [1] "segmantR-interchange-v1"
```
