# Run an active learning loop for iterative segmentation refinement

Orchestrates a human-in-the-loop (HITL) active learning workflow:
segment, review, correct, retrain, repeat.

## Usage

``` r
sg_active_learning_loop(
  image,
  model = "cellpose",
  n_rounds = 5L,
  patches_per_round = 10L,
  patch_size = 256L,
  initial_model = "cyto3"
)
```

## Arguments

- image:

  An `sg_image` object.

- model:

  Character. Segmentation backend to use. Currently only `"cellpose"` is
  supported. Default `"cellpose"`.

- n_rounds:

  Integer. Number of active learning rounds. Default `5L`.

- patches_per_round:

  Integer. Patches sampled per round. Default `10L`.

- patch_size:

  Integer. Patch size in pixels. Default `256L`.

- initial_model:

  Character. Initial model name. Default `"cyto3"`.

## Value

An `sg_hitl_result` S3 object with elements `$rounds` (list of per-round
results), `$final_model` (trained model path or object), and `$metrics`
(training metrics across rounds).

## Examples

``` r
# \donttest{
# Requires Python + Cellpose and interactive session:
# result <- sg_active_learning_loop(image, n_rounds = 3L)
# }
```
