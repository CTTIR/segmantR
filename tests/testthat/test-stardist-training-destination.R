test_that("StarDist output validation does not overwrite existing artifacts", {
  root <- withr::local_tempdir()
  target <- file.path(root, "existing")
  dir.create(target)
  sentinel <- file.path(target, "weights_best.h5")
  writeBin(as.raw(1:10), sentinel)
  before <- tools::md5sum(sentinel)
  expect_error(segmantR:::.sg_stardist_training_destination(root, "existing"),
               "already exists")
  expect_identical(tools::md5sum(sentinel), before)
  for (name in c("", " ", ".", "..", "../escape", "x/y", "x\\y")) {
    expect_error(segmantR:::.sg_stardist_training_destination(root, name),
                 "directory name")
  }
  expect_error(segmantR:::.sg_stardist_training_destination(sentinel, "new"),
               "output directory")
  destination <- segmantR:::.sg_stardist_training_destination(
    file.path(root, "new-parent"), "new-model")
  expect_false(dir.exists(destination$save_path))
})

test_that("invalid StarDist data and controls create no output", {
  root <- withr::local_tempdir()
  output <- file.path(root, "uncreated")
  local_mocked_bindings(.sg_backend_status = function(...) stop("Python reached"))
  expect_error(sg_train_stardist(list(1), save_path = output),
               class = "sg_validation_error")
  expect_false(file.exists(output))
  for (value in list(0, -1, .5, NA_real_, Inf, matrix(1), 1 + 1i)) {
    expect_error(sg_train_stardist(list(), n_epochs = value,
                                  save_path = output), "whole numbers")
    expect_error(sg_train_stardist(list(), steps_per_epoch = value,
                                  save_path = output), "whole numbers")
  }
  for (value in list(0, -1, NA_real_, Inf, matrix(1), 1 + 1i)) {
    expect_error(sg_train_stardist(list(), learning_rate = value,
                                  save_path = output), "learning_rate")
  }
  expect_false(file.exists(output))
})
