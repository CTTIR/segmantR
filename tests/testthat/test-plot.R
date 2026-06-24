two_cell_mask <- function() {
  labels <- matrix(0L, 20, 20)
  labels[3:8, 3:8] <- 1L
  labels[12:18, 12:18] <- 2L
  new_sg_mask(labels)
}

test_that("sg_plot_overlay returns a ggplot for an image", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  p <- sg_plot_overlay(img)
  expect_s3_class(p, "ggplot")
})

test_that("sg_plot_overlay draws outlines, labels and a 3D channel", {
  img <- new_sg_image(array(stats::runif(800), dim = c(20, 20, 2)))
  mask <- two_cell_mask()
  p <- sg_plot_overlay(img, mask, channel = 2L, fill_alpha = 0.3,
                       label_cells = TRUE, highlight = 1L)
  expect_s3_class(p, "ggplot")
})

test_that("sg_plot_overlay validates its image", {
  expect_error(sg_plot_overlay("x"))
})

test_that("sg_plot_mask colours by id", {
  p <- sg_plot_mask(two_cell_mask())
  expect_s3_class(p, "ggplot")
})

test_that("sg_plot_mask colours by a feature column", {
  mask <- two_cell_mask()
  feats <- data.frame(cell_id = c(1L, 2L), area = c(36, 49))
  p <- sg_plot_mask(mask, color_by = "area", features = feats)
  expect_s3_class(p, "ggplot")
})

test_that("sg_plot_mask requires features for non-id colouring", {
  expect_error(sg_plot_mask(two_cell_mask(), color_by = "area"),
               "features")
})

test_that("sg_plot_mask errors when the feature column is missing", {
  feats <- data.frame(cell_id = c(1L, 2L))
  expect_error(
    sg_plot_mask(two_cell_mask(), color_by = "area", features = feats),
    "not found"
  )
})

test_that("sg_plot_features scatters two columns", {
  feat <- data.frame(cell_id = 1:10, area = (1:10) * 5,
                     mean_intensity = (1:10) / 10, grp = rep(c("a", "b"), 5))
  expect_s3_class(sg_plot_features(feat), "ggplot")
  expect_s3_class(sg_plot_features(feat, color = "grp"), "ggplot")
  expect_s3_class(sg_plot_features(feat, facet = "grp"), "ggplot")
})

test_that("sg_plot_features errors on missing columns", {
  feat <- data.frame(cell_id = 1:3, area = 1:3, mean_intensity = 1:3)
  expect_error(sg_plot_features(feat, x = "nope"), "not found")
  expect_error(sg_plot_features(feat, y = "nope"), "not found")
  expect_error(sg_plot_features(feat, color = "nope"), "not found")
  expect_error(sg_plot_features(feat, facet = "nope"), "not found")
})

test_that("sg_plot_comparison facets two masks", {
  m1 <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2, 2))
  m2 <- new_sg_mask(matrix(c(0L, 0L, 1L, 1L), 2, 2))
  p <- sg_plot_comparison(m1, m2)
  expect_s3_class(p, "ggplot")
})

test_that("sg_plot_comparison validates inputs", {
  m <- new_sg_mask(matrix(0L, 2, 2))
  expect_error(sg_plot_comparison("x", m))
  expect_error(sg_plot_comparison(m, m, labels = "only one"))
})

test_that("sg_plot_metrics draws a bar chart", {
  res <- data.frame(metric = c("IoU", "F1"), value = c(0.8, 0.9))
  expect_s3_class(sg_plot_metrics(res), "ggplot")
})

test_that("sg_plot_metrics validates columns", {
  expect_error(sg_plot_metrics(data.frame(a = 1)), "metric")
})

test_that(".mask_to_outline_df highlights selected cells", {
  labels <- matrix(0L, 6, 6)
  labels[2:4, 2:4] <- 1L
  df_all <- segmantR:::.mask_to_outline_df(labels)
  df_hl <- segmantR:::.mask_to_outline_df(labels, highlight = 9L)
  expect_gt(nrow(df_all), 0L)
  expect_equal(nrow(df_hl), 0L)
})

test_that(".mask_centroids returns one row per cell", {
  labels <- matrix(0L, 6, 6)
  labels[1:2, 1:2] <- 1L
  labels[5:6, 5:6] <- 2L
  cen <- segmantR:::.mask_centroids(labels)
  expect_equal(nrow(cen), 2L)
  expect_equal(nrow(segmantR:::.mask_centroids(labels, highlight = 1L)), 1L)
  expect_equal(nrow(segmantR:::.mask_centroids(matrix(0L, 4, 4))), 0L)
})
