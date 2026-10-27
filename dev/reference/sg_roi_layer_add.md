# Add an ROI to a layer

Add an ROI to a layer

## Usage

``` r
sg_roi_layer_add(layer, roi, call = rlang::caller_env())
```

## Arguments

- layer:

  An
  [sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md).

- roi:

  An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md).

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md)
with the ROI appended. The label vocabulary and colour mapping are
extended if the ROI introduces a new label. A colliding ROI identifier
is re-minted to preserve uniqueness. The input is unchanged.

## See also

Other layers:
[`sg_roi_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md),
[`sg_roi_layer_n()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_n.md),
[`sg_roi_layer_remove()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_remove.md),
[`sg_roi_layer_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_rois.md),
[`sg_roi_style()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_style.md)

## Examples

``` r
lyr <- sg_roi_layer("tumour", labels = "tumour")
lyr <- sg_roi_layer_add(lyr, sg_roi_rect(0, 0, 10, 10, label = "tumour"))
sg_roi_layer_n(lyr)
#> [1] 1
```
