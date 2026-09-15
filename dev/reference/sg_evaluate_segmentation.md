# Evaluate segmentation quality

Computes standard instance segmentation metrics by comparing a predicted
mask against a ground truth mask.

## Usage

``` r
sg_evaluate_segmentation(
  predicted,
  ground_truth,
  metrics = c("dice", "jaccard", "aji", "panoptic_quality", "ap50", "ap75",
    "f1_detection")
)
```

## Arguments

- predicted:

  An `sg_mask` object with predicted segmentation.

- ground_truth:

  An `sg_mask` object with ground truth segmentation.

- metrics:

  Character vector of metrics to compute. One or more of `"dice"`,
  `"jaccard"`, `"aji"`, `"panoptic_quality"`, `"ap50"`, `"ap75"`,
  `"f1_detection"`. Default is all.

## Value

An `sg_eval` S3 object (a tibble with columns `metric` and `value`) with
a custom print method.

## Examples

``` r
pred_labels <- matrix(0L, nrow = 20, ncol = 20)
pred_labels[3:8, 3:8] <- 1L
pred_labels[12:18, 12:18] <- 2L
gt_labels <- matrix(0L, nrow = 20, ncol = 20)
gt_labels[3:9, 3:9] <- 1L
gt_labels[12:17, 12:17] <- 2L
pred <- new_sg_mask(pred_labels)
gt <- new_sg_mask(gt_labels)
result <- sg_evaluate_segmentation(pred, gt)
#> ✔ Computed 7 segmentation metrics.
print(result)
#> <sg_eval> — Segmentation Evaluation
#> ────────────────────────────────────────────────────────────────────────────────
#> dice: 0.8471
#> jaccard: 0.7347
#> aji: 0.7347
#> panoptic_quality: 0.7347
#> ap50: 1
#> ap75: 0
#> f1_detection: 1
#> ────────────────────────────────────────────────────────────────────────────────
```
