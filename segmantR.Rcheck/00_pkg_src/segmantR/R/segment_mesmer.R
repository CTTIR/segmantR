#' Mesmer (DeepCell) cell segmentation
#'
#' Segments cells using the Mesmer deep learning model from the
#' DeepCell library via `reticulate`. Mesmer is designed for
#' multiplexed tissue imaging and can segment both nuclear and
#' whole-cell compartments.
#'
#' Requires a working Python installation with `deepcell` installed.
#'
#' @param image An `sg_image` object. Must have at least two
#'   channels: a nuclear channel (first) and a membrane/cytoplasm
#'   channel (second).
#' @param compartment Character string specifying which compartment
#'   to segment. One of `"whole-cell"` (default), `"nuclear"`, or
#'   `"both"`.
#' @param image_mpp Numeric scalar or `NULL`. Microns per pixel of
#'   the input image. If `NULL`, the value is taken from the image
#'   resolution metadata; if that is also unavailable, `0.5` is
#'   used as a default.
#'
#' @return An `sg_mask` object (for `"whole-cell"` or `"nuclear"`)
#'   or a named list of two `sg_mask` objects (for `"both"`).
#' @export
#' @examples
#' \donttest{
#' pixels <- array(runif(200), dim = c(10, 10, 2))
#' img <- new_sg_image(pixels, channels = c("nuclear", "membrane"))
#' # Requires Python + deepcell:
#' # mask <- sg_segment_mesmer(img, compartment = "whole-cell")
#' }
sg_segment_mesmer <- function(image,
                              compartment = c("whole-cell", "nuclear",
                                              "both"),
                              image_mpp = NULL) {

  stopifnot(inherits(image, "sg_image"))
  compartment <- match.arg(compartment)

  .check_mesmer()

  pixels <- image$pixels

  # Validate input dimensions
  if (length(dim(pixels)) != 3L || dim(pixels)[3] < 2L) {
    cli::cli_abort(c(
      "Mesmer requires at least 2 channels (nuclear + membrane).",
      "i" = "Input image has {if (length(dim(pixels)) == 2L) '1' else dim(pixels)[3]} channel{?s}."
    ))
  }

  # Determine resolution
  if (is.null(image_mpp)) {
    image_mpp <- image$resolution$x_um
    if (is.na(image_mpp) || image_mpp <= 0) {
      image_mpp <- 0.5
      cli::cli_inform(c(
        "!" = "Image resolution not set; using default {.val {image_mpp}} um/px.",
        "i" = "Set {.arg image_mpp} or image resolution for accurate results."
      ))
    }
  }
  stopifnot(is.numeric(image_mpp), length(image_mpp) == 1L,
            image_mpp > 0)

  cli::cli_inform(c(
    "i" = "Running Mesmer segmentation ({.val {compartment}}) at {image_mpp} um/px."
  ))

  # Import deepcell
  deepcell <- reticulate::import("deepcell.applications")
  np <- reticulate::import("numpy", convert = FALSE)

  # Prepare 4D array: (batch, height, width, channels)
  nr <- dim(pixels)[1]
  nc <- dim(pixels)[2]
  nuclear <- pixels[, , 1]
  membrane <- pixels[, , 2]

  # Stack nuclear and membrane as (1, H, W, 2) numpy array
  combined <- array(0, dim = c(1L, nr, nc, 2L))
  combined[1, , , 1] <- nuclear
  combined[1, , , 2] <- membrane
  np_image <- np$array(combined, dtype = np$float32)

  # Create Mesmer application
  app <- tryCatch({
    deepcell$Mesmer()
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to initialise Mesmer model.",
      "x" = "{conditionMessage(e)}",
      "i" = "Ensure {.pkg deepcell} is correctly installed."
    ))
  })

  # Run prediction
  result <- tryCatch({
    app$predict(
      np_image,
      image_mpp = image_mpp,
      compartment = compartment
    )
  }, error = function(e) {
    cli::cli_abort(c(
      "Mesmer prediction failed.",
      "x" = "{conditionMessage(e)}",
      "i" = "Check input image dimensions and Python environment."
    ))
  })

  # Parse output
  if (compartment == "both") {
    result_r <- reticulate::py_to_r(result)
    # Mesmer returns a list of two arrays for "both"
    wc_labels <- as.integer(result_r[1, , , 1])
    dim(wc_labels) <- c(nr, nc)
    nuc_labels <- as.integer(result_r[1, , , 2])
    dim(nuc_labels) <- c(nr, nc)

    wc_mask <- new_sg_mask(
      labels = wc_labels,
      model_info = list(method = "mesmer:whole-cell",
                        image_mpp = image_mpp)
    )
    nuc_mask <- new_sg_mask(
      labels = nuc_labels,
      model_info = list(method = "mesmer:nuclear",
                        image_mpp = image_mpp)
    )

    cli::cli_inform(c(
      "v" = "Mesmer segmented {wc_mask$n_cells} whole cell{?s} and {nuc_mask$n_cells} nucle{?us/i}."
    ))

    return(list(`whole-cell` = wc_mask, nuclear = nuc_mask))
  }

  # Single compartment
  result_r <- reticulate::py_to_r(result)
  mask_mat <- as.integer(result_r[1, , , 1])
  dim(mask_mat) <- c(nr, nc)

  mask <- new_sg_mask(
    labels = mask_mat,
    model_info = list(
      method = paste0("mesmer:", compartment),
      image_mpp = image_mpp
    )
  )

  cli::cli_inform(c(
    "v" = "Mesmer segmented {mask$n_cells} object{?s} ({compartment})."
  ))

  mask
}
