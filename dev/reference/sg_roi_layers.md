# Layer summary table

Layer summary table

## Usage

``` r
sg_roi_layers(project, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- call:

  The calling environment, for error reporting.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per layer and the columns `name` (character), `n_rois`
(integer), `labels` (list of character), `visible` (logical), `locked`
(logical), and `z` (integer). A 0-row tibble with these columns when the
project has no layers.

## See also

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)

## Examples

``` r
proj <- sg_roi_project(sg_roi_frame(c(20, 20)),
                       list(sg_roi_layer("tumour"), sg_roi_layer("stroma")))
sg_roi_layers(proj)
#> # A tibble: 2 × 6
#>   name   n_rois labels    visible locked     z
#>   <chr>   <int> <list>    <lgl>   <lgl>  <int>
#> 1 tumour      0 <chr [0]> TRUE    FALSE      1
#> 2 stroma      0 <chr [0]> TRUE    FALSE      1
```
