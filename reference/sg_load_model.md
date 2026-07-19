# Load a packaged segmantR model

Reads a `.segmantR` archive created by
[`sg_package_model()`](https://cttir.github.io/segmantR/reference/sg_package_model.md)
and returns an `sg_trained_model` object.

## Usage

``` r
sg_load_model(path)
```

## Arguments

- path:

  Character. Path to the `.segmantR` archive file.

## Value

An `sg_trained_model` object.

## Examples

``` r
# \donttest{
# model <- sg_load_model("my_model.segmantR")
# }
```
