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
#' @param gpu Logical; if `TRUE` (default), attempts to install
#'   GPU-enabled versions of the backends.
#'
#' @return Invisibly returns `TRUE` on success.
#' @export
#' @examples
#' \donttest{
#' sg_setup_python(backends = "cellpose")
#' }
sg_setup_python <- function(envname = "segmantr",
                            method = c("auto", "conda", "virtualenv"),
                            backends = c("cellpose", "stardist"),
                            gpu = TRUE) {

  if (!requireNamespace("reticulate", quietly = TRUE)) {
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
  if (method == "conda" ||
      (method == "auto" && reticulate::conda_binary() != "")) {
    tryCatch(
      reticulate::conda_create(envname = envname),
      error = function(e) {
        cli::cli_inform(c(
          "!" = "Conda environment creation failed; trying virtualenv.",
          "i" = "{conditionMessage(e)}"
        ))
        reticulate::virtualenv_create(envname = envname)
      }
    )
  } else {
    reticulate::virtualenv_create(envname = envname)
  }

  # Install packages
  packages <- character(0)
  if ("cellpose" %in% backends) {
    packages <- c(packages, if (gpu) "cellpose[gui]" else "cellpose")
  }
  if ("stardist" %in% backends) {
    packages <- c(packages, "stardist",
                  if (gpu) "tensorflow" else "tensorflow-cpu")
  }

  if (length(packages) > 0L) {
    cli::cli_inform(c(
      "i" = "Installing Python packages: {.val {packages}}."
    ))
    reticulate::py_install(packages, envname = envname)
  }

  cli::cli_inform(c(
    "v" = "Python environment {.val {envname}} is ready.",
    "i" = "Use {.code reticulate::use_virtualenv('{envname}')} to activate."
  ))

  invisible(TRUE)
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
#' \donttest{
#' pixels <- array(runif(300), dim = c(10, 10, 3))
#' img <- new_sg_image(pixels, channels = c("R", "G", "B"))
#' # Requires Python + cellpose:
#' # mask <- sg_segment_cellpose(img, model = "cyto3")
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

  # Run evaluation
  result <- tryCatch({
    cp_model$eval(
      np_image,
      diameter = diameter,
      channels = ch_list,
      flow_threshold = flow_threshold,
      cellprob_threshold = cellprob_threshold,
      batch_size = batch_size,
      do_3D = FALSE,
      tile = tile
    )
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
    cellprob_threshold = cellprob_threshold
  ))

  n_cells <- mask$n_cells
  cli::cli_inform(c(
    "v" = "Cellpose segmented {n_cells} cell{?s}."
  ))

  mask
}


# ---- Internal helpers ---------------------------------------------------

#' Check if GPU is available for Cellpose
#' @noRd
.gpu_available <- function() {
  tryCatch({
    torch <- reticulate::import("torch", convert = TRUE)
    torch$cuda$is_available()
  }, error = function(e) {
    FALSE
  })
}
