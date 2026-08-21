# Display a formatted model card

Prints a human-readable model card for a trained segmentation model and
returns the card contents as a tibble.

## Usage

``` r
sg_model_card(trained_model)
```

## Arguments

- trained_model:

  An `sg_trained_model` object.

## Value

A tibble with columns `field` and `value` representing the model card
contents, returned invisibly.

## Examples

``` r
mdl <- new_sg_trained_model(
  model_path = tempdir(),
  backend = "cellpose",
  base_model = "cyto3",
  training_metrics = list(n_epochs = 100L),
  model_card = list(author = "Test User", tissue = "lung")
)
sg_model_card(mdl)
#> ── Model Card ──────────────────────────────────────────────────────────────────
#> Backend: cellpose
#> Base Model: cyto3
#> Model Path: /tmp/RtmpiQL4KY
#> Created: 2026-08-21 19:51:36
#> Metric: n_epochs: 100
#> author: Test User
#> tissue: lung
#> ────────────────────────────────────────────────────────────────────────────────
```
