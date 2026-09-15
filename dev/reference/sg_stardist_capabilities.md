# StarDist adapter capabilities

Reports which StarDist options can be mapped for Python (reticulate) and
for the QuPath StarDist extension, for a detected or declared QuPath and
extension version. Detection reads installation files only (QuPath is
not started). Options are `supported` for extension versions at or above
the documented minimum, `unknown` for older versions and `unavailable`
when the extension is missing.

## Usage

``` r
sg_stardist_capabilities(
  qupath_version = NULL,
  extension_version = NULL,
  check_python = FALSE
)
```

## Arguments

- qupath_version:

  Optional QuPath version to evaluate (default: detected installation).

- extension_version:

  Optional StarDist extension version (default: detected jar in the
  QuPath user directory).

- check_python:

  Logical; probe the Python `stardist` module (initialises Python).

## Value

An `sg_stardist_capabilities` list with `qupath`, `extension`, `python`,
`options` (tibble) and `parameters` (tibble from
[`sg_stardist_parameter_map()`](https://cttir.github.io/segmantR/dev/reference/sg_stardist_parameter_map.md)
for both targets).

## Examples

``` r
caps <- sg_stardist_capabilities(qupath_version = "0.7.0",
                                 extension_version = "0.6.0")
caps$options[, c("option", "status")]
#> # A tibble: 14 × 2
#>    option               status   
#>    <chr>                <chr>    
#>  1 threshold            supported
#>  2 channels             supported
#>  3 normalizePercentiles supported
#>  4 preprocessGlobal     supported
#>  5 pixelSize            supported
#>  6 tileSize             supported
#>  7 includeProbability   supported
#>  8 cellExpansion        supported
#>  9 cellConstrainScale   supported
#> 10 createAnnotations    supported
#> 11 classify             supported
#> 12 measureShape         supported
#> 13 measureIntensity     supported
#> 14 nThreads             supported
```
