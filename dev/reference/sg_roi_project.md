# Create an annotation project

Create an annotation project

## Usage

``` r
sg_roi_project(image, layers = list(), ..., call = rlang::caller_env())
```

## Arguments

- image:

  An
  [sg_roi_frame](https://cttir.github.io/segmantR/dev/reference/sg_roi_frame.md)
  the annotations refer to.

- layers:

  An
  [sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md),
  a list of them, or an empty list (default).

- ...:

  Additional named project metadata (e.g. `name`, `description`).

- call:

  The calling environment, for error reporting.

## Value

An sg_roi_project bundling the image, layers, metadata, and provenance
(creation time, `segmantR` version, R version, author, and an edit log).

## See also

[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask.md)

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layers.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_remove_roi.md),
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)

## Examples

``` r
sg_roi_project(sg_roi_frame(c(100, 100)), sg_roi_layer("tissue"))
#> <sg_roi_project> (unnamed)
#> image: ""
#> layers: 1  |  ROIs: 0
#>   tissue: 0 ROIs, labels 
```
