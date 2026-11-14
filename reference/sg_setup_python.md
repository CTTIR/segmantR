# Set up a Python environment for deep learning backends

Creates and configures a Python virtual environment or conda environment
with the requested deep learning segmentation backends (Cellpose,
StarDist) installed. StarDist setup also installs TensorBoard for its
training log callbacks.

## Usage

``` r
sg_setup_python(
  envname = "segmantr",
  method = c("auto", "conda", "virtualenv"),
  backends = c("cellpose", "stardist"),
  gpu = TRUE
)
```

## Arguments

- envname:

  Character string naming the Python environment. Default is
  `"segmantr"`.

- method:

  Character string specifying the environment type. One of `"auto"`
  (default), `"conda"`, or `"virtualenv"`.

- backends:

  Character vector of backends to install. Supported values are
  `"cellpose"` and `"stardist"`.

- gpu:

  Logical; selects the TensorFlow distribution for StarDist. On macOS,
  installs `tensorflow` for either value because `tensorflow-cpu` does
  not provide macOS wheels. Elsewhere, `TRUE` (default) selects
  `tensorflow` and `FALSE` selects `tensorflow-cpu`. This does not
  guarantee GPU support or select an inference device; available devices
  depend on the platform and installed runtime. Cellpose is installed as
  `cellpose>=3,<4`; it uses a GPU when the installed PyTorch build
  supports it.

## Value

Invisibly returns `TRUE` on success.

## Cellpose compatibility

The named legacy models require Cellpose 3.x. Setup constrains the
installation to `cellpose>=3,<4`, including when updating an existing
environment. Cellpose 4 uses a different model/API and is rejected
before model loading; it is not substituted for the requested legacy
model. Restart R after changing an environment already loaded by
reticulate.

## Selecting Python

segmantR never starts, downloads or installs Python by itself; without a
configured Python, recent versions of 'reticulate' would provision one
with 'uv'. The deep learning backends count as available only when
Python is already running in the session (for example after
`reticulate::use_virtualenv("segmantr")` and
[`reticulate::py_config()`](https://rstudio.github.io/reticulate/reference/py_config.html)),
when the environment variable `RETICULATE_PYTHON` or
`RETICULATE_PYTHON_ENV` names a Python, or when the option
`segmantR.python` is `TRUE`, which lets 'reticulate' find (or provision)
a Python on first use.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires Python and network access; installs Python modules
sg_setup_python(backends = "cellpose")
} # }
```
