# Content revision of a mask

A `"sha256:<hex>"` digest over the label array (dimensions and row-major
little-endian int32 values), the mask type and the effective legend.
Identical content always yields the same revision, so repeated imports
of the same prediction are idempotent.

## Usage

``` r
sg_mask_revision(mask)
```

## Arguments

- mask:

  An `sg_mask` object.

## Value

Character scalar.

## Examples

``` r
m <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2))
sg_mask_revision(m)
#> [1] "sha256:aae04e92b620bf9e445573b0730a9f46997771628a7eac24eb723f0f32b6a2c9"
```
