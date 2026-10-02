test_that("physical area survives actual isotropic resampling and reopening", {
  image <- new_sg_image(matrix(1, 4L, 4L), channels = "DAPI",
                        resolution = list(x_um = 0.5, y_um = 0.5))
  smaller <- sg_preprocess(image, target_resolution = 1)
  expect_identical(dim(smaller$pixels), c(2L, 2L))
  expect_equal(smaller$origin$downsample, 2)
  for (img in list(image, smaller)) {
    mask <- new_sg_mask(matrix(7L, nrow(img$pixels), ncol(img$pixels)),
                        origin = img$origin)
    path <- file.path(withr::local_tempdir(), "bundle")
    sg_export_interchange(
      list(image = img, mask = mask), path,
      formats = c("manifest", "mask_tiff", "geojson",
                  "measurements", "image_tiff")
    )
    back <- sg_import_interchange(path)
    expect_true(back$ok)
    expect_identical(back$mask$labels, mask$labels)
    expect_equal(back$image$resolution, img$resolution)
    values <- back$measurements
    expect_equal(values$value[values$name == "area_px"], 16)
    expect_equal(values$value[values$name == "area_um2"], 4)
    expect_equal(values$value[values$name == "centroid_x_px"], 2)
    expect_equal(values$value[values$name == "centroid_y_px"], 2)
  }
})

test_that("anisotropic pixels retain physical area without resampling", {
  img <- new_sg_image(matrix(1, 3L, 4L),
                      resolution = list(x_um = 0.5, y_um = 0.25),
                      origin = list(x = 100, y = 200, downsample = 4))
  unchanged <- sg_preprocess(img)
  expect_identical(unchanged$pixels, img$pixels)
  expect_identical(unchanged$resolution, img$resolution)
  expect_identical(unchanged$origin, img$origin)
  labels <- matrix(0L, 3L, 4L)
  labels[2L, 3L] <- 7L
  result <- segmantR:::.sg_measure_labels(
    labels, origin = img$origin, pixel_size = list(x = 0.5, y = 0.25)
  )
  expect_equal(result$area_px, 16)
  expect_equal(result$area_um2, 0.125)
  expect_equal(result$centroid_x_px, 110)
  expect_equal(result$centroid_y_px, 206)
})

test_that("invalid targets and anisotropic resampling fail before dispatch", {
  calls <- 0L
  local_mocked_bindings(.resample_bilinear = function(...) {
    calls <<- calls + 1L
    cli::cli_abort("resampler must not be reached")
  })
  square <- new_sg_image(matrix(1, 4L, 4L),
                         resolution = list(x_um = 0.5, y_um = 0.5))
  for (target in list(Inf, -Inf, NA_real_, NaN, 0, -1, c(1, 2), "1")) {
    expect_error(
      sg_preprocess(square, target_resolution = target),
      "finite positive numeric scalar", class = "sg_validation_error"
    )
  }
  anisotropic <- new_sg_image(matrix(1, 4L, 4L),
                              resolution = list(x_um = 0.5, y_um = 0.25))
  expect_error(sg_preprocess(anisotropic, target_resolution = 1),
               "anisotropic", class = "sg_validation_error")
  expect_identical(calls, 0L)
})

test_that("resampling never invents missing or invalid pixel calibration", {
  calls <- 0L
  local_mocked_bindings(.resample_bilinear = function(pixels, ...) {
    calls <<- calls + 1L
    pixels
  })
  for (sizes in list(
    list(x_um = 0.5, y_um = NA_real_), list(x_um = 0.5),
    list(x_um = NA_real_, y_um = 0.5), list(x_um = Inf, y_um = 1),
    list(x_um = -1, y_um = -1)
  )) {
    image <- new_sg_image(matrix(1, 4L, 4L), resolution = sizes)
    result <- tryCatch(sg_preprocess(image, target_resolution = 1),
                       error = identity)
    expect_s3_class(result, "sg_calibration_error")
  }
  expect_identical(calls, 0L)
  unknown <- new_sg_image(matrix(1, 4L, 4L))
  expect_message(result <- sg_preprocess(unknown, target_resolution = 1),
                 "resolution is not set")
  expect_identical(result$pixels, unknown$pixels)
  expect_identical(result$resolution, unknown$resolution)
  expect_identical(calls, 0L)
})

test_that("a dimensioned target is not a numeric scalar", {
  calls <- 0L
  local_mocked_bindings(.resample_bilinear = function(pixels, ...) {
    calls <<- calls + 1L
    pixels
  })
  image <- new_sg_image(matrix(1, 4L, 4L),
                        resolution = list(x_um = 0.5, y_um = 0.5))
  result <- tryCatch(sg_preprocess(image, target_resolution = matrix(1, 1, 1)),
                     error = identity)
  expect_s3_class(result, "sg_validation_error")
  expect_identical(calls, 0L)
})
