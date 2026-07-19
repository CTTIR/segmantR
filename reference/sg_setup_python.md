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

  Logical; if `TRUE` (default), attempts to install GPU-enabled versions
  of the backends.

## Value

Invisibly returns `TRUE` on success.

## Examples

``` r
# \donttest{
sg_setup_python(backends = "cellpose")
#> ℹ Setting up Python environment "segmantr".
#> ℹ Method: "auto", GPU: TRUE.
#> + /usr/share/miniconda/bin/conda create --yes --name segmantr 'python=3.12' --quiet -c conda-forge
#> ℹ Installing Python packages: "cellpose[gui]".
#> + /usr/share/miniconda/bin/conda install --yes --name segmantr -c conda-forge 'cellpose[gui]'
#> ✔ Python environment "segmantr" is ready.
#> ℹ Use `reticulate::use_virtualenv('segmantr')` to activate.
# }
```
