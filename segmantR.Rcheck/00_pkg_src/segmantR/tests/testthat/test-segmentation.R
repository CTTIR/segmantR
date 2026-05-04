test_that("sg_segment_threshold returns an sg_mask", {
  img <- sg_example_image("fluorescence_nuclei")
  msk <- sg_segment_threshold(img, method = "otsu", min_area = 5L)
  expect_s3_class(msk, "sg_mask")
  expect_equal(dim(msk), dim(img)[1:2])
})

test_that("sg_segment_threshold validates channel index", {
  img <- sg_example_image("fluorescence_nuclei")
  expect_error(sg_segment_threshold(img, channel = 5L), "out of range|only 1 channel")
})

test_that("sg_evaluate_segmentation produces dice/jaccard for identical masks", {
  m <- sg_example_mask("he_breast")
  res <- sg_evaluate_segmentation(m, m, metrics = c("dice", "jaccard"))
  expect_equal(res$value[res$metric == "dice"], 1)
  expect_equal(res$value[res$metric == "jaccard"], 1)
})

test_that("sg_evaluate_segmentation rejects mismatched dimensions", {
  a <- new_sg_mask(matrix(0L, 4L, 4L))
  b <- new_sg_mask(matrix(0L, 5L, 5L))
  expect_error(sg_evaluate_segmentation(a, b), "same dimensions")
})
