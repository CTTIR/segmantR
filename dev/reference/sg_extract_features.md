# Extract per-cell features from an image and mask

Computes intensity, morphology, texture, and location features for each
segmented cell. Returns a tibble with one row per cell.

## Usage

``` r
sg_extract_features(
  image,
  mask,
  features = c("intensity", "morphology", "texture", "location"),
  channels = NULL
)
```

## Arguments

- image:

  An `sg_image` object.

- mask:

  An `sg_mask` object with labels matching the image dimensions.

- features:

  Character vector of feature groups to compute. One or more of
  `"intensity"`, `"morphology"`, `"texture"`, `"location"`. Default is
  all four.

- channels:

  Integer or character vector selecting which image channels to use for
  intensity and texture features. `NULL` (default) uses all channels.

## Value

A tibble with one row per cell and a `cell_id` column, plus columns for
each requested feature.

## Details

Morphology features: `perimeter` is the number of boundary pixels;
`circularity` is \\4 \pi A / P^2\\, capped at 1 because the
boundary-pixel count underestimates the perimeter of round objects;
`eccentricity` comes from the eigenvalues of the pixel-coordinate
covariance (0 for a disc, 1 for a line of pixels); `solidity` is the
area divided by the area of the convex hull of the pixel squares.
Circularity, eccentricity and solidity are `NA` for single-pixel cells.

## Examples

``` r
pixels <- array(runif(20 * 20 * 2), dim = c(20, 20, 2))
img <- new_sg_image(pixels, channels = c("DAPI", "CD3"))
labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
feats <- sg_extract_features(img, mask, features = c("intensity", "morphology"))
#> ✔ Extracted intensity, morphology features for 2 cells.
print(feats)
#> # A tibble: 2 × 20
#>   cell_id DAPI_mean DAPI_sd DAPI_median DAPI_min DAPI_max DAPI_q25 DAPI_q75
#>     <int>     <dbl>   <dbl>       <dbl>    <dbl>    <dbl>    <dbl>    <dbl>
#> 1       1     0.472   0.275       0.484   0.0364    0.941    0.216    0.704
#> 2       2     0.559   0.270       0.619   0.0104    0.992    0.364    0.771
#> # ℹ 12 more variables: CD3_mean <dbl>, CD3_sd <dbl>, CD3_median <dbl>,
#> #   CD3_min <dbl>, CD3_max <dbl>, CD3_q25 <dbl>, CD3_q75 <dbl>, area <int>,
#> #   perimeter <dbl>, circularity <dbl>, eccentricity <dbl>, solidity <dbl>
```
