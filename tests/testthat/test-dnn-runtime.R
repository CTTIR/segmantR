# Real optional DNN runtimes. Each lane runs only when its prerequisite is
# present and says which prerequisite is missing otherwise.
#
# Cellpose lane:  SEGMANTR_CELLPOSE_PYTHON=/path/to/venv/bin/python
#                 (Python with cellpose and the cyto3 weights available)
# StarDist lane:  SEGMANTR_STARDIST_PYTHON=/path/to/python (stardist + tensorflow)
# Mesmer lane:    SEGMANTR_DEEPCELL_PYTHON=/path/to/python (deepcell)

use_python_lane <- function(var, module) {
  py <- Sys.getenv(var)
  skip_if(!nzchar(py), paste0("prerequisite: set ", var,
                              " to a Python with the '", module, "' module"))
  skip_if_not_installed("reticulate")
  skip_if(reticulate::py_available(initialize = FALSE) &&
            !identical(normalizePath(reticulate::py_config()$python,
                                     mustWork = FALSE),
                       normalizePath(py, mustWork = FALSE)),
          "prerequisite: reticulate is already bound to another Python in this session")
  reticulate::use_python(py, required = TRUE)
  skip_if(!reticulate::py_module_available(module),
          paste0("prerequisite: Python module '", module, "' in ", var))
  invisible(py)
}

test_that("Cellpose protocol runs with a real Cellpose runtime", {
  use_python_lane("SEGMANTR_CELLPOSE_PYTHON", "cellpose")
  version <- reticulate::import("importlib.metadata")$version("cellpose")
  skip_if(!startsWith(version, "3."),
          paste("prerequisite: Cellpose 3.x (models.Cellpose API); found", version))
  img <- sg_example_image("fluorescence_nuclei")
  img$resolution <- list(x_um = 0.5, y_um = 0.5)
  # cyto3 weights must already be cached (~/.cellpose/models); no downloads.
  skip_if(!file.exists(file.path(path.expand("~"), ".cellpose", "models",
                                 "cyto3")),
          "prerequisite: cached Cellpose cyto3 weights in ~/.cellpose/models")
  run <- suppressMessages(sg_protocol_run(img, "cellpose.2d.v1",
                                          model = "cyto3", diameter = 10,
                                          cytoplasm_channel = 0L,
                                          nucleus_channel = 0L,
                                          output = "run"))
  expect_equal(run$record$status, "succeeded")
  expect_equal(sg_mask_status(run$mask)$status, "staged")
  expect_true(is.integer(run$mask$labels))
  expect_gt(run$mask$n_cells, 3L)
  truth <- sg_example_mask("fluorescence_nuclei")
  ev <- suppressMessages(sg_evaluate_segmentation(run$mask, truth,
                                                  metrics = "dice"))
  expect_gt(ev$value, 0.5)
})

test_that("StarDist protocol runs with a real StarDist runtime", {
  use_python_lane("SEGMANTR_STARDIST_PYTHON", "stardist")
  img <- sg_example_image("fluorescence_nuclei")
  run <- suppressMessages(sg_protocol_run(img, "stardist.2d.v1",
                                          output = "run"))
  expect_equal(run$record$status, "succeeded")
  expect_equal(sg_mask_status(run$mask)$status, "staged")
})

test_that("Mesmer protocol runs with a real DeepCell runtime", {
  use_python_lane("SEGMANTR_DEEPCELL_PYTHON", "deepcell")
  img <- sg_example_image("multiplex_4ch")
  img$resolution <- list(x_um = 0.5, y_um = 0.5)
  run <- suppressMessages(sg_protocol_run(img, "mesmer.2d.v1", output = "run"))
  expect_equal(run$record$status, "succeeded")
})
