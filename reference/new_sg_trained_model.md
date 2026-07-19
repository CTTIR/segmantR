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
  model_card = list()
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
  etc.).

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
#> Model path: /tmp/RtmpKoa2dt
#> Epochs: 100
#> Final loss: 0.05
#> Created: 2026-07-19 08:53:41
```
