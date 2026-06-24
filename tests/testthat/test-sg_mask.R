test_that("new_sg_mask counts cells correctly", {
  labels <- matrix(c(0L, 0L, 1L, 1L, 0L, 2L, 2L, 0L, 3L), nrow = 3L)
  mask <- new_sg_mask(labels)
  expect_s3_class(mask, "sg_mask")
  expect_equal(mask$n_cells, 3L)
  expect_equal(dim(mask), c(3L, 3L))
})

test_that("new_sg_mask handles empty masks", {
  mask <- new_sg_mask(matrix(0L, 4L, 4L))
  expect_equal(mask$n_cells, 0L)
})

test_that("new_sg_mask coerces numeric to integer", {
  mask <- new_sg_mask(matrix(c(0, 1, 2, 0), 2L, 2L))
  expect_true(is.integer(mask$labels))
})

test_that("new_sg_mask stores image_id and model_info", {
  mask <- new_sg_mask(matrix(0L, 3, 3), image_id = "img7",
                      model_info = list(method = "threshold:otsu"))
  expect_equal(mask$image_id, "img7")
  expect_equal(mask$model_info$method, "threshold:otsu")
})

test_that("new_sg_mask defaults model_info to empty list", {
  mask <- new_sg_mask(matrix(0L, 3, 3))
  expect_equal(mask$model_info, list())
})

test_that("new_sg_mask errors on non-matrix without dim", {
  expect_error(new_sg_mask(1:5), "must be a matrix")
})

test_that("print.sg_mask prints dims, count and method", {
  m <- new_sg_mask(matrix(c(0L, 1L, 1L, 2L), 2, 2),
                   model_info = list(method = "watershed"))
  expect_snapshot(print(m))
  expect_invisible(print(m))
})

test_that("summary.sg_mask returns a per-cell area tibble", {
  labels <- matrix(0L, 6, 6)
  labels[1:2, 1:2] <- 1L
  labels[4:6, 4:6] <- 2L
  res <- summary(new_sg_mask(labels))
  expect_s3_class(res, "tbl_df")
  expect_equal(res$cell_id, c(1L, 2L))
  expect_equal(res$area, c(4L, 9L))
})

test_that("summary.sg_mask reports empty masks", {
  expect_snapshot(summary(new_sg_mask(matrix(0L, 4, 4))))
  expect_null(suppressMessages(summary(new_sg_mask(matrix(0L, 4, 4)))))
})
