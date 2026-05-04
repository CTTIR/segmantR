test_that("sg_extract_features returns one row per cell", {
  pixels <- array(stats::runif(20 * 20 * 2), dim = c(20L, 20L, 2L))
  img <- new_sg_image(pixels, channels = c("DAPI", "CD3"))
  labels <- matrix(0L, 20L, 20L)
  labels[3:8, 3:8] <- 1L
  labels[12:18, 12:18] <- 2L
  feats <- sg_extract_features(img, new_sg_mask(labels),
                               features = c("intensity", "morphology"))
  expect_s3_class(feats, "tbl_df")
  expect_equal(nrow(feats), 2L)
  expect_true("cell_id" %in% names(feats))
})

test_that("sg_extract_features rejects mismatched dims", {
  img <- new_sg_image(matrix(0, 10L, 10L))
  msk <- new_sg_mask(matrix(0L, 5L, 5L))
  expect_error(sg_extract_features(img, msk), "do not match")
})
