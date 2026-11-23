# Bar chart of evaluation metrics

Displays a bar chart of segmentation evaluation metrics on a 0 to 1
scale, such as Dice, Jaccard, panoptic quality and F1.

## Usage

``` r
sg_plot_metrics(eval_result)
```

## Arguments

- eval_result:

  A data frame with columns `metric` and `value`, for example from
  [`sg_evaluate_segmentation()`](https://cttir.github.io/segmantR/reference/sg_evaluate_segmentation.md).

## Value

A `ggplot2` object.

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
reference <- sg_example_mask("fluorescence_nuclei")
otsu <- sg_segment_threshold(img, min_area = 5)
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
sg_plot_metrics(sg_evaluate_segmentation(otsu, reference))
#> ✔ Computed 7 segmentation metrics.
```
