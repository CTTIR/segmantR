# Prepare annotation tasks for caller-driven segmentation refinement

Prepares batches of annotation patches for a human-in-the-loop workflow.
This function does not segment images, collect corrections, or retrain a
model. Review the returned tasks, apply corrections, and call the
training functions explicitly when corrected image-mask pairs are
available.

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

  Integer. Number of annotation-task batches. Default `5L`.

- patches_per_round:

  Integer. Patches sampled per round. Default `10L`.

- patch_size:

  Integer. Patch size in pixels. Default `256L`.

- initial_model:

  Character. Initial model name. Default `"cyto3"`.

## Value

An `sg_hitl_result` S3 object with elements `$rounds` (list of
annotation-task records), `$final_model` (the unchanged
`initial_model`), and `$metrics` (task counts, backend, initial model,
and timestamp). The result does not contain training or accuracy
metrics.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires Python with Cellpose; prepares annotation tasks only
img <- sg_example_image("fluorescence_nuclei")
result <- sg_active_learning_loop(img, n_rounds = 3L,
                                  patches_per_round = 2L, patch_size = 32L)
} # }
```
