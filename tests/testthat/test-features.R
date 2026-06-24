make_img_mask <- function() {
  pixels <- array(stats::runif(20 * 20 * 2), dim = c(20L, 20L, 2L))
  img <- new_sg_image(pixels, channels = c("DAPI", "CD3"))
  labels <- matrix(0L, 20L, 20L)
  labels[3:8, 3:8] <- 1L
  labels[12:18, 12:18] <- 2L
  list(img = img, mask = new_sg_mask(labels))
}

test_that("sg_extract_features returns one row per cell", {
  fm <- make_img_mask()
  feats <- sg_extract_features(fm$img, fm$mask,
                               features = c("intensity", "morphology"))
  expect_s3_class(feats, "tbl_df")
  expect_equal(nrow(feats), 2L)
  expect_true("cell_id" %in% names(feats))
})

test_that("sg_extract_features computes all four feature groups", {
  fm <- make_img_mask()
  feats <- sg_extract_features(fm$img, fm$mask)
  expect_true(all(c("DAPI_mean", "area", "DAPI_entropy",
                    "centroid_row") %in% names(feats)))
})

test_that("sg_extract_features works on a 2D image", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  labels <- matrix(0L, 20, 20)
  labels[3:8, 3:8] <- 1L
  feats <- sg_extract_features(img, new_sg_mask(labels),
                               features = "intensity")
  expect_equal(nrow(feats), 1L)
})

test_that("sg_extract_features selects channels by name", {
  fm <- make_img_mask()
  feats <- sg_extract_features(fm$img, fm$mask, features = "intensity",
                               channels = c("CD3"))
  expect_true(any(grepl("^CD3_", names(feats))))
  expect_false(any(grepl("^DAPI_", names(feats))))
})

test_that("sg_extract_features selects channels by index", {
  fm <- make_img_mask()
  feats <- sg_extract_features(fm$img, fm$mask, features = "intensity",
                               channels = 2L)
  expect_true(any(grepl("^CD3_", names(feats))))
})

test_that("sg_extract_features errors on an unknown channel name", {
  fm <- make_img_mask()
  expect_error(
    sg_extract_features(fm$img, fm$mask, channels = "nope"),
    "not found"
  )
})

test_that("sg_extract_features returns an empty tibble for empty masks", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  feats <- sg_extract_features(img, new_sg_mask(matrix(0L, 10, 10)))
  expect_equal(nrow(feats), 0L)
  expect_true("cell_id" %in% names(feats))
})

test_that("sg_extract_features rejects mismatched dims", {
  img <- new_sg_image(matrix(0, 10L, 10L))
  msk <- new_sg_mask(matrix(0L, 5L, 5L))
  expect_error(sg_extract_features(img, msk), "do not match")
})

test_that("sg_extract_features validates argument classes", {
  expect_error(sg_extract_features("x", new_sg_mask(matrix(0L, 4, 4))))
  expect_error(sg_extract_features(new_sg_image(matrix(0, 4, 4)), "y"))
})

test_that("sg_extract_features texture handles single-pixel cells", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  labels <- matrix(0L, 10, 10)
  labels[5, 5] <- 1L  # single-pixel cell
  feats <- sg_extract_features(img, new_sg_mask(labels), features = "texture")
  expect_equal(feats$ch1_entropy, 0)
  expect_equal(feats$ch1_iqr, 0)
})

test_that("sg_extract_features computes texture and location together", {
  fm <- make_img_mask()
  feats <- sg_extract_features(fm$img, fm$mask,
                               features = c("texture", "location"))
  expect_true(any(grepl("_entropy$", names(feats))))
  expect_true("centroid_row" %in% names(feats))
})

test_that("sg_extract_features morphology output is reproducible", {
  labels <- matrix(0L, 20, 20)
  labels[3:8, 3:8] <- 1L
  labels[12:18, 12:18] <- 2L
  img <- new_sg_image(matrix(0.5, 20, 20))
  feats <- sg_extract_features(img, new_sg_mask(labels),
                               features = "morphology")
  expect_snapshot_value(feats$area, style = "serialize")
})
