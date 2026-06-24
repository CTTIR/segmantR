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
