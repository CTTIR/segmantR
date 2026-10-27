# Summarise a project

Summarise a project

## Usage

``` r
sg_roi_summary(project, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- call:

  The calling environment, for error reporting.

## Value

An `sg_roi_summary` object: a list with `n_layers`, `n_rois`, per-label
ROI counts, and total area per label.

## See also

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)

## Examples

``` r
sg_roi_summary(sg_roi_project(sg_roi_frame(c(20, 20)), sg_roi_layer_add(sg_roi_layer("tissue"), sg_roi_rect(2, 2, 8, 8, "tissue"))))
#> <sg_roi_summary> NA
#> layers: 1  |  ROIs: 1
#>   "tissue": 1 ROI, area 36 px
```
