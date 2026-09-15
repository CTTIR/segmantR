# Build the segmantR Shiny application

Returns a `shiny.appobj` built from package code, with explicit input
objects instead of global options. The app offers image/channel/band
selection, a protocol picker with a parameter form generated from the
protocol registry, mask overlay, backend status for optional DNN
protocols, a staged/reviewed workflow with explicit overwrite
confirmation, and export of a neutral interchange bundle. There is no
code entry of any kind.

## Usage

``` r
sg_app(input = NULL, state = NULL, control = "off", ...)
```

## Arguments

- input:

  `NULL`, an `sg_image`, an `sg_mask`, a list with `image` and/or
  `mask`, or the path of an interchange bundle (imported as staged).

- state:

  Optional list with initial `protocol` (id) and `parameters` (named
  list of overrides).

- control:

  `"off"`. The local control service (`segmantR-control-v1`) is planned
  and not implemented; other values signal an `sg_capability_error`.

- ...:

  Options: `read_only` (logical, disables running and review).

## Value

A `shiny.appobj`.

## See also

[`sg_run_app()`](https://cttir.github.io/segmantR/dev/reference/sg_run_app.md),
[`sg_control_capabilities()`](https://cttir.github.io/segmantR/dev/reference/sg_control_capabilities.md)

## Examples

``` r
app <- sg_app(list(image = sg_example_image("fluorescence_nuclei")))
class(app)
#> [1] "shiny.appobj"
if (FALSE) { # \dontrun{
shiny::runApp(app)
} # }
```
