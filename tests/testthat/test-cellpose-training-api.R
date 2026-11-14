test_that("training and inference share the default channel selectors", {
  defaults <- formals(sg_train_cellpose)$channels
  expect_identical(defaults, formals(sg_segment_cellpose)$channels)
  expect_identical(segmantR:::.sg_cellpose_channels(eval(defaults), 3L), c(0L, 1L))
  expect_identical(segmantR:::.sg_cellpose_channels(list(), 1L), c(0L, 0L))
  for (value in list(-1, .5, NA_real_, Inf, matrix(1), 1 + 1i, 4)) {
    expect_error(segmantR:::.sg_cellpose_channels(list(cytoplasm = value), 3L),
                 "channel selectors")
  }
  for (value in list(1, list(1), list(other = 1),
                     structure(list(1, 2), names = c("nucleus", "nucleus")))) {
    expect_error(segmantR:::.sg_cellpose_channels(value), "named list")
  }
})

test_that("unsupported aliases fail before Python or fallback model loading", {
  local_mocked_bindings(.check_cellpose = function() stop("Python reached"))
  image <- new_sg_image(matrix(0, 8, 12))
  for (alias in c("tissuenet", "livecell")) {
    expect_error(sg_segment_cellpose(image, model = alias), "legacy")
    expect_error(sg_train_cellpose(list(), base_model = alias), "legacy")
  }
  expect_error(sg_segment_cellpose(image, model = "custom",
                                   custom_model_path = tempfile()), "weights file")
  expect_error(sg_segment_cellpose(image, model = "custom",
                                   custom_model_path = tempdir()), "weights file")
})

test_that("training rejects undefined optimization controls", {
  local_mocked_bindings(.check_cellpose = function() invisible(TRUE))
  for (epochs in list(0, -1, 1.5, NA_real_, Inf, .Machine$integer.max + 1,
                     matrix(1), 1 + 1i)) {
    expect_error(sg_train_cellpose(list(), n_epochs = epochs), "n_epochs")
  }
  for (rate in list(0, -1, NA_real_, Inf, matrix(1), 1 + 1i)) {
    expect_error(sg_train_cellpose(list(), learning_rate = rate), "learning_rate")
  }
})
