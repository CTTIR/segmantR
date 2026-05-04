#' StarDist cell segmentation
#'
#' Segments cells (typically nuclei) using the StarDist deep learning
#' model via `reticulate`. Requires a working Python installation
#' with `stardist` and `tensorflow` installed. Use
#' [sg_setup_python()] to configure the environment.
#'
#' @param image An `sg_image` object.
#' @param model Character string specifying the StarDist model.
#'   One of `"2D_versatile_fluo"` (default),
#'   `"2D_versatile_he"`, `"2D_paper_dsb2018"`, or `"custom"`.
#' @param channel Integer index of the image channel to segment.
#'   Default is `1L`.
#' @param prob_thresh Numeric; object probability threshold.
#'   Objects with probability below this value are discarded.
#'   Default is `0.5`.
#' @param nms_thresh Numeric; non-maximum suppression overlap
#'   threshold. Overlapping detections above this threshold are
#'   merged. Default is `0.4`.
#' @param scale Numeric vector of length 1 or 2, or `NULL`.
#'   Scaling factor applied to the image before prediction.
#'   If `NULL`, no scaling is applied.
#' @param custom_model_path Character string or `NULL`. Path to a
#'   custom-trained StarDist model directory. Required when
#'   `model = "custom"`.
#' @param n_tiles Integer vector of length 2 or `NULL`. Number of
#'   tiles in each dimension for processing large images.
#'   If `NULL`, StarDist determines tiling automatically.
#'
#' @return An `sg_mask` object with labelled cell regions.
#' @export
#' @examples
#' \donttest{
#' pixels <- matrix(runif(400), nrow = 20, ncol = 20)
#' img <- new_sg_image(pixels)
#' # Requires Python + stardist:
#' # mask <- sg_segment_stardist(img, model = "2D_versatile_fluo")
#' }
sg_segment_stardist <- function(image,
                                model = c("2D_versatile_fluo",
                                          "2D_versatile_he",
                                          "2D_paper_dsb2018",
                                          "custom"),
                                channel = 1L,
                                prob_thresh = 0.5,
                                nms_thresh = 0.4,
                                scale = NULL,
                                custom_model_path = NULL,
                                n_tiles = NULL) {

  stopifnot(inherits(image, "sg_image"))
  model <- match.arg(model)
  channel <- as.integer(channel)
  stopifnot(is.numeric(prob_thresh), length(prob_thresh) == 1L)
  stopifnot(is.numeric(nms_thresh), length(nms_thresh) == 1L)

  .check_stardist()

  if (model == "custom" && is.null(custom_model_path)) {
    cli::cli_abort(c(
      "{.arg custom_model_path} is required when {.code model = 'custom'}.",
      "i" = "Provide the path to a trained StarDist model directory."
    ))
  }

  cli::cli_inform(c(
    "i" = "Running StarDist segmentation with model {.val {model}}."
  ))

  # Import stardist
  stardist_mod <- reticulate::import("stardist.models")

  # Load model
  sd_model <- if (model == "custom") {
    stardist_mod$StarDist2D(
      name = basename(custom_model_path),
      basedir = dirname(custom_model_path)
    )
  } else {
    stardist_mod$StarDist2D$from_pretrained(model)
  }

  # Extract single channel
  ch <- .extract_channel(image, channel)

  # Normalise to [0, 1]
  rng <- range(ch, na.rm = TRUE)
  if (rng[2] - rng[1] > 0) {
    ch <- (ch - rng[1]) / (rng[2] - rng[1])
  }

  # Convert to numpy
  np <- reticulate::import("numpy", convert = FALSE)
  np_image <- np$array(ch, dtype = np$float32)

  # Predict
  predict_args <- list(
    np_image,
    prob_thresh = prob_thresh,
    nms_thresh = nms_thresh
  )
  if (!is.null(scale)) {
    predict_args$scale <- scale
  }
  if (!is.null(n_tiles)) {
    predict_args$n_tiles <- as.integer(n_tiles)
  }

  result <- tryCatch({
    do.call(sd_model$predict_instances, predict_args)
  }, error = function(e) {
    cli::cli_abort(c(
      "StarDist prediction failed.",
      "x" = "{conditionMessage(e)}",
      "i" = "Check that your Python environment is correctly configured."
    ))
  })

  # StarDist returns (labels, details)
  labels <- result[[1]]
  details <- if (length(result) > 1L) result[[2]] else NULL

  mask <- .stardist_to_sg(labels, details = details, model_info = list(
    method = paste0("stardist:", model),
    prob_thresh = prob_thresh,
    nms_thresh = nms_thresh
  ))

  n_cells <- mask$n_cells
  cli::cli_inform(c(
    "v" = "StarDist segmented {n_cells} cell{?s}."
  ))

  mask
}
