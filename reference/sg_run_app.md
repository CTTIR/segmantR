# Launch the segmantR Shiny application

Starts the interactive Shiny application for cell segmentation,
annotation, and model training. The app is bundled under
`inst/shiny/segmantR/`.

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

## Examples

``` r
if (FALSE) { # \dontrun{
sg_run_app()
} # }
```
