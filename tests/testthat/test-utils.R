# Tests for internal utility functions in R/utils.R

test_that("%||% returns left unless NULL", {
  expect_equal(segmantR:::`%||%`(1, 2), 1)
  expect_equal(segmantR:::`%||%`(NULL, 2), 2)
})

test_that(".otsu_threshold splits a bimodal distribution", {
  ch <- matrix(c(rep(0.1, 50), rep(0.9, 50)), 10, 10)
  thr <- segmantR:::.otsu_threshold(ch)
  expect_gt(thr, 0.1)
  expect_lt(thr, 0.9)
})

test_that(".otsu_threshold returns median on a constant image", {
  ch <- matrix(0.5, 5, 5)
  expect_equal(segmantR:::.otsu_threshold(ch), 0.5)
})

test_that(".triangle_threshold returns a finite value", {
  set.seed(1)
  ch <- matrix(stats::rbeta(400, 2, 5), 20, 20)
  thr <- segmantR:::.triangle_threshold(ch)
  expect_true(is.finite(thr))
})

test_that(".triangle_threshold returns median on a constant image", {
  expect_equal(segmantR:::.triangle_threshold(matrix(0.3, 4, 4)), 0.3)
})

test_that(".adaptive_threshold returns a 0/1 matrix of matching dimensions", {
  set.seed(2)
  ch <- matrix(stats::runif(100), 10, 10)
  res <- segmantR:::.adaptive_threshold(ch, block_size = 5L, offset = 0.05)
  expect_equal(dim(res), c(10L, 10L))
  expect_true(all(res %in% c(0L, 1L)))
})

test_that(".adaptive_threshold coerces even block sizes to odd", {
  ch <- matrix(stats::runif(64), 8, 8)
  res <- segmantR:::.adaptive_threshold(ch, block_size = 4L)
  expect_equal(dim(res), c(8L, 8L))
})

test_that(".cumsum2d produces a correct integral image", {
  m <- matrix(1, 3, 3)
  cum <- segmantR:::.cumsum2d(m)
  expect_equal(cum[3, 3], 9)
  expect_equal(cum[1, 1], 1)
  expect_equal(cum[2, 2], 4)
})

test_that(".connected_components labels separate blobs distinctly", {
  binary <- matrix(0L, 5, 5)
  binary[1, 1] <- 1L
  binary[5, 5] <- 1L
  labels <- segmantR:::.connected_components(binary)
  expect_equal(max(labels), 2L)
})

test_that(".distance_transform peaks inside an object", {
  binary <- matrix(0L, 7, 7)
  binary[2:6, 2:6] <- 1L
  dt <- segmantR:::.distance_transform(binary)
  expect_equal(dim(dt), c(7L, 7L))
  expect_gte(max(dt), 0)
})

test_that(".morpho_erode and .morpho_dilate change foreground extent", {
  binary <- matrix(0L, 7, 7)
  binary[2:6, 2:6] <- 1L
  eroded <- segmantR:::.morpho_erode(binary, size = 3L)
  dilated <- segmantR:::.morpho_dilate(eroded, size = 3L)
  expect_lte(sum(eroded), sum(binary))
  expect_gte(sum(dilated), sum(eroded))
})

test_that(".fill_holes closes an interior hole", {
  binary <- matrix(1L, 7, 7)
  binary[4, 4] <- 0L  # interior hole
  binary[1, ] <- 0L   # connect background to edge
  filled <- segmantR:::.fill_holes(binary)
  expect_equal(filled[4, 4], 1L)
})

test_that(".morphological_cleanup runs open + fill", {
  binary <- matrix(0L, 9, 9)
  binary[3:7, 3:7] <- 1L
  res <- segmantR:::.morphological_cleanup(binary, open_size = 3L,
                                           fill_holes = TRUE)
  expect_equal(dim(res), c(9L, 9L))
})

test_that(".voronoi_propagate_r expands seeds", {
  seeds <- matrix(0L, 6, 6)
  seeds[1, 1] <- 1L
  seeds[6, 6] <- 2L
  res <- segmantR:::.voronoi_propagate_r(seeds, expand_max = 10L)
  expect_gt(sum(res > 0L), 2L)
  expect_true(all(res %in% c(0L, 1L, 2L)))
})

test_that(".voronoi_propagate_r respects a mask", {
  seeds <- matrix(0L, 6, 6)
  seeds[1, 1] <- 1L
  mask <- matrix(0L, 6, 6)
  mask[1:3, 1:3] <- 1L
  res <- segmantR:::.voronoi_propagate_r(seeds, mask = mask, expand_max = 10L)
  expect_equal(res[6, 6], 0L)
})

test_that(".watershed_seeds returns labelled seeds", {
  set.seed(3)
  ch <- matrix(stats::runif(100), 10, 10)
  seeds <- segmantR:::.watershed_seeds(ch, method = "distance", h = 0.3)
  expect_equal(dim(seeds), c(10L, 10L))
})

test_that(".compute_morphology returns NA tibble for absent cells", {
  labels <- matrix(0L, 4, 4)
  m <- segmantR:::.compute_morphology(labels, cell_id = 99L)
  expect_equal(m$area, 0L)
  expect_true(is.na(m$circularity))
})

test_that(".compute_morphology computes area and centroid for a square", {
  labels <- matrix(0L, 6, 6)
  labels[2:4, 2:4] <- 1L
  m <- segmantR:::.compute_morphology(labels, cell_id = 1L)
  expect_equal(m$area, 9L)
  expect_equal(m$centroid_row, 3)
  expect_equal(m$centroid_col, 3)
  expect_gt(m$perimeter, 0)
})

test_that(".estimate_perimeter counts border pixels", {
  labels <- matrix(0L, 5, 5)
  labels[2:4, 2:4] <- 1L
  p <- segmantR:::.estimate_perimeter(labels, 1L)
  expect_equal(p, 8)  # all 9 minus the centre
})

test_that(".convex_hull_area handles small and large point sets", {
  expect_equal(segmantR:::.convex_hull_area(matrix(1:2, 1, 2)), 1)
  square <- as.matrix(expand.grid(1:4, 1:4))
  expect_gt(segmantR:::.convex_hull_area(square), 0)
})

test_that(".uncertainty_score is 0 for empty masks and in [0,1] otherwise", {
  empty <- new_sg_mask(matrix(0L, 5, 5))
  expect_equal(segmantR:::.uncertainty_score(empty, NULL), 0)
  labels <- matrix(0L, 6, 6)
  labels[2:4, 2:4] <- 1L
  m <- new_sg_mask(labels)
  s <- segmantR:::.uncertainty_score(m, NULL)
  expect_gte(s, 0)
  expect_lte(s, 1)
})

test_that(".patch_sampler grid and random strategies return patches", {
  img <- new_sg_image(matrix(stats::runif(64 * 64), 64, 64))
  grid_patches <- segmantR:::.patch_sampler(img, n = 4L, size = 16L,
                                            strategy = "grid")
  expect_true(length(grid_patches) > 0L)
  expect_true(all(c("row_start", "col_end") %in% names(grid_patches[[1]])))
  set.seed(5)
  rnd_patches <- segmantR:::.patch_sampler(img, n = 4L, size = 16L,
                                           strategy = "random")
  expect_true(length(rnd_patches) > 0L)
})

test_that(".corrections_to_mask_ops validates and passes through", {
  expect_error(segmantR:::.corrections_to_mask_ops(1), "must be a list")
  ops <- list(list(action = "delete"))
  expect_identical(segmantR:::.corrections_to_mask_ops(ops), ops)
})

test_that(".mask_to_training_pair bundles inputs", {
  img <- new_sg_image(matrix(0, 4, 4))
  msk <- new_sg_mask(matrix(0L, 4, 4))
  tp <- segmantR:::.mask_to_training_pair(img, msk, patch_size = 64L)
  expect_equal(tp$patch_size, 64L)
  expect_s3_class(tp$image, "sg_image")
})

test_that(".check_cellpose errors without reticulate or module", {
  local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(segmantR:::.check_cellpose(), "reticulate")
})

test_that(".check_stardist errors without reticulate", {
  local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(segmantR:::.check_stardist(), "reticulate")
})

test_that(".check_mesmer errors without reticulate", {
  local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(segmantR:::.check_mesmer(), "reticulate")
})

test_that(".check_ebimage returns FALSE when EBImage is absent", {
  skip_if(requireNamespace("EBImage", quietly = TRUE),
          "EBImage is installed")
  expect_false(segmantR:::.check_ebimage())
})

test_that(".check_cellpose errors when the module is unavailable", {
  skip_if_not_installed("reticulate")
  local_mocked_bindings(
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(segmantR:::.check_cellpose(), "module not found")
})

test_that(".check_stardist errors when the module is unavailable", {
  skip_if_not_installed("reticulate")
  local_mocked_bindings(
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(segmantR:::.check_stardist(), "module not found")
})

test_that(".check_mesmer errors when the module is unavailable", {
  skip_if_not_installed("reticulate")
  local_mocked_bindings(
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(segmantR:::.check_mesmer(), "module not found")
})

test_that(".watershed_seeds supports the markers method", {
  set.seed(3)
  ch <- matrix(stats::runif(100), 10, 10)
  seeds <- segmantR:::.watershed_seeds(ch, method = "markers", h = 0.3)
  expect_equal(dim(seeds), c(10L, 10L))
})

test_that(".patch_sampler random strategy oversamples when n exceeds grid", {
  img <- new_sg_image(array(stats::runif(64 * 64 * 2), dim = c(64, 64, 2)))
  set.seed(8)
  patches <- segmantR:::.patch_sampler(img, n = 100L, size = 32L,
                                       strategy = "random")
  expect_true(length(patches) > 0L)
})
