# Tests for the deep-learning backend wrappers. Python/reticulate is not
# available in CI, so we exercise input validation and the availability-check
# error paths (mocking the internal .check_* helpers where needed).

test_that("sg_segment_cellpose validates its image", {
  expect_error(sg_segment_cellpose("x"))
})

test_that("sg_segment_cellpose errors without cellpose available", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)),
                      channels = c("R", "G", "B"))
  local_mocked_bindings(
    .check_cellpose = function() cli::cli_abort("Cellpose not available")
  )
  expect_error(sg_segment_cellpose(img), "not available")
})

test_that("sg_segment_cellpose requires a custom model path for custom", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)))
  local_mocked_bindings(.check_cellpose = function() invisible(TRUE))
  # Import will fail (no reticulate python), but the custom-path check fires
  # before any import, so we expect the custom_model_path error specifically.
  expect_error(sg_segment_cellpose(img, model = "custom"),
               "custom_model_path")
})

test_that("sg_segment_stardist validates its image", {
  expect_error(sg_segment_stardist("x"))
})

test_that("sg_segment_stardist errors without stardist available", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  local_mocked_bindings(
    .check_stardist = function() cli::cli_abort("StarDist not available")
  )
  expect_error(sg_segment_stardist(img), "not available")
})

test_that("sg_segment_stardist requires a custom model path for custom", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  local_mocked_bindings(.check_stardist = function() invisible(TRUE))
  expect_error(sg_segment_stardist(img, model = "custom"),
               "custom_model_path")
})

test_that("sg_segment_mesmer validates its image", {
  expect_error(sg_segment_mesmer("x"))
})

test_that("sg_segment_mesmer errors without deepcell available", {
  img <- new_sg_image(array(stats::runif(200), dim = c(10, 10, 2)),
                      channels = c("nuclear", "membrane"))
  local_mocked_bindings(
    .check_mesmer = function() cli::cli_abort("DeepCell not available")
  )
  expect_error(sg_segment_mesmer(img), "not available")
})

test_that("sg_segment_mesmer requires at least two channels", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  local_mocked_bindings(.check_mesmer = function() invisible(TRUE))
  expect_error(sg_segment_mesmer(img), "at least 2 channels")
})

test_that("sg_setup_python errors without reticulate", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (pkg == "reticulate") FALSE else TRUE,
    .package = "base"
  )
  expect_error(sg_setup_python(), "reticulate")
})

test_that("sg_setup_python builds a virtualenv and installs backends", {
  skip_if_not_installed("reticulate")
  created <- list()
  installed <- NULL
  local_mocked_bindings(
    conda_binary = function(...) "",
    virtualenv_create = function(envname, ...) {
      created[["venv"]] <<- envname
      invisible(TRUE)
    },
    py_install = function(packages, envname, ...) {
      installed <<- packages
      invisible(TRUE)
    },
    .package = "reticulate"
  )
  res <- sg_setup_python(envname = "test_env", method = "virtualenv",
                         backends = c("cellpose", "stardist"), gpu = FALSE)
  expect_true(res)
  expect_equal(created[["venv"]], "test_env")
  expect_true("cellpose" %in% installed)
  expect_true(any(grepl("tensorflow", installed)))
})

test_that("sg_setup_python falls back to virtualenv on conda failure", {
  skip_if_not_installed("reticulate")
  used_venv <- FALSE
  local_mocked_bindings(
    conda_binary = function(...) "/usr/bin/conda",
    conda_create = function(envname, ...) stop("conda boom"),
    virtualenv_create = function(envname, ...) {
      used_venv <<- TRUE
      invisible(TRUE)
    },
    py_install = function(packages, envname, ...) invisible(TRUE),
    .package = "reticulate"
  )
  res <- sg_setup_python(method = "auto", backends = "cellpose", gpu = TRUE)
  expect_true(res)
  expect_true(used_venv)
})

test_that(".gpu_available returns FALSE when torch is unavailable", {
  expect_false(segmantR:::.gpu_available())
})
