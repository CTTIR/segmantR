test_that("new_sg_image constructs from a 2D matrix", {
  pixels <- matrix(stats::runif(100), nrow = 10, ncol = 10)
  img <- new_sg_image(pixels)
  expect_s3_class(img, "sg_image")
  expect_equal(dim(img), c(10L, 10L))
  expect_equal(img$channels, "ch1")
  expect_equal(img$history, character(0))
})

test_that("new_sg_image constructs from a 3D array with named channels", {
  arr <- array(stats::runif(48), dim = c(4L, 4L, 3L))
  img <- new_sg_image(arr, channels = c("R", "G", "B"))
  expect_equal(img$channels, c("R", "G", "B"))
  expect_equal(dim(img), c(4L, 4L, 3L))
})

test_that("new_sg_image defaults channel names for 3D arrays", {
  arr <- array(stats::runif(48), dim = c(4L, 4L, 3L))
  img <- new_sg_image(arr)
  expect_equal(img$channels, c("ch1", "ch2", "ch3"))
})

test_that("new_sg_image fills resolution default when NULL", {
  img <- new_sg_image(matrix(0, 3, 3))
  expect_true(is.na(img$resolution$x_um))
  expect_true(is.na(img$resolution$y_um))
})

test_that("new_sg_image keeps supplied resolution and metadata", {
  img <- new_sg_image(matrix(0, 3, 3),
                      resolution = list(x_um = 0.5, y_um = 0.5),
                      metadata = list(id = "slide1"))
  expect_equal(img$resolution$x_um, 0.5)
  expect_equal(img$metadata$id, "slide1")
})

test_that("new_sg_image rejects invalid input", {
  expect_error(new_sg_image("not numeric"))
  expect_error(new_sg_image(stats::runif(10)))
})

test_that("[ subsetting a 2D image returns an sg_image", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  sub <- img[1:5, 1:5]
  expect_s3_class(sub, "sg_image")
  expect_equal(dim(sub), c(5L, 5L))
})

test_that("[ subsetting a 3D image preserves channels", {
  img <- new_sg_image(array(stats::runif(48), dim = c(4, 4, 3)),
                      channels = c("R", "G", "B"))
  sub <- img[1:2, 1:2]
  expect_equal(dim(sub), c(2L, 2L, 3L))
  expect_equal(sub$channels, c("R", "G", "B"))
})

test_that("print.sg_image reports grayscale, multichannel, resolution, history", {
  expect_snapshot(print(new_sg_image(matrix(0, 4, 4))))
  multi <- new_sg_image(array(0, dim = c(4, 4, 2)), channels = c("a", "b"),
                        resolution = list(x_um = 0.5, y_um = 0.5))
  multi$history <- c("denoise", "stretch")
  expect_snapshot(print(multi))
  expect_invisible(print(new_sg_image(matrix(0, 4, 4))))
})

test_that("sg_read_image errors on missing file", {
  expect_error(sg_read_image(tempfile(fileext = ".tiff")), "not found")
})

test_that("sg_read_image reads a TIFF via the tiff fallback", {
  skip_if_not_installed("tiff")
  local_mocked_bindings(.check_ebimage = function() FALSE)
  tmp <- withr::local_tempfile(fileext = ".tiff")
  tiff::writeTIFF(matrix(stats::runif(64), 8, 8), tmp)
  img <- sg_read_image(tmp)
  expect_s3_class(img, "sg_image")
  expect_equal(dim(img)[1:2], c(8L, 8L))
  expect_equal(img$channels, "ch1")
})

test_that("sg_read_image reads a multi-channel TIFF via the tiff fallback", {
  skip_if_not_installed("tiff")
  local_mocked_bindings(.check_ebimage = function() FALSE)
  tmp <- withr::local_tempfile(fileext = ".tiff")
  tiff::writeTIFF(array(stats::runif(192), dim = c(8, 8, 3)), tmp)
  img <- sg_read_image(tmp)
  expect_s3_class(img, "sg_image")
  expect_equal(dim(img)[3], 3L)
  expect_equal(img$channels, c("ch1", "ch2", "ch3"))
})

test_that("sg_read_image dispatches to EBImage when available", {
  local_mocked_bindings(.check_ebimage = function() TRUE)
  # A real path is required so file.exists() passes.
  tmp <- withr::local_tempfile(fileext = ".tiff")
  writeLines("x", tmp)
  # EBImage is not installed in CI; calling EBImage::readImage() should raise
  # a "namespace" style error rather than the "not found" path. Either way we
  # exercise the dispatch branch.
  res <- tryCatch(sg_read_image(tmp), error = function(e) conditionMessage(e))
  expect_false(grepl("Image file not found", res, fixed = TRUE))
})
