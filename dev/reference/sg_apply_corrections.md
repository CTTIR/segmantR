# Apply manual corrections to a segmentation mask

Takes a list of correction operations (split, merge, delete, add) and
applies them to produce a corrected mask.

## Usage

``` r
sg_apply_corrections(mask, corrections)
```

## Arguments

- mask:

  An `sg_mask` object.

- corrections:

  A list of correction operations. Each element is a list with at least
  an `$action` field (`"split"`, `"merge"`, `"delete"`, or `"add"`). See
  Details.

## Value

A corrected `sg_mask` object.

## Details

Each correction in the list must contain:

- `action = "delete"`:

  Remove cell. Requires `$cell_id`.

- `action = "merge"`:

  Merge cells. Requires `$cell_ids` (integer vector).

- `action = "split"`:

  Split a cell. Requires `$cell_id` and `$seed_points` (matrix with
  columns row, col).

- `action = "add"`:

  Add a new cell. Requires `$pixels` (matrix of row/col coordinates).

## Examples

``` r
labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
corrected <- sg_apply_corrections(mask, list(
  list(action = "delete", cell_id = 2L)
))
#> ✔ Applied 1 correction.
#> ℹ Result: 1 cell.
print(corrected)
#> <sg_mask>: 20 x 20, 1 cell
```
