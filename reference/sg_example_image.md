# Load a bundled example image

Returns an `sg_image` containing synthetic image data for testing and
demonstrations.

## Usage

``` r
sg_example_image(type = c("he_breast", "fluorescence_nuclei", "multiplex_4ch"))
```

## Arguments

- type:

  Character, one of `"he_breast"`, `"fluorescence_nuclei"`, or
  `"multiplex_4ch"`.

## Value

An `sg_image` object.

## Examples

``` r
img <- sg_example_image("he_breast")
print(img)
#> <sg_image>: 64 x 64 (1 channel)
```
