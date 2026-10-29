# Set up a Python environment for deep learning backends

Creates and configures a Python virtual environment or conda environment
with the requested deep learning segmentation backends (Cellpose,
StarDist) installed.

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

  Logical; if `TRUE` (default), installs the GPU-capable `tensorflow`
  build for StarDist instead of `tensorflow-cpu`. Cellpose is always
  installed as `cellpose`; it uses a GPU when the installed PyTorch
  build supports it.

## Value

Invisibly returns `TRUE` on success.

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
sg_setup_python(backends = "cellpose")
} # }
```
