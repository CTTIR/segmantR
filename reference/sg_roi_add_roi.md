# Add an ROI to a project layer

Add an ROI to a project layer

## Usage

``` r
sg_roi_add_roi(project, layer, roi, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md).

- layer:

  Single string name of the target layer.

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md).

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md)
with the ROI added to the layer. A colliding ROI identifier is re-minted
to keep identifiers unique across the project. The input is unchanged.

## See also

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/reference/sg_roi_add_layer.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/reference/sg_roi_validate.md)

## Examples

``` r
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), sg_roi_layer("tissue"))
proj <- sg_roi_add_roi(proj, "tissue", sg_roi_rect(2, 2, 8, 8, label = "tissue"))
sg_roi_rois(proj)$area_px
#> [1] 36
```
