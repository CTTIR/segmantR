test_that("custom StarDist inference loads saved weights without modifying the model", {
  model_path <- Sys.getenv("SEGMANTR_TEST_STARDIST_MODEL", "")
  skip_if(!nzchar(model_path), "requires an explicitly supplied saved StarDist model")
  skip_if_not_installed("reticulate")
  skip_if_not(segmantR:::.sg_python_selected(), "requires a selected Python")
  skip_if_not(reticulate::py_module_available("stardist"), "requires StarDist")
  assets <- list.files(model_path, pattern = "\\.(json|h5)$", full.names = TRUE)
  expect_true(length(assets) >= 2L)
  before <- tools::md5sum(assets)
  y <- row(matrix(0, 64, 96))
  x <- col(matrix(0, 64, 96))
  pixels <- exp(-((x - 23)^2 + (y - 18)^2) / 50) +
    .85 * exp(-((x - 72)^2 + (y - 46)^2) / 70)
  image <- new_sg_image(pixels)
  expected_input <- (pixels - min(pixels)) / diff(range(pixels))
  np <- reticulate::import("numpy", convert = FALSE)
  models <- reticulate::import("stardist.models", convert = FALSE)
  direct <- models$StarDist2D(config = NULL, name = basename(model_path),
                              basedir = dirname(model_path))
  expected <- direct$predict_instances(
    np$array(expected_input, dtype = np$float32),
    prob_thresh = .5, nms_thresh = .4
  )
  expected <- reticulate::py_to_r(expected[[0L]])
  for (iteration in seq_len(2L)) {
    actual <- sg_segment_stardist(image, model = "custom",
                                  custom_model_path = model_path)
    expect_identical(dim(actual$labels), c(64L, 96L))
    expect_identical(actual$labels, expected)
    expect_identical(tools::md5sum(assets), before)
  }
  missing <- file.path(tempdir(), "missing-stardist-model")
  expect_false(file.exists(missing))
  expect_error(sg_segment_stardist(image, model = "custom",
                                   custom_model_path = missing))
  expect_false(file.exists(missing))
})
