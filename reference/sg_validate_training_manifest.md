# Validate a training dataset manifest

Checks schema conformance, split leakage (a group or source in more than
one split), tile bounds, exclusion bookkeeping, instance/label contract
of materialised mask tiles (integer dtype, background 0, unique
connected instance ids, complete object lists), recorded tile digests,
the dataset digest and, for directories, the integrity inventory.

## Usage

``` r
sg_validate_training_manifest(
  x,
  mask_type = NULL,
  check_files = TRUE,
  error = TRUE
)
```

## Arguments

- x:

  An `sg_dataset_manifest`, `sg_training_set`, a prepared dataset
  directory or a `dataset_manifest.json` path.

- mask_type:

  Optional mask type the consumer requires (e.g. `"instance"` for
  StarDist).

- check_files:

  Logical; read and check tile files of a directory.

- error:

  Logical; signal the first failure instead of reporting it.

## Value

An `sg_validation_report` with `ok`, `checks` and `error`.

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
# The synthetic example mask contains overlapping ellipses; split them
# into separate instances first.
msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                         disconnected = "split")
man <- sg_dataset_manifest(list(list(image = img, mask = msk,
                                     subject_id = "A")),
                           tile_size = 32L, min_objects = 0L,
                           split = c(train = 1, validation = 0, test = 0))
sg_validate_training_manifest(man)$ok
#> [1] TRUE
```
