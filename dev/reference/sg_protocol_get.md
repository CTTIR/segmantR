# Get a registered protocol

Get a registered protocol

## Usage

``` r
sg_protocol_get(id, version = NULL)
```

## Arguments

- id:

  Protocol identifier, e.g. `"threshold.otsu.v1"`.

- version:

  Optional exact semantic version. `NULL` returns the registered
  version.

## Value

An `sg_protocol` object (a validated named list).

## Examples

``` r
p <- sg_protocol_get("threshold.otsu.v1")
p$version
#> [1] "1.0.0"
```
