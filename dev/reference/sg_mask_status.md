# Review state of a mask

Review state of a mask

## Usage

``` r
sg_mask_status(mask)
```

## Arguments

- mask:

  An `sg_mask` object.

## Value

A list with `status`, `revision` (current content revision),
`reviewed_revision`, `parent_revision` and `consistent` (`FALSE` when a
reviewed mask was modified after review).

## Examples

``` r
sg_mask_status(new_sg_mask(matrix(0L, 3, 3)))
#> $status
#> [1] "draft"
#> 
#> $revision
#> [1] "sha256:27299a7f3343522670e5c884f905d78ebf71fe02bccc8a8e532479ca54c22940"
#> 
#> $reviewed_revision
#> [1] NA
#> 
#> $parent_revision
#> [1] NA
#> 
#> $consistent
#> [1] TRUE
#> 
#> $history
#> list()
#> 
```
