# Prepare training data tiles

Builds the dataset manifest with
[`sg_dataset_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_dataset_manifest.md)
and materialises the included tiles: image tiles as float64 TIFF (exact
values, `[y, x, channel]` pages) and mask tiles as unsigned integer TIFF
with labels renumbered 1..N per tile in raster order. Tile object lists
map tile labels to source object ids. With a `destination`, a directory
with `dataset_manifest.json`, `tiles/<split>/images|masks/*.tif` and
`integrity.json` is written; otherwise tiles are returned in memory.

## Usage

``` r
sg_prepare_training_data(pairs, destination = NULL, ..., overwrite = FALSE)
```

## Arguments

- pairs:

  A list of training pairs. Each element is a list with `image`
  (`sg_image`), `mask` (`sg_mask`) and the grouping ids `subject_id`,
  `sample_id` and/or `slide_id`.

- destination:

  Optional output directory (must not exist or be empty).

- ...:

  Further arguments for
  [`sg_dataset_manifest()`](https://cttir.github.io/segmantR/dev/reference/sg_dataset_manifest.md).

- overwrite:

  Logical; replace an existing prepared dataset.

## Value

An `sg_training_set` with `manifest`, `path` (or `NULL`) and `tiles`
(in-memory list when `destination` is `NULL`).

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
# The synthetic example mask contains overlapping ellipses; split them
# into separate instances first.
msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                         disconnected = "split")
ts <- sg_prepare_training_data(
  list(list(image = img, mask = msk, subject_id = "A")),
  tile_size = 32L, min_objects = 0L,
  split = c(train = 1, validation = 0, test = 0)
)
length(ts$tiles)
#> [1] 4
```
