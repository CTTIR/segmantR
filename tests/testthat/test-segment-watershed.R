test_that("sg_segment_watershed returns an sg_mask", {
  set.seed(42)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  msk <- sg_segment_watershed(img, seed_method = "distance", h = 0.3)
  expect_s3_class(msk, "sg_mask")
  expect_equal(msk$model_info$method, "watershed")
})

test_that("sg_segment_watershed supports the dilation expansion method", {
  set.seed(42)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  msk <- sg_segment_watershed(img, seed_method = "distance", h = 0.3,
                              expand_method = "dilation", expand_pixels = 2L)
  expect_s3_class(msk, "sg_mask")
})

test_that("sg_segment_watershed accepts a membrane channel", {
  set.seed(42)
  img <- new_sg_image(array(stats::runif(800), dim = c(20, 20, 2)),
                      channels = c("nuc", "mem"))
  msk <- sg_segment_watershed(img, channel = 1L, membrane_channel = 2L,
                              seed_method = "distance", h = 0.3)
  expect_s3_class(msk, "sg_mask")
})

test_that("sg_segment_watershed handles zero expansion", {
  set.seed(42)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  msk <- sg_segment_watershed(img, seed_method = "distance", h = 0.3,
                              expand_pixels = 0L)
  expect_s3_class(msk, "sg_mask")
})

test_that("sg_segment_watershed validates its image argument", {
  expect_error(sg_segment_watershed("x"))
})

test_that("sg_segment_propagate expands nuclear seeds", {
  set.seed(42)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  seeds <- matrix(0L, 20, 20)
  seeds[5, 5] <- 1L
  seeds[15, 15] <- 2L
  result <- sg_segment_propagate(img, nuclear_mask = new_sg_mask(seeds))
  expect_s3_class(result, "sg_mask")
  expect_gte(result$n_cells, 1L)
})

test_that("sg_segment_propagate uses a membrane image when provided", {
  skip_if(requireNamespace("EBImage", quietly = TRUE), "EBImage installed")
  set.seed(42)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  membrane <- new_sg_image(matrix(stats::runif(400), 20, 20))
  seeds <- matrix(0L, 20, 20)
  seeds[5, 5] <- 1L
  result <- sg_segment_propagate(img, nuclear_mask = new_sg_mask(seeds),
                                 membrane_image = membrane)
  expect_s3_class(result, "sg_mask")
  expect_equal(result$model_info$method, "propagate:voronoi_r")
})

test_that("sg_segment_propagate falls back when EBImage::propagate fails", {
  local_mocked_bindings(.check_ebimage = function() TRUE)
  # EBImage is not installed, so EBImage::propagate() raises inside tryCatch
  # and the pure-R Voronoi fallback is exercised.
  set.seed(42)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  seeds <- matrix(0L, 20, 20); seeds[5, 5] <- 1L; seeds[15, 15] <- 2L
  res <- sg_segment_propagate(img, nuclear_mask = new_sg_mask(seeds))
  expect_s3_class(res, "sg_mask")
  expect_equal(res$model_info$method, "propagate:voronoi_r")
})

test_that("sg_segment_propagate validates its arguments", {
  img <- new_sg_image(matrix(0, 5, 5))
  expect_error(sg_segment_propagate("x", new_sg_mask(matrix(0L, 5, 5))))
  expect_error(sg_segment_propagate(img, "y"))
  expect_error(sg_segment_propagate(img, new_sg_mask(matrix(0L, 5, 5)),
                                    lambda = -1))
})

test_that(".simple_watershed floods from seeds", {
  surface <- matrix(stats::runif(36), 6, 6)
  seeds <- matrix(0L, 6, 6)
  seeds[1, 1] <- 1L
  seeds[6, 6] <- 2L
  labels <- segmantR:::.simple_watershed(surface, seeds)
  expect_equal(dim(labels), c(6L, 6L))
  expect_gt(sum(labels > 0L), 2L)
})

test_that(".dilate_labels grows labelled regions", {
  labels <- matrix(0L, 6, 6)
  labels[3, 3] <- 1L
  out <- segmantR:::.dilate_labels(labels, 1L)
  expect_gt(sum(out > 0L), 1L)
})
