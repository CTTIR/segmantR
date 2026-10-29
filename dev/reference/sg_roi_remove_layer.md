# Remove a layer from a project

Remove a layer from a project

## Usage

``` r
sg_roi_remove_layer(project, name, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- name:

  Single string layer name.

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md)
without the named layer. The input is unchanged.

## See also

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)

## Examples

``` r
proj <- sg_roi_project(sg_roi_frame(c(20, 20)),
                       list(sg_roi_layer("tumour"), sg_roi_layer("stroma")))
names(sg_roi_remove_layer(proj, "stroma")$layers)
#> [1] "tumour"
```
