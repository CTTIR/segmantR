# Create a new sg_trained_model object

Constructor for the `sg_trained_model` S3 class, representing a trained
segmentation model with associated metadata.

## Usage

``` r
new_sg_trained_model(
  model_path,
  backend = c("cellpose", "stardist"),
  base_model,
  training_metrics,
  model_card = list(),
  runtime = NULL,
  dataset_manifest = NULL,
  license = NULL,
  representation = "unknown"
)
```

## Arguments

- model_path:

  Character. Path to the trained model weights.

- backend:

  Character. Segmentation backend: `"cellpose"` or `"stardist"`.

- base_model:

  Character. Name of the base model that was fine-tuned.

- training_metrics:

  Named list of training metrics (e.g., loss curve, number of epochs).

- model_card:

  Named list of model card metadata (description, author, intended use,
  etc.). The versioned card written by
  [`sg_package_model()`](https://cttir.github.io/segmantR/dev/reference/sg_package_model.md)
  reads `purpose`, `data_domain`, `channels`, `target_pixel_size_um`,
  `input_value_semantics`, `normalization`, `limitations` (character),
  `evaluation` (named list of metrics) and `license` from here.

- runtime:

  Optional runtime description (list) recorded at training time; never a
  copy of a Python environment.

- dataset_manifest:

  Optional `sg_dataset_manifest` the model was trained on.

- license:

  Optional list with `id` (e.g. an SPDX identifier), `name`, `source`
  and `text`.

- representation:

  Weight representation: `"pb"`, `"savedmodel"`, `"bioimageio"`,
  `"pytorch"`, `"keras"`, `"directory"`, `"file"` or `"unknown"`.

## Value

An object of class `sg_trained_model`.

## Examples

``` r
mdl <- new_sg_trained_model(
  model_path = tempdir(),
  backend = "cellpose",
  base_model = "cyto3",
  training_metrics = list(n_epochs = 100L, final_loss = 0.05)
)
print(mdl)
#> <sg_trained_model>
#> Backend: cellpose
#> Base model: cyto3
#> Model path: /tmp/RtmpDHlkS7
#> Epochs: 100
#> Final loss: 0.05
#> Created: 2026-10-02 06:25:30
```
