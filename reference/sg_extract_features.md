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
#> 1       1     0.511   0.281       0.526  0.0676     0.961    0.247    0.755
#> 2       2     0.448   0.276       0.447  0.00238    0.966    0.165    0.675
#> # ℹ 12 more variables: CD3_mean <dbl>, CD3_sd <dbl>, CD3_median <dbl>,
#> #   CD3_min <dbl>, CD3_max <dbl>, CD3_q25 <dbl>, CD3_q75 <dbl>, area <int>,
#> #   perimeter <dbl>, circularity <dbl>, eccentricity <dbl>, solidity <dbl>
```
