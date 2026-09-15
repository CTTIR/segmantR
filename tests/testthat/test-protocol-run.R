# Declarative runs against exact, independently constructed expectations and
# against the direct functions.

two_squares <- function() {
  px <- matrix(0.1, 20, 24)
  px[3:8, 3:8] <- 0.9      # A: 36 px
  px[12:18, 14:21] <- 0.8  # B: 56 px
  px[16:17, 3:4] <- 0.9    # C: 4 px
  new_sg_image(px, channels = "nuc", id = "squares",
               resolution = list(x_um = 0.5, y_um = 0.5))
}

expected_squares <- function(with_a = TRUE) {
  l <- matrix(0L, 20, 24)
  if (with_a) {
    l[3:8, 3:8] <- 1L
    l[12:18, 14:21] <- 2L
  } else {
    l[12:18, 14:21] <- 1L
  }
  l
}

test_that("threshold.otsu.v1 reproduces exact labels and areas", {
  img <- two_squares()
  m <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1",
                                        min_area = 10L))
  expect_identical(m$labels, expected_squares(TRUE))
  expect_equal(m$mask_type, "instance")
  expect_equal(m$image_id, "squares")
  expect_equal(sg_mask_status(m)$status, "draft")
  d <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1"))
  expect_identical(d$labels, expected_squares(FALSE))
  run <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1",
                                          min_area = 10L, output = "run"))
  expect_equal(run$measurements$area_px, c(36, 56))
  expect_equal(run$measurements$area_um2, c(36, 56) * 0.25)
  expect_equal(run$measurements$centroid_x_px, c(5, 17))
  expect_equal(run$measurements$mean_intensity_nuc, c(0.9, 0.8))
})

test_that("core protocols equal the direct function calls", {
  img <- two_squares()
  cases <- list(
    list(id = "threshold.otsu.v1", args = list(min_area = 10L),
         direct = function() sg_segment_threshold(img, method = "otsu",
                                                  min_area = 10L)),
    list(id = "threshold.adaptive.v1",
         args = list(block_size = 7L, min_area = 1L, open_size = 0L),
         direct = function() sg_segment_threshold(
           img, method = "adaptive", block_size = 7L, min_area = 1L,
           morphology = list(open = 0L, fill_holes = TRUE))),
    list(id = "threshold.triangle.v1", args = list(min_area = 5L),
         direct = function() sg_segment_threshold(img, method = "triangle",
                                                  min_area = 5L)),
    list(id = "watershed.distance.v1", args = list(h = 0.3),
         direct = function() sg_segment_watershed(img, seed_method = "distance",
                                                  h = 0.3)),
    list(id = "watershed.h_minima.v1", args = list(),
         direct = function() sg_segment_watershed(img, seed_method = "h_minima"))
  )
  for (cs in cases) {
    run <- suppressMessages(do.call(sg_protocol_run, c(
      list(image = img, protocol = cs$id), cs$args, list(output = "run"))))
    direct <- suppressMessages(cs$direct())
    expect_identical(run$mask$labels, direct$labels, info = cs$id)
    expect_length(segmantR:::.sg_schema_errors(run$record, "run.schema.json",
                                               normalise = FALSE), 0L)
    expect_equal(run$record$delegate$`function`,
                 sg_protocol_get(cs$id)$method$delegate)
    expect_equal(run$record$outputs$mask$revision, sg_mask_revision(run$mask))
    chk <- segmantR:::.sg_check_labels(run$mask$labels, "labelled")
    expect_true(chk$ok, info = cs$id)
    expect_true(is.integer(run$mask$labels))
  }
})

test_that("recorded delegate arguments reproduce the run directly", {
  img <- two_squares()
  run <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1",
                                          min_area = 12L, output = "run"))
  a <- run$record$delegate$arguments
  direct <- suppressMessages(sg_segment_threshold(
    img, channel = a$channel, method = a$method, min_area = a$min_area,
    max_area = a$max_area,
    morphology = list(open = a$morphology$open,
                      fill_holes = a$morphology$fill_holes)))
  expect_identical(direct$labels, run$mask$labels)
  expect_identical(run$record$parameters_digest,
                   segmantR:::.sg_digest_json(run$record$parameters))
})

test_that("propagate.voronoi.v1 grows seeds to exact diamonds", {
  img <- new_sg_image(matrix(0, 10, 20))
  seeds <- matrix(0L, 10, 20)
  seeds[5, 5] <- 1L
  seeds[5, 15] <- 2L
  run <- suppressMessages(sg_protocol_run(img, "propagate.voronoi.v1",
                                          seeds = new_sg_mask(seeds),
                                          expand_max = 3L, output = "run"))
  expected <- matrix(0L, 10, 20)
  rr <- row(expected)
  cc <- col(expected)
  expected[abs(rr - 5) + abs(cc - 5) <= 3] <- 1L
  expected[abs(rr - 5) + abs(cc - 15) <= 3] <- 2L
  expect_identical(run$mask$labels, expected)
  expect_equal(run$measurements$area_px, c(25, 25))
  direct <- suppressMessages(sg_segment_propagate(
    img, new_sg_mask(seeds), expand_max = 3L, engine = "voronoi_r"))
  expect_identical(direct$labels, expected)
})

test_that("propagate protocol never switches silently to EBImage", {
  local_mocked_bindings(
    .check_ebimage = function() TRUE,
    .ebimage_propagate = function(...) stop("must not be called")
  )
  img <- new_sg_image(matrix(0, 6, 6))
  seeds <- matrix(0L, 6, 6)
  seeds[3, 3] <- 1L
  m <- suppressMessages(sg_protocol_run(img, "propagate.voronoi.v1",
                                        seeds = new_sg_mask(seeds)))
  expect_equal(m$model_info$method, "propagate:voronoi_r")
})

test_that("label cleanup applies each rule in the declared order", {
  l <- matrix(0L, 7, 10)
  l[2:3, 2:3] <- 5L
  l[2:4, 6:8] <- 9L
  l[3, 7] <- 0L
  l[6, 1:2] <- 3L
  l[6, 5:6] <- 3L
  m <- sg_mask_legend(new_sg_mask(l, image_id = "c"), materialise = TRUE)
  ids <- sg_mask_legend(m)$object_id
  out <- suppressMessages(sg_protocol_run(
    m, "postprocess.label-cleanup.v1", fill_holes = TRUE,
    disconnected = "split", border = "remove", min_area = 3L))
  expected <- matrix(0L, 7, 10)
  expected[2:3, 2:3] <- 1L
  expected[2:4, 6:8] <- 2L
  expect_identical(out$labels, expected)
  leg <- sg_mask_legend(out)
  expect_equal(leg$object_id, ids[c(2, 3)])
  touch <- matrix(c(1L, 1L, 2L, 2L), nrow = 1)
  sep <- sg_cleanup_labels(new_sg_mask(touch), touching = "separate",
                           relabel = "none")
  expect_equal(sep$labels, matrix(c(1L, 1L, 0L, 2L), nrow = 1))
  um <- sg_cleanup_labels(new_sg_mask(l), min_area_um2 = 2,
                          pixel_size = list(x = 1, y = 0.5))
  expect_equal(unname(segmantR:::.sg_label_areas(um$labels)), c(4L, 4L, 8L))
})

test_that("band selection by name or wavelength equals the index run", {
  arr <- array(0.1, c(20, 24, 3))
  arr[3:8, 3:8, 2] <- 0.9
  arr[12:18, 14:21, 2] <- 0.8
  img <- new_sg_image(arr, channels = c("b1", "b2", "b3"),
                      bands = data.frame(wavelength_nm = c(450, 550, 650)),
                      value_semantics = "reflectance")
  by_index <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1",
                                               channel = 2L, min_area = 10L))
  by_name <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1",
                                              channel_name = "b2",
                                              min_area = 10L, output = "run"))
  by_wl <- suppressMessages(sg_protocol_run(img, "threshold.otsu.v1",
                                            wavelength_nm = 553,
                                            min_area = 10L))
  expect_identical(by_index$labels, expected_squares(TRUE))
  expect_identical(by_name$mask$labels, by_index$labels)
  expect_identical(by_wl$labels, by_index$labels)
  expect_equal(by_name$record$delegate$arguments$image,
               "<derived:sg_select_channel>")
})

test_that("seed policy fixed restores the caller RNG state", {
  def <- unclass(sg_protocol_get("threshold.otsu.v1"))
  def$seed_policy <- list(policy = "fixed", seed = 42L, note = "test")
  withr::local_seed(99)
  expected_next <- {
    withr::with_seed(99, stats::runif(1))
  }
  run <- suppressMessages(sg_protocol_run(two_squares(), def, min_area = 10L,
                                          output = "run"))
  expect_equal(stats::runif(1), expected_next)
  expect_equal(run$record$seed$value, 42L)
  expect_match(run$record$seed$rng_kind, "Mersenne")
})

test_that("missing optional backends yield unavailable runs, never fallbacks", {
  img <- two_squares()
  local_mocked_bindings(
    .check_stardist = function() stop("stardist missing"),
    .check_cellpose = function() stop("cellpose missing"),
    .check_mesmer = function() stop("deepcell missing")
  )
  err <- expect_error(sg_protocol_run(img, "stardist.2d.v1"),
                      class = "sg_capability_error")
  expect_equal(err$code, "CAPABILITY_UNAVAILABLE")
  run <- sg_protocol_run(img, "stardist.2d.v1", output = "run")
  expect_equal(run$record$status, "unavailable")
  expect_null(run$mask)
  expect_match(run$record$error$message, "stardist")
  expect_length(segmantR:::.sg_schema_errors(run$record, "run.schema.json",
                                             normalise = FALSE), 0L)
  expect_equal(sg_protocol_run(img, "cellpose.2d.v1", output = "run")$record$status,
               "unavailable")
  two <- new_sg_image(array(stats::runif(2 * 400), c(20, 20, 2)),
                      resolution = list(x_um = 0.5, y_um = 0.5))
  expect_equal(sg_protocol_run(two, "mesmer.2d.v1", output = "run")$record$status,
               "unavailable")
})

test_that("stardist protocol maps normalisation, scale and tiles explicitly", {
  captured <- NULL
  local_mocked_bindings(
    .check_stardist = function() invisible(TRUE),
    .sg_stardist_predict = function(ch, ...) {
      captured <<- list(ch = ch, args = list(...))
      l <- matrix(0L, nrow(ch), ncol(ch))
      l[2:4, 2:4] <- 1L
      new_sg_mask(l, model_info = list(method = "stardist:mock"))
    }
  )
  px <- matrix(seq_len(130 * 70), 130, 70) + 0
  img <- new_sg_image(px, resolution = list(x_um = 0.25, y_um = 0.25))
  run <- sg_protocol_run(img, "stardist.2d.v1", normalize_low = 1,
                         normalize_high = 99, pixel_size_um = 0.5,
                         tile_size = 64L, output = "run")
  q <- stats::quantile(px, c(0.01, 0.99), names = FALSE)
  expect_equal(captured$ch, (px - q[1]) / (q[2] - q[1]))
  expect_equal(captured$args$scale, 0.5)
  expect_equal(captured$args$n_tiles, c(3L, 2L))
  expect_equal(sg_mask_status(run$mask)$status, "staged")
  expect_equal(run$record$outputs$mask$status, "staged")
  expect_error(sg_protocol_run(img, "stardist.2d.v1", cell_expansion_um = 2),
               class = "sg_capability_error")
  expect_error(sg_protocol_run(img, "stardist.2d.v1", normalize_scope = "tile"),
               class = "sg_capability_error")
  uncal <- new_sg_image(px)
  expect_error(sg_protocol_run(uncal, "stardist.2d.v1", pixel_size_um = 0.5),
               class = "sg_calibration_error")
})

test_that("cellpose protocol converts diameter_um with the calibration", {
  captured <- NULL
  local_mocked_bindings(
    .check_cellpose = function() invisible(TRUE),
    sg_segment_cellpose = function(image, ...) {
      captured <<- list(...)
      new_sg_mask(matrix(0L, nrow(image$pixels), ncol(image$pixels)))
    }
  )
  img <- new_sg_image(array(stats::runif(2 * 400), c(20, 20, 2)),
                      resolution = list(x_um = 0.5, y_um = 0.5))
  run <- sg_protocol_run(img, "cellpose.2d.v1", diameter_um = 10,
                         nucleus_channel = 2L, output = "run")
  expect_equal(captured$diameter, 20)
  expect_equal(captured$channels, list(cytoplasm = 0L, nucleus = 2L))
  expect_equal(run$record$status, "succeeded")
})
