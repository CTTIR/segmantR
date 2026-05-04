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
