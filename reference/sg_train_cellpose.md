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
  verbose = TRUE,
  channels = list(cytoplasm = 0L, nucleus = 1L)
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

- channels:

  Named list of `cytoplasm` and `nucleus` channel selectors, using the
  same defaults and convention as
  [`sg_segment_cellpose()`](https://cttir.github.io/segmantR/reference/sg_segment_cellpose.md).
  Use the same selectors when applying the trained model. Zero selects
  grayscale/no nuclear channel; positive values are one-based channels.
  Grayscale selection ignores the nuclear selector and supplies a zero
  second channel, following Cellpose's convention.

## Value

An `sg_trained_model` object.

## Details

Uses the Cellpose 3 `train_seg` API on CPU. Images are converted with
the same channel selection as inference. Cellpose's default training
filter requires at least five labeled objects per retained training
image. The returned model path names the actual saved weights file.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires Python with Cellpose (see sg_setup_python())
pair <- list(image = sg_example_image("fluorescence_nuclei"),
             mask = sg_example_mask("fluorescence_nuclei"))
trained <- sg_train_cellpose(list(pair), base_model = "cyto3",
                             n_epochs = 10L)
} # }
```
