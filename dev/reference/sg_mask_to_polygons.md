# Convert mask to polygon geometries

Extracts cell boundaries from a label mask and returns them as polygon
geometries. If the sf package is available, returns an `sf` data frame;
otherwise returns a tibble of boundary coordinates.

## Usage

``` r
sg_mask_to_polygons(mask, simplify = TRUE, tolerance = 1)
```

## Arguments

- mask:

  An `sg_mask` object.

- simplify:

  Logical. Simplify polygon geometries? Default `TRUE`.

- tolerance:

  Numeric. Simplification tolerance in pixels when `simplify = TRUE`.
  Default `1.0`.

## Value

An `sf` data frame with one row per cell (columns `cell_id` and
`geometry`) when sf is available, or a tibble with columns `cell_id`,
`row`, `col` listing boundary coordinates.

## Examples

``` r
labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
polys <- sg_mask_to_polygons(mask, simplify = FALSE)
head(polys)
#> Simple feature collection with 2 features and 1 field
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 3 ymin: 3 xmax: 18 ymax: 18
#> CRS:           NA
#>   cell_id                       geometry
#> 1       1 POLYGON ((8 3, 3 3, 3 8, 8 ...
#> 2       2 POLYGON ((18 12, 12 12, 12 ...
```
