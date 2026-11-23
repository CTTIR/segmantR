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

# ---- regression tests -------------------------------------------------------

layer_classes <- function(p) {
  unname(vapply(p$layers, function(l) class(l$geom)[1], character(1)))
}

test_that(".mask_outline_segments traces the pixel edges of each cell", {
  labels <- matrix(0L, 5, 6)
  labels[2:3, 2:4] <- 1L
  seg <- segmantR:::.mask_outline_segments(labels)
  # a 2 x 3 rectangle has a perimeter of 10 unit edges
  expect_equal(nrow(seg), 10L)
  expect_equal(range(c(seg$x, seg$xend)), c(1.5, 4.5))
  expect_equal(range(c(seg$y, seg$yend)), c(1.5, 3.5))
  # every segment is one pixel edge long
  expect_true(all(abs(seg$xend - seg$x) + abs(seg$yend - seg$y) == 1))

  # touching cells: the joint 2 x 4 outline (12 edges) plus one separating
  # edge per touching pixel pair (2), each drawn once
  labels[2:3, 5] <- 2L
  seg2 <- segmantR:::.mask_outline_segments(labels)
  expect_equal(nrow(seg2), 12L + 2L)
  expect_false(any(duplicated(seg2)))

  # cells on the image border are closed along the border
  full <- matrix(1L, 2, 2)
  expect_equal(nrow(segmantR:::.mask_outline_segments(full)), 8L)
  expect_equal(nrow(segmantR:::.mask_outline_segments(matrix(0L, 3, 3))), 0L)
})

test_that(".mask_to_outline_df marks border and neighbour pixels only", {
  labels <- matrix(0L, 7, 7)
  labels[2:6, 2:6] <- 1L
  df <- segmantR:::.mask_to_outline_df(labels)
  expect_equal(nrow(df), 16L)
  expect_false(any(df$row == 4 & df$col == 4))
  edge <- matrix(1L, 3, 3)
  expect_equal(nrow(segmantR:::.mask_to_outline_df(edge)), 8L)
})

test_that(".mask_centroids are exact and sorted by cell id", {
  labels <- matrix(0L, 6, 6)
  labels[5:6, 5:6] <- 7L
  labels[1:2, 1:3] <- 3L
  cen <- segmantR:::.mask_centroids(labels)
  expect_equal(cen$cell_id, c(3L, 7L))
  expect_equal(cen$row, c(1.5, 5.5))
  expect_equal(cen$col, c(2, 5.5))
})

test_that("sg_plot_overlay draws outlines as segments and fills cell regions", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  mask <- two_cell_mask()
  p <- sg_plot_overlay(img, mask)
  expect_equal(layer_classes(p), c("GeomRaster", "GeomSegment"))

  p_fill <- sg_plot_overlay(img, mask, fill_alpha = 0.4, label_cells = TRUE)
  expect_equal(layer_classes(p_fill),
               c("GeomRaster", "GeomTile", "GeomSegment", "GeomText"))
  # the fill covers every pixel of both cells, not only their boundary
  expect_equal(nrow(p_fill$layers[[2]]$data), 6L * 6L + 7L * 7L)
  expect_equal(p_fill$layers[[4]]$data$cell_id, 1:2)

  p_hl <- sg_plot_overlay(img, mask, fill_alpha = 0.4, highlight = 2L)
  expect_equal(nrow(p_hl$layers[[2]]$data), 7L * 7L)
  expect_no_error(ggplot2::ggplot_build(p_fill))
})

test_that("sg_plot_overlay handles empty masks and unknown highlights", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  empty <- new_sg_mask(matrix(0L, 20, 20))
  expect_equal(layer_classes(sg_plot_overlay(img, empty, fill_alpha = 0.5,
                                             label_cells = TRUE)),
               "GeomRaster")
  expect_equal(layer_classes(sg_plot_overlay(img, two_cell_mask(),
                                             highlight = 99L)),
               "GeomRaster")
})

test_that("sg_plot_overlay validates channel, mask size and fill_alpha", {
  img2 <- new_sg_image(matrix(stats::runif(400), 20, 20))
  img3 <- new_sg_image(array(stats::runif(1200), dim = c(20, 20, 3)))
  expect_error(sg_plot_overlay(img2, channel = 2L), "only 1 channel")
  expect_error(sg_plot_overlay(img3, channel = 5L), "out of range")
  expect_error(sg_plot_overlay(img3, channel = NA), "single channel number")
  expect_error(sg_plot_overlay(img2, new_sg_mask(matrix(1L, 5, 5))),
               "same height and width")
  expect_error(sg_plot_overlay(img2, "mask"), "sg_mask")
  expect_error(sg_plot_overlay(img2, two_cell_mask(), fill_alpha = 2),
               "between 0 and 1")
})

test_that("sg_plot_mask colours by character, factor and logical columns", {
  mask <- two_cell_mask()
  feats <- data.frame(cell_id = 1:2, cluster = c("tumour", "stroma"))
  p <- sg_plot_mask(mask, color_by = "cluster", features = feats)
  expect_no_error(b <- ggplot2::ggplot_build(p))
  expect_s3_class(p$scales$get_scales("fill"), "ScaleDiscrete")
  expect_equal(levels(p$data$fill_value), c("stroma", "tumour"))
  # cell 1 is "tumour", cell 2 is "stroma", background stays NA
  expect_equal(as.character(p$data$fill_value[p$data$cell_id == 1L][1]),
               "tumour")
  expect_true(all(is.na(p$data$fill_value[p$data$cell_id == 0L])))

  feats$cluster <- factor(c("b", "a"), levels = c("b", "a", "unused"))
  p_f <- sg_plot_mask(mask, color_by = "cluster", features = feats)
  expect_no_error(ggplot2::ggplot_build(p_f))
  expect_equal(levels(p_f$data$fill_value), c("b", "a", "unused"))

  feats$cluster <- c(TRUE, FALSE)
  expect_no_error(ggplot2::ggplot_build(
    sg_plot_mask(mask, color_by = "cluster", features = feats)
  ))

  # numeric columns keep the continuous scale
  feats$cluster <- c(1.5, 2.5)
  p_n <- sg_plot_mask(mask, color_by = "cluster", features = feats)
  expect_s3_class(p_n$scales$get_scales("fill"), "ScaleContinuous")
})

test_that("sg_plot_mask matches features by cell id, not by row order", {
  mask <- two_cell_mask()
  feats <- data.frame(cell_id = c(2L, 1L, 9L), area = c(49, 36, 1))
  p <- sg_plot_mask(mask, color_by = "area", features = feats)
  expect_equal(unique(p$data$fill_value[p$data$cell_id == 1L]), 36)
  expect_equal(unique(p$data$fill_value[p$data$cell_id == 2L]), 49)
})

test_that("sg_plot_mask hides the per-cell legend for many cells only", {
  legend_position <- function(p) p$theme$legend.position
  expect_false(identical(legend_position(sg_plot_mask(two_cell_mask())),
                         "none"))
  many <- matrix(0L, 10, 10)
  many[seq(1, 99, by = 4)] <- seq_len(25)
  expect_equal(legend_position(sg_plot_mask(new_sg_mask(many))), "none")
  # the background is not a legend entry
  p <- sg_plot_mask(two_cell_mask())
  expect_equal(p$scales$get_scales("fill")$get_limits(), c("1", "2"))
  expect_no_warning(b <- ggplot2::ggplot_build(p))
  expect_equal(unique(b$data[[1]]$fill[is.na(p$data$fill_value)]), "grey20")
  expect_no_error(ggplot2::ggplot_build(sg_plot_mask(
    new_sg_mask(matrix(0L, 4, 4))
  )))
})

test_that("sg_plot_mask validates mask and features", {
  expect_error(sg_plot_mask("x"), "sg_mask")
  expect_error(
    sg_plot_mask(two_cell_mask(), "area", features = data.frame(area = 1)),
    "cell_id"
  )
})

test_that("sg_plot_features uses one layer and labels the colour legend", {
  feat <- data.frame(area = c(10, 20, 30), mean_intensity = c(0.2, 0.5, 0.8),
                     grp = c("a", "b", "a"), score = c(1, 2, 3))
  p <- sg_plot_features(feat, color = "grp")
  expect_length(p$layers, 1L)
  expect_equal(p$labels$colour, "grp")
  expect_no_error(ggplot2::ggplot_build(p))
  expect_no_error(ggplot2::ggplot_build(sg_plot_features(feat, color = "score")))
  expect_no_error(ggplot2::ggplot_build(
    sg_plot_features(feat[0, ], color = "grp")
  ))
  expect_error(sg_plot_features(list(area = 1)), "data frame")
})

test_that("sg_plot_comparison rejects identical panel titles", {
  m <- two_cell_mask()
  expect_error(sg_plot_comparison(m, m, labels = c("A", "A")),
               "two different panel titles")
  expect_error(sg_plot_comparison(m, m, labels = c("A", NA)),
               "two different panel titles")
  expect_no_error(ggplot2::ggplot_build(
    sg_plot_comparison(m, new_sg_mask(matrix(0L, 20, 20)))
  ))
})

test_that("sg_plot_metrics accepts sg_evaluate_segmentation() output", {
  m <- two_cell_mask()
  ev <- suppressMessages(sg_evaluate_segmentation(m, m))
  expect_no_error(ggplot2::ggplot_build(sg_plot_metrics(ev)))
  expect_error(sg_plot_metrics(list(metric = "a", value = 1)), "data frame")
})
