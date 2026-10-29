# Load a bundled example image

Returns an `sg_image` containing synthetic image data for testing and
demonstrations. The data are drawn with a fixed seed, so they are the
same in every session, and the caller's random number stream is left
unchanged.

## Usage

``` r
sg_example_image(type = c("he_breast", "fluorescence_nuclei", "multiplex_4ch"))
```

## Arguments

- type:

  Character, the example to generate:

  - `"he_breast"`: 64 x 64 single-channel image simulating an H&E
    stained breast section with about 20 cell-like blobs;

  - `"fluorescence_nuclei"`: 64 x 64 single-channel image simulating
    DAPI-stained nuclei, about 15 bright spots on a dark background;

  - `"multiplex_4ch"`: 64 x 64 x 4 array simulating a four-channel panel
    (DAPI, CD3, CD8, PanCK) with about 18 cells.

## Value

An `sg_image` object.

## See also

[`sg_example_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_example_mask.md)
for the matching label masks.

## Examples

``` r
img <- sg_example_image("he_breast")
print(img)
#> <sg_image>: 64 x 64 (1 channel)
```
