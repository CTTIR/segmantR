test_that("new_sg_image constructs from a 2D matrix", {
  pixels <- matrix(stats::runif(100), nrow = 10, ncol = 10)
  img <- new_sg_image(pixels)
  expect_s3_class(img, "sg_image")
  expect_equal(dim(img), c(10L, 10L))
  expect_equal(img$channels, "ch1")
})

test_that("new_sg_image constructs from a 3D array with named channels", {
  arr <- array(stats::runif(48), dim = c(4L, 4L, 3L))
  img <- new_sg_image(arr, channels = c("R", "G", "B"))
  expect_equal(img$channels, c("R", "G", "B"))
  expect_equal(dim(img), c(4L, 4L, 3L))
})

test_that("new_sg_image rejects invalid input", {
  expect_error(new_sg_image("not numeric"))
  expect_error(new_sg_image(stats::runif(10)))
})

test_that("[ subsetting returns an sg_image", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  sub <- img[1:5, 1:5]
  expect_s3_class(sub, "sg_image")
  expect_equal(dim(sub), c(5L, 5L))
})

test_that("sg_read_image errors on missing file", {
  expect_error(sg_read_image(tempfile(fileext = ".tiff")), "not found")
})
