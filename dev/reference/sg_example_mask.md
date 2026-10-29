# Load a bundled example mask

Returns an `sg_mask` matching the corresponding example image. Like
[`sg_example_image()`](https://cttir.github.io/segmantR/dev/reference/sg_example_image.md),
it leaves the caller's random number stream unchanged.

## Usage

``` r
sg_example_mask(type = c("he_breast", "fluorescence_nuclei", "multiplex_4ch"))
```

## Arguments

- type:

  Character, one of `"he_breast"`, `"fluorescence_nuclei"`, or
  `"multiplex_4ch"` (see
  [`sg_example_image()`](https://cttir.github.io/segmantR/dev/reference/sg_example_image.md)).

## Value

An `sg_mask` object whose labels are 0 for background and positive
integers for the cells of the example image of the same type.

## Examples

``` r
mask <- sg_example_mask("he_breast")
print(mask)
#> <sg_mask>: 64 x 64, 20 cells
#> Method: synthetic
```
