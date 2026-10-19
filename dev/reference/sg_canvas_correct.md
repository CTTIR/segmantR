# Apply a cell canvas correction

Geometry is in local array pixels. Changes retain image binding and are
staged for explicit review. Overlapping cells are rejected.

## Usage

``` r
sg_canvas_correct(
  mask,
  geometry = NULL,
  action = "add",
  cell_id = NULL,
  expected_revision
)
```

## Arguments

- mask:

  An `sg_mask`.

- geometry:

  GeoJSON Polygon or MultiPolygon, required for add/edit.

- action:

  One of `add`, `edit`, `erase`.

- cell_id:

  Existing integer label for edit/erase.

- expected_revision:

  Revision shown when the edit began.

## Value

A staged `sg_mask`.
