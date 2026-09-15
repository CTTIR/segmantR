# Describe a StarDist model for exchange

Hashes the model files and records representation, channels, pixel size,
normalisation, license and the runtimes that can load the representation
(`.pb` for QuPath/OpenCV, SavedModel for QuPath/TensorFlow, bioimage.io
for the extension's bioimage.io support, a Python model directory for
`stardist`).

## Usage

``` r
sg_stardist_manifest(
  model,
  ...,
  name = NULL,
  channels = NULL,
  n_channels_in = NULL,
  pixel_size_um = NULL,
  normalization = NULL,
  license_id = NULL,
  source = NULL
)
```

## Arguments

- model:

  Path to a `.pb` file, a SavedModel or Python model directory, a
  bioimage.io folder, or an `sg_trained_model` with backend
  `"stardist"`.

- ...:

  Reserved; must be empty.

- name:

  Model name (default: file/directory name).

- channels:

  Optional channel names the model expects.

- n_channels_in:

  Optional number of input channels.

- pixel_size_um:

  Optional pixel size the model was trained for.

- normalization:

  Optional list (e.g.
  `list(method = "percentile", low = 1, high = 99.8)`).

- license_id:

  Optional SPDX identifier.

- source:

  Optional short provenance text (no URLs are fetched).

## Value

An `sg_stardist_manifest` list conforming to
`stardist-model.schema.json`; `digest` follows the integrity inventory
rule and is what `run.json` and the Groovy template verify.

## Examples

``` r
f <- tempfile(fileext = ".pb")
writeBin(as.raw(1:10), f)
sg_stardist_manifest(f, n_channels_in = 1L)$representation
#> [1] "pb"
```
