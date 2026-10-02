sparse_label_fixture <- function() {
  labels <- matrix(0L, 8L, 8L)
  labels[2:3, 2:3] <- 2L
  labels[5:6, 5:6] <- 7L
  new_sg_mask(labels)
}

test_that("sparse instance labels count and measure only present objects", {
  mask <- sparse_label_fixture()
  expect_identical(mask$n_cells, 2L)
  expect_identical(sort(unique(as.vector(mask$labels))), c(0L, 2L, 7L))
  image <- new_sg_image(matrix(1, 8L, 8L), channels = "DAPI")
  features <- suppressMessages(sg_extract_features(
    image, mask, features = c("intensity", "morphology", "location")
  ))
  expect_identical(features$cell_id, c(2L, 7L))
  expect_equal(features$area, c(4, 4))
  # Check the existing one-based row/column API fields.
  expect_equal(features$centroid_row, c(2.5, 5.5)) # nolint: cttir_domain_vocab
  expect_equal(features$centroid_col, c(2.5, 5.5)) # nolint: cttir_domain_vocab
  expect_equal(features$DAPI_mean, c(1, 1))
})

test_that("sparse-label permutation retains perfect instance metrics", {
  mask <- sparse_label_fixture()
  labels <- mask$labels
  labels[mask$labels == 2L] <- 19L
  labels[mask$labels == 7L] <- 3L
  result <- suppressMessages(sg_evaluate_segmentation(
    mask, new_sg_mask(labels)
  ))
  expect_equal(result$value, rep(1, nrow(result)))
})

test_that("sparse labels survive mask operations without omitted objects", {
  mask <- sparse_label_fixture()
  filtered <- suppressMessages(sg_filter_cells(
    mask, min_area = 1L, min_circularity = 0, max_eccentricity = 1
  ))
  expect_identical(filtered$n_cells, 2L)
  expect_identical(filtered$labels > 0L, mask$labels > 0L)
  merged <- suppressMessages(sg_merge_masks(mask, mask))
  expect_identical(merged$nuclear$labels, mask$labels)
  polygons <- suppressMessages(sg_mask_to_polygons(mask, simplify = FALSE))
  expect_identical(sort(unique(polygons$cell_id)), c(2L, 7L))
  csv <- withr::local_tempfile(fileext = ".csv")
  suppressMessages(sg_export_mask(mask, csv, format = "csv"))
  expect_identical(utils::read.csv(csv)$cell_id, c(2L, 7L))
})

test_that("mask construction refuses unrepresentable label values", {
  for (value in c(NA_real_, NaN, Inf, -1, 1.5, 2147483648, 4294967295)) {
    expect_error(
      new_sg_mask(matrix(c(0, value), 1L, 2L)),
      "finite whole numbers between 0 and 2147483647"
    )
  }
  edge <- new_sg_mask(matrix(c(0, 2147483647), 1L, 2L))
  expect_identical(edge$labels[1L, 2L], .Machine$integer.max)
  expect_identical(edge$n_cells, 1L)
})

test_that("border flags follow retained output labels after sparse filtering", {
  labels <- matrix(0L, 8L, 8L)
  labels[1L, 1:2] <- 2L
  labels[4:5, 4:5] <- 7L
  mask <- new_sg_mask(labels)
  keep <- suppressMessages(sg_filter_cells(
    mask, min_area = 1L, min_circularity = 0, max_eccentricity = 1,
    border_cells = "flag"
  ))
  expect_identical(keep$labels[1L, 1L], 1L)
  expect_identical(keep$labels[4L, 4L], 2L)
  expect_identical(keep$border_cell_ids, 1L)
  drop <- suppressMessages(sg_filter_cells(
    mask, min_area = 3L, min_circularity = 0, max_eccentricity = 1,
    border_cells = "flag"
  ))
  expect_identical(drop$labels[1L, 1L], 0L)
  expect_identical(drop$labels[4L, 4L], 1L)
  expect_identical(drop$border_cell_ids, integer(0))
})
