# Remove an ROI from a project

Remove an ROI from a project

## Usage

``` r
sg_roi_remove_roi(project, id, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- id:

  Single string ROI identifier.

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md)
without the identified ROI. Warns and returns the project unchanged if
the identifier is not found.

## See also

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_layer.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue", id = "r1"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
nrow(sg_roi_rois(sg_roi_remove_roi(proj, "r1")))
#> [1] 0
```
