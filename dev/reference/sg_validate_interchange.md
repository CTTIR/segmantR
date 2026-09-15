# Validate interchange data

Validates a bundle or file on disk (all checks of
[`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md))
or an in-memory object: `sg_manifest` or list (JSON Schema and version),
`sg_mask` (label contract, legend completeness, review consistency),
`sg_run` (run schema) or `sg_protocol`.

## Usage

``` r
sg_validate_interchange(path_or_object, ...)
```

## Arguments

- path_or_object:

  A path, `sg_manifest`, manifest list, `sg_mask`, `sg_run` or
  `sg_protocol`.

- ...:

  Passed to
  [`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md)
  for paths.

## Value

An `sg_validation_report` with `ok`, `checks` (tibble) and `error`.

## Examples

``` r
m <- sg_example_mask("fluorescence_nuclei")
sg_validate_interchange(m)$ok
#> [1] FALSE
bad <- m
bad$labels[1, 1] <- -3L
sg_validate_interchange(bad)$ok
#> [1] FALSE
```
