# Fine-tune a Cellpose model on user-corrected masks

Trains (fine-tunes) a Cellpose segmentation model using corrected
image-mask pairs provided by the user. Requires a working Python
environment with Cellpose installed (see
[`sg_setup_python()`](https://cttir.github.io/segmantR/reference/sg_setup_python.md)).

## Usage

``` r
sg_train_cellpose(
  training_data,
  base_model = "cyto3",
  n_epochs = 100L,
  learning_rate = 0.1,
  save_path = NULL,
  verbose = TRUE
)
```

## Arguments

- training_data:

  A list of training pairs. Each element must be a list with `$image`
  (`sg_image`) and `$mask` (`sg_mask`).

- base_model:

  Character. Cellpose base model to fine-tune. Default `"cyto3"`.

- n_epochs:

  Integer. Number of training epochs. Default `100L`.

- learning_rate:

  Numeric. Learning rate. Default `0.1`.

- save_path:

  Character or `NULL`. Directory to save the trained model. When `NULL`,
  a temporary directory is used.

- verbose:

  Logical. Print training progress? Default `TRUE`.

## Value

An `sg_trained_model` object.

## Examples

``` r
# \donttest{
# Requires Python + Cellpose:
# trained <- sg_train_cellpose(training_data, base_model = "cyto3")
# }
```
