# Train a StarDist 2D model

Trains a StarDist model on a prepared instance dataset. All data checks
run in R before Python is touched: the dataset must be an instance
dataset without split leakage, every training mask must be integer with
background 0 and one connected part per positive id, and the training
split must not be empty. Only then is the optional Python runtime
(`stardist`, `tensorflow`, `csbdeep` through reticulate) checked; when
it is missing an `sg_capability_error` with code
`CAPABILITY_UNAVAILABLE` and an installation hint is signalled.

## Usage

``` r
sg_train_stardist(
  training_data,
  base_model = NULL,
  n_epochs = 100L,
  steps_per_epoch = 100L,
  learning_rate = 3e-04,
  n_rays = 32L,
  grid = c(2L, 2L),
  normalize = c(1, 99.8),
  save_path = NULL,
  name = "stardist_model",
  model_card = list(),
  seed = 1L,
  verbose = TRUE
)
```

## Arguments

- training_data:

  An `sg_training_set` from
  [`sg_prepare_training_data()`](https://cttir.github.io/segmantR/dev/reference/sg_prepare_training_data.md)
  (in memory or on disk), or the path of a prepared dataset directory.

- base_model:

  Optional pretrained StarDist model name to fine-tune (e.g.
  `"2D_versatile_fluo"`); `NULL` trains from a new configuration.

- n_epochs, steps_per_epoch:

  Training length.

- learning_rate:

  Adam learning rate.

- n_rays:

  Number of radial directions.

- grid:

  Subsampling grid (length 2).

- normalize:

  Percentiles (length 2) for per-tile normalisation, recorded in the
  model card.

- save_path:

  Directory for the trained model (default: a temporary directory).

- name:

  Model name (directory name below `save_path`).

- model_card:

  Model card fields (purpose, data_domain, limitations, license, ...),
  see
  [`new_sg_trained_model()`](https://cttir.github.io/segmantR/dev/reference/new_sg_trained_model.md).

- seed:

  Integer seed passed to the Python random number generators.

- verbose:

  Logical; print progress.

## Value

An `sg_trained_model` with backend `"stardist"`, the dataset manifest,
runtime description and evaluation metrics (validation split thresholds
when available).

## Examples

``` r
# \donttest{
img <- sg_example_image("fluorescence_nuclei")
msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                         disconnected = "split")
ts <- sg_prepare_training_data(
  list(list(image = img, mask = msk, subject_id = "A"),
       list(image = img, mask = msk, subject_id = "B")),
  tile_size = 32L, split = c(train = 0.5, validation = 0.5, test = 0)
)
# Requires Python stardist; otherwise a classified capability error:
try(sg_train_stardist(ts, n_epochs = 1L))
#> Error in .sg_abort_unavailable("StarDist training (Python stardist + tensorflow)",  : 
#>   StarDist training (Python stardist + tensorflow) is not available.
#> ℹ Install the Python packages 'stardist' and 'tensorflow'
#>   (sg_setup_python(backends = 'stardist')).
# }
```
