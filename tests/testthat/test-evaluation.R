pred_gt <- function() {
  pred <- matrix(0L, 20, 20); pred[3:8, 3:8] <- 1L; pred[12:18, 12:18] <- 2L
  gt   <- matrix(0L, 20, 20); gt[3:9, 3:9] <- 1L; gt[12:17, 12:17] <- 2L
  list(pred = new_sg_mask(pred), gt = new_sg_mask(gt))
}

test_that("sg_evaluate_segmentation computes all metrics", {
  pg <- pred_gt()
  res <- sg_evaluate_segmentation(pg$pred, pg$gt)
  expect_s3_class(res, "sg_eval")
  expect_setequal(res$metric,
                  c("dice", "jaccard", "aji", "panoptic_quality",
                    "ap50", "ap75", "f1_detection"))
  expect_true(all(res$value >= 0 & res$value <= 1))
})

test_that("identical masks score 1 on dice and jaccard", {
  m <- sg_example_mask("he_breast")
  res <- sg_evaluate_segmentation(m, m, metrics = c("dice", "jaccard"))
  expect_equal(res$value[res$metric == "dice"], 1)
  expect_equal(res$value[res$metric == "jaccard"], 1)
})

test_that("identical masks score 1 on instance metrics", {
  m <- new_sg_mask({
    l <- matrix(0L, 20, 20); l[3:8, 3:8] <- 1L; l[12:18, 12:18] <- 2L; l
  })
  res <- sg_evaluate_segmentation(m, m,
                                  metrics = c("aji", "panoptic_quality",
                                              "f1_detection"))
  expect_equal(res$value[res$metric == "f1_detection"], 1)
  expect_equal(res$value[res$metric == "aji"], 1)
})

test_that("two empty masks score 1 (perfect agreement)", {
  e <- new_sg_mask(matrix(0L, 10, 10))
  res <- sg_evaluate_segmentation(e, e)
  expect_true(all(res$value == 1))
})

test_that("empty-vs-nonempty masks score 0 on instance metrics", {
  e <- new_sg_mask(matrix(0L, 20, 20))
  m <- new_sg_mask({ l <- matrix(0L, 20, 20); l[3:8, 3:8] <- 1L; l })
  res <- sg_evaluate_segmentation(e, m,
                                  metrics = c("aji", "panoptic_quality",
                                              "ap50", "ap75", "f1_detection"))
  expect_true(all(res$value == 0))
})

test_that("sg_evaluate_segmentation validates classes and dimensions", {
  m <- new_sg_mask(matrix(0L, 4, 4))
  expect_error(sg_evaluate_segmentation("x", m), "predicted")
  expect_error(sg_evaluate_segmentation(m, "y"), "ground_truth")
  expect_error(
    sg_evaluate_segmentation(new_sg_mask(matrix(0L, 4, 4)),
                             new_sg_mask(matrix(0L, 5, 5))),
    "same dimensions"
  )
})

test_that("print.sg_eval is invisible and snapshot-stable", {
  pg <- pred_gt()
  res <- sg_evaluate_segmentation(pg$pred, pg$gt, metrics = c("dice", "jaccard"))
  expect_invisible(print(res))
  expect_snapshot(print(res))
})

test_that("evaluation metrics are reproducible", {
  pg <- pred_gt()
  res <- sg_evaluate_segmentation(pg$pred, pg$gt)
  expect_snapshot_value(round(res$value, 6), style = "serialize")
})

test_that("ap50 and ap75 are TP / (TP + FP + FN), not F1", {
  p <- matrix(0L, 20, 20)
  p[2:5, 2:5] <- 1L
  p[8:11, 8:11] <- 2L
  p[15:18, 15:18] <- 3L
  g <- matrix(0L, 20, 20)
  g[2:5, 2:5] <- 1L
  res <- suppressMessages(sg_evaluate_segmentation(
    new_sg_mask(p), new_sg_mask(g), metrics = c("ap50", "ap75", "f1_detection")
  ))
  # one true positive, two false positives, no false negatives
  expect_equal(res$value[res$metric == "ap50"], 1 / 3)
  expect_equal(res$value[res$metric == "ap75"], 1 / 3)
  expect_equal(res$value[res$metric == "f1_detection"], 0.5)
})

# ---- regression tests -------------------------------------------------------

test_that("instance overlap equals the pairwise definition", {
  withr::local_seed(20261123)
  n <- 30L
  rand_labels <- function(k, step) {
    m <- matrix(0L, n, n)
    for (i in seq_len(k)) {
      r <- sample(n - 6L, 1L)
      c <- sample(n - 6L, 1L)
      m[r:(r + sample(2:6, 1L)), c:(c + sample(2:6, 1L))] <- i * step
    }
    m
  }
  for (rep in 1:5) {
    pred <- rand_labels(8L, 3L)  # sparse label ids
    gt <- rand_labels(6L, 1L)
    pred_ids <- segmantR:::.sg_label_ids(pred)
    gt_ids <- segmantR:::.sg_label_ids(gt)
    ov <- segmantR:::.sg_instance_overlap(pred, gt, pred_ids, gt_ids)

    expected <- matrix(0, length(pred_ids), length(gt_ids))
    for (p in seq_along(pred_ids)) {
      for (g in seq_along(gt_ids)) {
        a <- pred == pred_ids[p]
        b <- gt == gt_ids[g]
        expected[p, g] <- sum(a & b) / sum(a | b)
      }
    }
    expect_identical(ov$iou, expected)
    expect_equal(ov$area_pred,
                 vapply(pred_ids, function(i) sum(pred == i), integer(1)))
    expect_equal(ov$area_gt,
                 vapply(gt_ids, function(i) sum(gt == i), integer(1)))
  }
})

test_that("metrics have their hand-computed values for a small example", {
  # prediction: A (16 px) and B (16 px); ground truth: A' (20 px, contains A)
  # and C (9 px, disjoint from every prediction)
  p <- matrix(0L, 20, 20)
  p[2:5, 2:5] <- 1L
  p[10:13, 10:13] <- 2L
  g <- matrix(0L, 20, 20)
  g[2:6, 2:5] <- 5L
  g[16:18, 16:18] <- 9L
  res <- suppressMessages(sg_evaluate_segmentation(new_sg_mask(p),
                                                   new_sg_mask(g)))
  val <- stats::setNames(res$value, res$metric)
  # pixels: |P| = 32, |G| = 29, |P and G| = 16, |P or G| = 45
  expect_equal(val[["dice"]], 2 * 16 / (32 + 29))
  expect_equal(val[["jaccard"]], 16 / 45)
  # AJI: A' matched to A (16 / 20); C unmatched (+9); B unused (+16)
  expect_equal(val[["aji"]], 16 / (20 + 9 + 16))
  # one match with IoU 0.8, one false positive, one false negative
  expect_equal(val[["panoptic_quality"]], 0.8 * (1 / 2))
  expect_equal(val[["ap50"]], 1 / 3)
  expect_equal(val[["ap75"]], 1 / 3)
  expect_equal(val[["f1_detection"]], 0.5)
})

test_that("evaluation stays fast for many cells", {
  skip_on_cran()
  lab <- matrix(0L, 240, 240)
  k <- 0L
  for (i in seq(3, 230, by = 12)) {
    for (j in seq(3, 230, by = 12)) {
      k <- k + 1L
      lab[i:(i + 8), j:(j + 8)] <- k
    }
  }
  shifted <- rbind(lab[-(1:2), ], lab[1:2, ])
  elapsed <- system.time(
    res <- suppressMessages(sg_evaluate_segmentation(new_sg_mask(shifted),
                                                     new_sg_mask(lab)))
  )[["elapsed"]]
  # 400 cells took minutes with one whole-image comparison per cell pair
  expect_lt(elapsed, 10)
  expect_equal(res$value[res$metric == "f1_detection"], 1)
})
