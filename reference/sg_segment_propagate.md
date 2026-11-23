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
  expand_max = 20L,
  engine = c("auto", "voronoi_r", "ebimage")
)
```

## Arguments

- image:

  An `sg_image` object.

- nuclear_mask:

  An `sg_mask` object providing the nuclear seed labels.

- membrane_image:

  An `sg_image` object (single channel) used to constrain the pure-R
  engine: new pixels must have intensity strictly below the membrane
  image's 90th percentile. Supplied seeds are retained. A membrane image
  selects pure R in auto mode.

- lambda:

  Finite nonnegative numeric weight passed only to EBImage. Higher
  values give Euclidean distance more weight relative to image
  gradients. The pure-R engine does not use this parameter. Default
  `0.01`.

- expand_max:

  Nonnegative integer; maximum number of four-neighbour propagation
  steps from the supplied seed pixels. Default is `20L`. With no
  membrane, this bounds the support to Manhattan distance `expand_max`
  pixels from a seed. Both engines honour this support bound; EBImage
  retains its intensity-aware assignment of labels within it, so the
  engines need not assign identical labels. Zero preserves the seeds.

- engine:

  `"auto"` (default, historic behaviour: EBImage when it is installed
  and no membrane image is given, otherwise pure R), `"voronoi_r"`
  (always the pure-R engine) or `"ebimage"` (always EBImage; errors
  instead of falling back).

## Value

An `sg_mask` object with expanded cell labels. Its `model_info` records
the engine, requested `lambda`, whether `lambda_applied`, and
`expand_max`. For pure R it also records `membrane_threshold` and
`membrane_quantile` (`NULL` when no membrane image is supplied).

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
