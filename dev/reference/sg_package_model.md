# Package a trained model for sharing

Creates a `.segmantR` archive (ZIP format) containing model weights, a
`model_card.json`, and optionally training data.

## Usage

``` r
sg_package_model(
  trained_model,
  output_path,
  name = NULL,
  description = NULL,
  include_training_data = FALSE,
  format = c("segmantR", "cellpose", "both"),
  embed_weights = TRUE,
  license = NULL,
  overwrite = TRUE
)
```

## Arguments

- trained_model:

  An `sg_trained_model` object.

- output_path:

  Character. Path for the output archive file.

- name:

  Character or `NULL`. Human-readable model name.

- description:

  Character or `NULL`. Short description of the model.

- include_training_data:

  Logical. Include training data in the archive? Default `FALSE`. When
  `TRUE`, the dataset manifest (not the pixels) is included; tiles stay
  in their own integrity-checked dataset directory.

- format:

  Character. Archive format: `"segmantR"` (default), `"cellpose"`, or
  `"both"`.

- embed_weights:

  Logical; copy weights into the archive (default) or record them as a
  hashed reference relative to the archive directory.

- license:

  Optional license list (`id`, `name`, `source`, `text`); defaults to
  `trained_model$license`.

- overwrite:

  Logical; replace an existing archive.

## Value

The output file path, returned invisibly.

## Details

The archive keeps relative paths and contains a versioned
`model_card.json` (schema `segmantR-model-card-v1`, still carrying the
fields written by segmantR 0.1.0), `runtime.json`,
`dataset_manifest.json` when the model has one, `license.json` when a
license is given, the weights under `weights/` (or a hashed relative
reference when `embed_weights = FALSE`) and `checksums.sha256` covering
every file. Python environments are never copied into a bundle.

## Examples

``` r
# \donttest{
mdl <- new_sg_trained_model(
  model_path = tempdir(),
  backend = "cellpose",
  base_model = "cyto3",
  training_metrics = list(n_epochs = 50L)
)
out <- sg_package_model(mdl, tempfile(fileext = ".segmantR"))
#> ✔ Model packaged to /tmp/Rtmph7ZNKs/file20971dfbc138.segmantR.
# }
```
