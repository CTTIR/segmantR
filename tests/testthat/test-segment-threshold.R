test_that("sg_segment_threshold returns an sg_mask (otsu)", {
  img <- sg_example_image("fluorescence_nuclei")
  msk <- sg_segment_threshold(img, method = "otsu", min_area = 5L)
  expect_s3_class(msk, "sg_mask")
  expect_equal(dim(msk), dim(img)[1:2])
  expect_equal(msk$model_info$method, "threshold:otsu")
})

test_that("sg_segment_threshold supports the triangle method", {
  img <- sg_example_image("fluorescence_nuclei")
  msk <- sg_segment_threshold(img, method = "triangle", min_area = 5L)
  expect_s3_class(msk, "sg_mask")
  expect_equal(msk$model_info$method, "threshold:triangle")
})

test_that("sg_segment_threshold supports the adaptive method", {
  set.seed(11)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  msk <- sg_segment_threshold(img, method = "adaptive", block_size = 7L,
                              min_area = 1L,
                              morphology = list(open = 0L, fill_holes = FALSE))
  expect_s3_class(msk, "sg_mask")
  expect_equal(dim(msk), c(20L, 20L))
})

test_that("sg_segment_threshold honours custom morphology settings", {
  img <- sg_example_image("fluorescence_nuclei")
  msk <- sg_segment_threshold(img, method = "otsu", min_area = 5L,
                              morphology = list(open = 0L, fill_holes = FALSE))
  expect_s3_class(msk, "sg_mask")
})

test_that("sg_segment_threshold validates the channel index", {
  img <- sg_example_image("fluorescence_nuclei")
  expect_error(sg_segment_threshold(img, channel = 5L),
               "out of range|only 1 channel")
})

test_that("sg_segment_threshold validates its image argument", {
  expect_error(sg_segment_threshold("x"))
})

test_that("sg_segment_threshold output is reproducible", {
  set.seed(123)
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  msk <- sg_segment_threshold(img, method = "otsu", min_area = 3L)
  expect_snapshot_value(msk$labels, style = "serialize")
})

test_that(".extract_channel selects channels and validates range", {
  img2 <- new_sg_image(matrix(stats::runif(100), 10, 10))
  expect_equal(dim(segmantR:::.extract_channel(img2, 1L)), c(10L, 10L))
  expect_error(segmantR:::.extract_channel(img2, 2L), "only 1 channel")
  img3 <- new_sg_image(array(stats::runif(75), dim = c(5, 5, 3)))
  expect_equal(dim(segmantR:::.extract_channel(img3, 2L)), c(5L, 5L))
  expect_error(segmantR:::.extract_channel(img3, 9L), "out of range")
})

test_that(".filter_by_area drops objects and relabels", {
  labels <- matrix(0L, 10, 10)
  labels[1:2, 1:2] <- 1L    # area 4
  labels[5:9, 5:9] <- 2L    # area 25
  filtered <- segmantR:::.filter_by_area(labels, min_area = 10L,
                                         max_area = 1000L)
  expect_equal(max(filtered), 1L)
  expect_true(all(filtered[1:2, 1:2] == 0L))
})

test_that(".filter_by_area passes empty label matrices through", {
  labels <- matrix(0L, 4, 4)
  expect_equal(segmantR:::.filter_by_area(labels, 1L, 100L), labels)
})
