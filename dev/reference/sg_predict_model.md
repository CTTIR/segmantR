# Predict with a trained model

Backend-agnostic prediction facade. The model's backend selects the
protocol (`stardist.2d.v1` or `cellpose.2d.v1`); the run goes through
[`sg_protocol_run()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_run.md)
so parameters are validated and recorded, the backend is checked at the
point of use, and the resulting mask is **staged** with the model digest
in its provenance. Predictions never overwrite reviewed masks; use
[`sg_replace_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_review.md)
to adopt a reviewed result explicitly.

## Usage

``` r
sg_predict_model(model, image, ..., protocol = NULL, output = c("mask", "run"))
```

## Arguments

- model:

  An `sg_trained_model` or the path of a `.segmantR` archive (loaded
  with integrity verification).

- image:

  An `sg_image`.

- ...:

  Protocol parameters (see `sg_protocol_schema(protocol)`).

- protocol:

  Optional protocol id overriding the backend default.

- output:

  `"mask"` or `"run"` (see
  [`sg_protocol_run()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_run.md)).

## Value

A staged `sg_mask` or an `sg_run`.

## Examples

``` r
# \donttest{
mdl <- new_sg_trained_model(tempfile("model"), backend = "stardist",
                            base_model = "none", training_metrics = list())
img <- sg_example_image("fluorescence_nuclei")
run <- sg_predict_model(mdl, img, output = "run")
#> Downloading uv...
#> Done!
run$record$status
#> [1] "unavailable"
# }
```
