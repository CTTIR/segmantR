# Add a layer to a project

Add a layer to a project

## Usage

``` r
sg_roi_add_layer(project, layer, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md).

- layer:

  An
  [sg_roi_layer](https://cttir.github.io/segmantR/reference/sg_roi_layer.md)
  with a name not already used in the project.

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md)
with the layer added. The input is unchanged.

## See also

Other projects:
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/reference/sg_roi_validate.md)

## Examples

``` r
proj <- sg_roi_project(sg_roi_frame(c(20, 20)))
proj <- sg_roi_add_layer(proj, sg_roi_layer("tissue"))
names(proj$layers)
#> [1] "tissue"
```
