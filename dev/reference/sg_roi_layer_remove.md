# Remove an ROI from a layer

Remove an ROI from a layer

## Usage

``` r
sg_roi_layer_remove(layer, id, call = rlang::caller_env())
```

## Arguments

- layer:

  An
  [sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md).

- id:

  Single string ROI identifier.

- call:

  The calling environment, for error reporting.

## Value

A new
[sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md)
without the identified ROI. Warns if the ROI is not present and returns
the layer unchanged.

## See also

Other layers:
[`sg_roi_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md),
[`sg_roi_layer_add()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_add.md),
[`sg_roi_layer_n()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_n.md),
[`sg_roi_layer_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_rois.md),
[`sg_roi_style()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_style.md)
