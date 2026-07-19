# Voronoi propagation from nuclear seeds

Expands nuclear seed regions outward using Voronoi-style propagation,
optionally constrained by a membrane signal. When available,
[`EBImage::propagate()`](https://rdrr.io/pkg/EBImage/man/propagate.html)
is used for higher performance; otherwise a pure-R fallback is used.

## Usage

``` r
sg_segment_propagate(
  image,
  nuclear_mask,
  membrane_image = NULL,
  lambda = 0.01,
  expand_max = 20L
)
```

## Arguments

- image:

  An `sg_image` object.

- nuclear_mask:

  An `sg_mask` object providing the nuclear seed labels.

- membrane_image:

  An `sg_image` object (single channel) used as a cost surface to
  penalise crossing membranes. If `NULL`, propagation proceeds
  uniformly.

- lambda:

  Numeric weight for the membrane penalty in the cost function. Higher
  values make propagation stop more readily at membranes. Default is
  `0.01`.

- expand_max:

  Integer; maximum number of propagation iterations. Default is `20L`.

## Value

An `sg_mask` object with expanded cell labels.

## Examples

``` r
set.seed(42)
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
seeds <- matrix(0L, nrow = 20, ncol = 20)
seeds[5, 5] <- 1L
seeds[15, 15] <- 2L
nuc_mask <- new_sg_mask(seeds)
result <- sg_segment_propagate(img, nuclear_mask = nuc_mask)
print(result)
#> <sg_mask>: 20 x 20, 2 cells
#> Method: propagate:ebimage
```
