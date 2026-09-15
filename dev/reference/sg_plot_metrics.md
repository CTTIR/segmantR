# Bar chart of evaluation metrics

Displays a bar chart of segmentation evaluation metrics such as IoU,
precision, recall, and F1.

## Usage

``` r
sg_plot_metrics(eval_result)
```

## Arguments

- eval_result:

  A data frame with columns `metric` and `value`, e.g., from
  `sg_evaluate()`.

## Value

A `ggplot2` object.

## Examples

``` r
res <- data.frame(
  metric = c("IoU", "Precision", "Recall", "F1"),
  value = c(0.82, 0.90, 0.85, 0.87)
)
p <- sg_plot_metrics(res)
p
```
