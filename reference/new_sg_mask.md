# Create a new sg_mask object

Constructor for the `sg_mask` S3 class, which stores an integer label
matrix where 0 represents background and positive integers represent
individual cell IDs.

## Usage

``` r
new_sg_mask(labels, image_id = NULL, model_info = NULL)
```

## Arguments

- labels:

  Integer matrix of cell labels. 0 = background, 1..N = cell IDs.

- image_id:

  Optional character string identifying the source image.

- model_info:

  Optional named list of model metadata.

## Value

An object of class `sg_mask`.

## Examples

``` r
labels <- matrix(c(0L, 0L, 1L, 1L, 0L, 2L, 2L, 0L, 0L), nrow = 3)
mask <- new_sg_mask(labels)
print(mask)
#> <sg_mask>: 3 x 3, 2 cells
```
