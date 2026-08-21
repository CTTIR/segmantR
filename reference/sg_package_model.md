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
  format = c("segmantR", "cellpose", "both")
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

  Logical. Include training data in the archive? Default `FALSE`.

- format:

  Character. Archive format: `"segmantR"` (default), `"cellpose"`, or
  `"both"`.

## Value

The output file path, returned invisibly.

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
#> ✔ Model packaged to /tmp/RtmpiQL4KY/file4a6a73346a4d.segmantR.
# }
```
