# Load a bundled example mask

Returns an `sg_mask` matching the corresponding example image.

## Usage

``` r
sg_example_mask(type = c("he_breast", "fluorescence_nuclei", "multiplex_4ch"))
```

## Arguments

- type:

  Character, one of `"he_breast"`, `"fluorescence_nuclei"`, or
  `"multiplex_4ch"`.

## Value

An `sg_mask` object.

## Examples

``` r
mask <- sg_example_mask("he_breast")
print(mask)
#> <sg_mask>: 64 x 64, 20 cells
#> Method: synthetic
```
