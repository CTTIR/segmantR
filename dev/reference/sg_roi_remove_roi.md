# Remove an ROI from a project

Remove an ROI from a project

## Usage

``` r
sg_roi_remove_roi(project, id, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi.html).

- id:

  Single string ROI identifier.

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi.html)
without the identified ROI. Warns and returns the project unchanged if
the identifier is not found.

## See also

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/reference/sg_roi.html),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_layer.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/reference/sg_roi.html),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)
