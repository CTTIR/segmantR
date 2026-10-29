# Describe a training dataset

Builds a tile-level dataset manifest from image/mask pairs without
writing pixels. Tiles are laid out on a regular grid (`tile_size`,
`overlap`), splits are assigned per **group** (`subject_id`, `sample_id`
or `slide_id`) with a fixed seed so tiles of one origin never land in
different splits, and every tile records its bounds, plane, object list
(label, object id, class) and exclusion reason.

## Usage

``` r
sg_dataset_manifest(
  pairs,
  tile_size = 256L,
  overlap = 0L,
  group_by = c("subject_id", "sample_id", "slide_id"),
  split = c(train = 0.7, validation = 0.15, test = 0.15),
  seed = 1L,
  mask_type = c("instance", "labelled", "binary"),
  min_objects = 1L,
  partial_tiles = c("exclude", "keep"),
  require_reviewed = FALSE,
  normalization = list(method = "none"),
  backend = NULL
)
```

## Arguments

- pairs:

  A list of training pairs. Each element is a list with `image`
  (`sg_image`), `mask` (`sg_mask`) and the grouping ids `subject_id`,
  `sample_id` and/or `slide_id`.

- tile_size:

  Tile edge length in pixels.

- overlap:

  Overlap between neighbouring tiles in pixels.

- group_by:

  Grouping key used for the split.

- split:

  Named proportions for `train`, `validation` and `test` (normalised to
  sum 1).

- seed:

  Integer seed of the group permutation (the global RNG state is
  restored afterwards).

- mask_type:

  Required mask type.

- min_objects:

  Tiles with fewer objects are excluded (`"empty"` for zero objects,
  `"too_few_objects"` otherwise).

- partial_tiles:

  `"exclude"` border tiles smaller than `tile_size`, or `"keep"` them.

- require_reviewed:

  Logical; exclude tiles from masks that are not reviewed
  (`"not_reviewed"`).

- normalization:

  List with `method` (`"none"`, `"minmax"`, `"percentile"`), `low`,
  `high` describing the normalisation the trainer applies (recorded, not
  applied here).

- backend:

  Optional target backend name recorded in the manifest.

## Value

An `sg_dataset_manifest` list conforming to
`dataset-manifest.schema.json`.

## Details

Masks must satisfy the requested `mask_type`: integer, background 0, and
for `"instance"` one connected part per label. A foreground/background
mask with several objects under one label is rejected
(`NOT_INSTANCE_MASK`) instead of being accepted silently.

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
# The synthetic example mask contains overlapping ellipses; split them
# into separate instances first.
msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                         disconnected = "split")
pairs <- list(
  list(image = img, mask = msk, subject_id = "A"),
  list(image = img, mask = msk, subject_id = "B")
)
man <- sg_dataset_manifest(pairs, tile_size = 32L, min_objects = 0L,
                           split = c(train = 0.5, validation = 0.5,
                                     test = 0))
table(vapply(man$tiles, function(t) t$split, ""))
#> 
#>      train validation 
#>          4          4 
```
