# Launch the segmantR Shiny application

Starts the interactive Shiny application for cell segmentation,
annotation, and model training. The app is built by
[`sg_app()`](https://cttir.github.io/segmantR/dev/reference/sg_app.md)
from package code; `inst/shiny/segmantR/app.R` is a thin wrapper for
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html) on the
installed directory.

## Usage

``` r
sg_run_app(image = NULL, mask = NULL, port = NULL, launch.browser = TRUE)
```

## Arguments

- image:

  An `sg_image` object to pre-load, or `NULL`.

- mask:

  An `sg_mask` object to pre-load, or `NULL`.

- port:

  Integer port number, or `NULL` to use the default.

- launch.browser:

  Logical, whether to open the app in a browser (default `TRUE`).

## Value

`NULL`, invisibly.

## Details

For compatibility with code that starts the bundled app directory
directly, the pre-loaded objects are also stored in the option
`segmantR.app_env`;
[`sg_app()`](https://cttir.github.io/segmantR/dev/reference/sg_app.md)
itself does not use options.

## Examples

``` r
if (FALSE) { # \dontrun{
sg_run_app()
} # }
```
