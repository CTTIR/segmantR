# Merge nuclear and cell body masks

Combines a nuclear segmentation mask with a cell body segmentation mask
to produce paired nuclear-cell assignments.

## Usage

``` r
sg_merge_masks(nuclear_mask, cell_mask, method = c("assign", "expand"))
```

## Arguments

- nuclear_mask:

  An `sg_mask` object for nuclei.

- cell_mask:

  An `sg_mask` object for cell bodies.

- method:

  Character. `"assign"` (default) assigns nuclei to overlapping cells;
  `"expand"` expands nuclear labels outward to fill cell boundaries.

## Value

A list with elements `$nuclear` and `$cell`, both `sg_mask` objects with
matched cell IDs.

## Examples

``` r
nuc_labels <- matrix(0L, nrow = 20, ncol = 20)
nuc_labels[5:7, 5:7] <- 1L
nuc_labels[14:16, 14:16] <- 2L
cell_labels <- matrix(0L, nrow = 20, ncol = 20)
cell_labels[3:9, 3:9] <- 1L
cell_labels[12:18, 12:18] <- 2L
nuc_mask <- new_sg_mask(nuc_labels)
cell_mask <- new_sg_mask(cell_labels)
merged <- sg_merge_masks(nuc_mask, cell_mask)
#> ✔ Merged nuclear (2 nuclei) and cell (2 cells) masks.
#> ℹ Method: "assign"
print(merged$nuclear)
#> <sg_mask>: 20 x 20, 2 cells
```
