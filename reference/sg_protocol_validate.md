# Validate a protocol, optionally against an image and parameters

Checks the definition against `segmantR-protocol-v1` (schema family and
major version, JSON Schema, parameter mapping completeness, defaults),
resolves parameters (unknown names and out-of-range values are errors),
and, when an image is given, checks the input contract: array order and
size, value semantics, channel/band selection and pixel calibration.

## Usage

``` r
sg_protocol_validate(protocol, image = NULL, ..., error = TRUE)
```

## Arguments

- protocol:

  Protocol id, `sg_protocol`, named list, JSON text or path to a `.json`
  file.

- image:

  Optional `sg_image` (or `sg_mask` for mask-input protocols).

- ...:

  Parameter overrides and additional inputs (for example
  `seeds = mask`).

- error:

  Logical; if `FALSE`, return a report with `ok = FALSE` instead of
  signalling the first error.

## Value

An `sg_protocol_validation` list with `ok`, `protocol`, `parameters`,
`checks` (tibble) and `error` (condition or `NULL`).

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
v <- sg_protocol_validate("threshold.otsu.v1", img, min_area = 5L)
v$ok
#> [1] TRUE
bad <- sg_protocol_validate("threshold.otsu.v1", img, min_area = -1L,
                            error = FALSE)
bad$error$code
#> [1] "PARAMETER_OUT_OF_RANGE"
```
