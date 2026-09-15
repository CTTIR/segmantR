# Filter cells by morphological criteria

Removes cells from a segmentation mask that fall outside specified
morphological thresholds. Useful for quality control after initial
segmentation.

## Usage

``` r
sg_filter_cells(
  mask,
  min_area = 50L,
  max_area = 5000L,
  min_circularity = 0.3,
  max_eccentricity = 0.95,
  border_cells = c("keep", "remove", "flag")
)
```

## Arguments

- mask:

  An `sg_mask` object.

- min_area:

  Integer. Minimum cell area in pixels. Default `50L`.

- max_area:

  Integer. Maximum cell area in pixels. Default `5000L`.

- min_circularity:

  Numeric in \[0, 1\]. Minimum circularity (4 \* pi \* area /
  perimeter^2). Default `0.3`.

- max_eccentricity:

  Numeric in \[0, 1\]. Maximum eccentricity. Default `0.95`.

- border_cells:

  Character. How to handle cells touching the image border: `"keep"`
  (default), `"remove"`, or `"flag"`.

## Value

A filtered `sg_mask` object. When `border_cells = "flag"`, the returned
mask has an additional `border_cell_ids` element.

## Examples

``` r
labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
filtered <- sg_filter_cells(mask, min_area = 10L, max_area = 100L)
#> ✔ Kept 2 of 2 cells.
#> ℹ Removed 0 cells by morphological filtering.
print(filtered)
#> <sg_mask>: 20 x 20, 2 cells
```
