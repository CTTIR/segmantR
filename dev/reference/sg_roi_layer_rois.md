# Layer ROI table

Layer ROI table

## Usage

``` r
sg_roi_layer_rois(layer, image = NULL, call = rlang::caller_env())
```

## Arguments

- layer:

  An
  [sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md).

- image:

  Optional
  [sg_roi_frame](https://cttir.github.io/segmantR/dev/reference/sg_roi_frame.md)
  for accurate level-0 coordinate transforms.

- call:

  The calling environment, for error reporting.

## Value

An ROI table (see
[`sg_roi_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois.md)
for the column contract). A 0-row table with the same columns when the
layer has no ROIs.

## See also

Other layers:
[`sg_roi_layer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md),
[`sg_roi_layer_add()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_add.md),
[`sg_roi_layer_n()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_n.md),
[`sg_roi_layer_remove()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_remove.md),
[`sg_roi_style()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_style.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(0, 0, 4, 4, label = "tumour"))
lyr <- sg_roi_layer_add(lyr, sg_roi_rect(5, 5, 8, 8, label = "stroma"))
sg_roi_layer_rois(lyr)[, c("label", "area_px")]
#> # A tibble: 2 × 2
#>   label  area_px
#>   <chr>    <dbl>
#> 1 tumour      16
#> 2 stroma       9
```
