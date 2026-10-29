# Validate a project's invariants

Check that layer names are unique, ROI identifiers are unique across the
project, and all geometries are valid.

## Usage

``` r
sg_roi_validate(project, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- call:

  The calling environment, for error reporting.

## Value

The project, invisibly, if valid; otherwise an error describing the
violated invariant.

## See also

[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_geometry.md)

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_summary.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
sg_roi_validate(proj)
```
