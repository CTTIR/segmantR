#' Set up a Python environment for deep learning backends
#'
#' Creates and configures a Python virtual environment or conda
#' environment with the requested deep learning segmentation backends
#' (Cellpose, StarDist) installed.
#'
#' @param envname Character string naming the Python environment.
#'   Default is `"segmantr"`.
#' @param method Character string specifying the environment type.
#'   One of `"auto"` (default), `"conda"`, or `"virtualenv"`.
#' @param backends Character vector of backends to install.
#'   Supported values are `"cellpose"` and `"stardist"`.
#' @param gpu Logical; if `TRUE` (default), installs the GPU-capable
#'   `tensorflow` build for StarDist instead of `tensorflow-cpu`. Cellpose
#'   is always installed as `cellpose`; it uses a GPU when the installed
#'   PyTorch build supports it.
#'
#' @section Selecting Python:
#' segmantR never starts, downloads or installs Python by itself; without a
#' configured Python, recent versions of 'reticulate' would provision one
#' with 'uv'. The deep learning backends count as available only when
#' Python is already running in the session (for example after
#' `reticulate::use_virtualenv("segmantr")` and `reticulate::py_config()`),
#' when the environment variable `RETICULATE_PYTHON` or
#' `RETICULATE_PYTHON_ENV` names a Python, or when the option
#' `segmantR.python` is `TRUE`, which lets 'reticulate' find (or provision)
#' a Python on first use.
#'
#' @return Invisibly returns `TRUE` on success.
#' @export
#' @examples
#' \dontrun{
#' sg_setup_python(backends = "cellpose")
#' }
sg_setup_python <- function(envname = "segmantr",
                            method = c("auto", "conda", "virtualenv"),
                            backends = c("cellpose", "stardist"),
                            gpu = TRUE) {

  if (!.sg_has_pkg("reticulate")) {
    cli::cli_abort(c(
      "{.pkg reticulate} is required to set up Python environments.",
      "i" = "Install with: {.code install.packages('reticulate')}"
    ))
  }

  method <- match.arg(method)
  backends <- match.arg(backends, several.ok = TRUE)
  stopifnot(is.logical(gpu), length(gpu) == 1L)
  stopifnot(is.character(envname), length(envname) == 1L)

  cli::cli_inform(c(
    "i" = "Setting up Python environment {.val {envname}}.",
    "i" = "Method: {.val {method}}, GPU: {.val {gpu}}."
  ))

  # Create environment
  env_type <- "virtualenv"
  if (method == "conda" ||
      (method == "auto" && .sg_conda_binary() != "")) {
    env_type <- tryCatch({
      .sg_conda_create(envname)
      "conda"
    }, error = function(e) {
      cli::cli_inform(c(
        "!" = "Conda environment creation failed; trying virtualenv.",
        "i" = "{conditionMessage(e)}"
      ))
      .sg_virtualenv_create(envname)
      "virtualenv"
    })
  } else {
    .sg_virtualenv_create(envname)
  }

  # Install packages. Cellpose reaches a GPU through its PyTorch build (the
  # "gui" extra is the desktop interface); `gpu` only switches StarDist
  # between tensorflow builds.
  packages <- character(0)
  if ("cellpose" %in% backends) {
    packages <- c(packages, "cellpose")
  }
  if ("stardist" %in% backends) {
    packages <- c(packages, "stardist",
                  if (gpu) "tensorflow" else "tensorflow-cpu")
  }

  if (length(packages) > 0L) {
    cli::cli_inform(c(
      "i" = "Installing Python packages: {.val {packages}}."
    ))
    .sg_py_install(packages, envname, env_type)
  }

  activate <- if (env_type == "conda") "use_condaenv" else "use_virtualenv"
  cli::cli_inform(c(
    "v" = "Python environment {.val {envname}} is ready.",
    "i" = paste("Use {.code reticulate::{activate}('{envname}')} and",
                "{.code reticulate::py_config()} to activate it.")
  ))

  invisible(TRUE)
}

# Thin wrappers around reticulate, so tests can replace them without
# mocking the reticulate namespace
.sg_conda_binary <- function() reticulate::conda_binary()

.sg_conda_create <- function(envname) {
  reticulate::conda_create(envname = envname)
}

.sg_virtualenv_create <- function(envname) {
  reticulate::virtualenv_create(envname = envname)
}

.sg_py_install <- function(packages, envname, method) {
  reticulate::py_install(packages, envname = envname, method = method)
}


#' Cellpose cell segmentation
#'
#' Segments cells using the Cellpose deep learning model via
#' `reticulate`. Requires a working Python installation with
#' `cellpose` installed. Use [sg_setup_python()] to configure the
#' environment.
#'
#' @param image An `sg_image` object.
#' @param model Character string specifying the Cellpose model.
#'   One of `"cyto3"` (default), `"cyto2"`, `"nuclei"`,
#'   `"tissuenet"`, `"livecell"`, or `"custom"`.
#' @param channels A named list with elements `cytoplasm` and
#'   `nucleus`, each an integer channel index (0-based, following
#'   Cellpose convention). Default is
#'   `list(cytoplasm = 0L, nucleus = 1L)`.
#' @param diameter Numeric or `NULL`. Estimated cell diameter in
#'   pixels. If `NULL`, Cellpose estimates the diameter
#'   automatically.
#' @param flow_threshold Numeric; flow error threshold for mask
#'   filtering. Default is `0.4`.
#' @param cellprob_threshold Numeric; cell probability threshold.
#'   Default is `0.0`.
#' @param custom_model_path Character string or `NULL`. Path to a
#'   custom-trained Cellpose model. Required when
#'   `model = "custom"`.
#' @param batch_size Integer; number of images to process in
#'   parallel on the GPU. Default is `8L`.
#' @param tile Logical; if `TRUE` (default), large images are
#'   processed in tiles to reduce memory usage.
#'
#' @return An `sg_mask` object with labelled cell regions.
#' @export
#' @examples
#' pixels <- array(runif(300), dim = c(10, 10, 3))
#' img <- new_sg_image(pixels, channels = c("R", "G", "B"))
#' \dontrun{
#' # Requires Python with Cellpose (see sg_setup_python())
#' mask <- sg_segment_cellpose(img, model = "cyto3")
#' }
sg_segment_cellpose <- function(image,
                                model = c("cyto3", "cyto2", "nuclei",
                                          "tissuenet", "livecell",
                                          "custom"),
                                channels = list(cytoplasm = 0L,
                                                nucleus = 1L),
                                diameter = NULL,
                                flow_threshold = 0.4,
                                cellprob_threshold = 0.0,
                                custom_model_path = NULL,
                                batch_size = 8L,
                                tile = TRUE) {

  stopifnot(inherits(image, "sg_image"))
  model <- match.arg(model)
  stopifnot(is.list(channels))
  stopifnot(is.numeric(flow_threshold), length(flow_threshold) == 1L)
  stopifnot(is.numeric(cellprob_threshold),
            length(cellprob_threshold) == 1L)
  batch_size <- as.integer(batch_size)
  stopifnot(is.logical(tile), length(tile) == 1L)

  .check_cellpose()

  if (model == "custom" && is.null(custom_model_path)) {
    cli::cli_abort(c(
      "{.arg custom_model_path} is required when {.code model = 'custom'}.",
      "i" = "Provide the path to a trained Cellpose model."
    ))
  }

  cli::cli_inform(c(
    "i" = "Running Cellpose segmentation with model {.val {model}}."
  ))

  # Import cellpose
  cellpose <- reticulate::import("cellpose")
  cp_models <- cellpose$models

  # Initialise model
  cp_model <- if (model == "custom") {
    cp_models$CellposeModel(
      pretrained_model = custom_model_path,
      gpu = .gpu_available()
    )
  } else {
    cp_models$Cellpose(
      model_type = model,
      gpu = .gpu_available()
    )
  }

  # Prepare image array
  np_image <- .r_array_to_cellpose(image)
  ch_list <- as.integer(c(channels$cytoplasm %||% 0L,
                          channels$nucleus %||% 0L))

  # Run evaluation. Cellpose >= 3 removed the `tile` argument (it always
  # tiles internally); pass it only when the installed eval() accepts it.
  eval_args <- list(
    np_image,
    diameter = diameter,
    channels = ch_list,
    flow_threshold = flow_threshold,
    cellprob_threshold = cellprob_threshold,
    batch_size = batch_size,
    do_3D = FALSE
  )
  accepts_tile <- .sg_py_accepts_arg(cp_model$eval, "tile")
  if (accepts_tile) eval_args$tile <- tile
  result <- tryCatch({
    do.call(cp_model$eval, eval_args)
  }, error = function(e) {
    cli::cli_abort(c(
      "Cellpose evaluation failed.",
      "x" = "{conditionMessage(e)}",
      "i" = "Check that your Python environment is correctly configured."
    ))
  })

  # Extract mask (first element of result tuple)
  np_mask <- result[[1]]
  if (inherits(np_mask, "python.builtin.list")) {
    np_mask <- np_mask[[0]]
  }

  mask <- .cellpose_mask_to_sg(np_mask, model_info = list(
    method = paste0("cellpose:", model),
    diameter = diameter,
    flow_threshold = flow_threshold,
    cellprob_threshold = cellprob_threshold,
    tile = if (accepts_tile) tile else
      "not an eval() argument in this Cellpose version (tiles internally)"
  ))

  n_cells <- mask$n_cells
  cli::cli_inform(c(
    "v" = "Cellpose segmented {n_cells} cell{?s}."
  ))

  mask
}


# ---- Internal helpers ---------------------------------------------------

#' Does a Python callable accept a keyword argument?
#' @noRd
.sg_py_accepts_arg <- function(fn, arg) {
  tryCatch({
    inspect <- reticulate::import("inspect", convert = FALSE)
    sig <- inspect$signature(fn)
    keys <- reticulate::py_to_r(reticulate::import_builtins()$list(
      sig$parameters$keys()))
    arg %in% unlist(keys)
  }, error = function(e) TRUE)
}

#' Check if GPU is available for Cellpose
#' @noRd
.gpu_available <- function() {
  if (!.sg_python_selected()) return(FALSE)
  tryCatch({
    torch <- reticulate::import("torch", convert = TRUE)
    torch$cuda$is_available()
  }, error = function(e) {
    FALSE
  })
}
