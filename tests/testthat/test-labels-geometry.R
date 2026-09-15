# Label utilities and pixel-exact geometry with independent oracles:
# hand-computed matrices and the historic queue-based component labeller.

test_that("components reproduce hand-computed 4- and 8-connected labels", {
  b <- matrix(c(1, 1, 0, 0,
                0, 1, 0, 1,
                0, 0, 1, 1,
                1, 0, 0, 0), nrow = 4, byrow = TRUE)
  expect_equal(segmantR:::.sg_components(b, 4L), matrix(c(
    1L, 1L, 0L, 0L,
    0L, 1L, 0L, 2L,
    0L, 0L, 2L, 2L,
    3L, 0L, 0L, 0L), nrow = 4, byrow = TRUE))
  expect_equal(segmantR:::.sg_components(b, 8L), matrix(c(
    1L, 1L, 0L, 0L,
    0L, 1L, 0L, 1L,
    0L, 0L, 1L, 1L,
    2L, 0L, 0L, 0L), nrow = 4, byrow = TRUE))
})

test_that("components agree with the historic labeller on random images", {
  withr::local_seed(11)
  for (i in 1:15) {
    nr <- sample(1:18, 1)
    nc <- sample(1:18, 1)
    b <- matrix(stats::runif(nr * nc) > 0.5, nr, nc)
    expect_identical(segmantR:::.sg_components(b, 4L),
                     segmantR:::.connected_components(
                       matrix(as.integer(b), nr, nc)))
  }
})

test_that("relabelling, area filter, border removal and touching rules", {
  l <- matrix(c(0L, 5L, 5L, 0L,
                9L, 9L, 0L, 0L,
                0L, 0L, 0L, 2L), nrow = 3, byrow = TRUE)
  expect_equal(segmantR:::.sg_relabel(l, "value")[1, 2], 2L)
  expect_equal(segmantR:::.sg_relabel(l, "raster")[1, 2], 1L)
  expect_equal(segmantR:::.sg_area_filter(l, min_area = 2)[3, 4], 0L)
  expect_true(all(segmantR:::.sg_remove_border(l) == 0L))
  touch <- matrix(c(1L, 2L, 2L), nrow = 1)
  expect_equal(segmantR:::.sg_separate_touching(touch), matrix(c(1L, 0L, 2L),
                                                               nrow = 1))
})

test_that("hole filling fills only holes enclosed by one label", {
  l <- matrix(0L, 7, 9)
  l[2:6, 2:6] <- 1L
  l[4, 4] <- 0L          # hole in label 1
  l[2:6, 7:8] <- 2L
  l[4, 7] <- 0L          # gap between 1 and 2 touches both labels
  out <- segmantR:::.sg_fill_label_holes(l)
  expect_equal(out[4, 4], 1L)
  expect_equal(out[4, 7], 0L)
})

test_that("disconnected parts are split or pruned", {
  l <- matrix(0L, 3, 7)
  l[1, 1:2] <- 3L
  l[3, 5:7] <- 3L
  s <- segmantR:::.sg_disconnected(l, 4L, "split")
  expect_setequal(unique(s[s > 0]), c(3L, 4L))
  k <- segmantR:::.sg_disconnected(l, 4L, "keep_largest")
  expect_equal(sum(k == 3L), 3L)
  chk <- segmantR:::.sg_check_labels(l, "instance")
  expect_false(chk$ok)
  expect_true(segmantR:::.sg_check_labels(l, "labelled")$ok)
})

test_that("traced polygons are exact: area, hole ring and rasterisation", {
  l <- matrix(0L, 8, 8)
  l[2:7, 2:7] <- 1L
  l[4:5, 4:5] <- 0L
  l[1, 8] <- 2L
  polys <- segmantR:::.sg_label_polygons(l)
  rings1 <- polys[["1"]][[1]]
  expect_length(rings1, 2L)
  expect_equal(segmantR:::.sg_ring_area(rings1[[1]]), 36)
  expect_equal(segmantR:::.sg_ring_area(rings1[[2]]), -4)
  expect_equal(unname(polys[["2"]][[1]][[1]][, "x"]), c(7, 8, 8, 7, 7))
  back <- matrix(0L, 8, 8)
  for (id in names(polys)) {
    back[segmantR:::.sg_rasterise_polygons(polys[[id]], c(8, 8))] <- as.integer(id)
  }
  expect_identical(back, l)
})

test_that("diagonally touching pixels become separate rings", {
  l <- matrix(0L, 3, 3)
  l[1, 1] <- 1L
  l[2, 2] <- 1L
  polys <- segmantR:::.sg_label_polygons(l)
  expect_length(polys[["1"]], 2L)
  expect_equal(segmantR:::.sg_geojson_geometry(polys[["1"]])$type,
               "MultiPolygon")
})

test_that("tracing and rasterisation round-trip random masks with origin", {
  withr::local_seed(5)
  o <- list(x = 100, y = 50, downsample = 2)
  for (i in 1:8) {
    nr <- sample(3:15, 1)
    nc <- sample(3:15, 1)
    l <- segmantR:::.sg_components(matrix(stats::runif(nr * nc) > 0.45, nr,
                                          nc), 8L)
    polys <- segmantR:::.sg_label_polygons(l, origin = o)
    back <- matrix(0L, nr, nc)
    for (id in names(polys)) {
      back[segmantR:::.sg_rasterise_polygons(polys[[id]], c(nr, nc), o)] <-
        as.integer(id)
    }
    expect_identical(back, l)
  }
})

test_that("measurements use image coordinates and calibration", {
  l <- matrix(0L, 4, 6)
  l[2:3, 3:5] <- 1L
  px <- matrix(1:24, 4, 6)
  m <- segmantR:::.sg_measure_labels(l, px, "A",
                                     origin = list(x = 10, y = 20, downsample = 1),
                                     pixel_size = list(x = 0.5, y = 0.25))
  expect_equal(m$area_px, 6)
  expect_equal(m$area_um2, 6 * 0.125)
  expect_equal(m$centroid_x_px, 10 + 3.5)
  expect_equal(m$centroid_y_px, 20 + 2)
  expect_equal(m$bbox_x_px, 12)
  expect_equal(m$mean_intensity_A, mean(px[2:3, 3:5]))
  long <- segmantR:::.sg_measurements_long(tibble::tibble(label = 1L,
                                                          v = c(NaN)))
  expect_equal(long$value_state, "nan")
  expect_true(is.nan(segmantR:::.sg_value_from_state(NA, "nan")))
})
