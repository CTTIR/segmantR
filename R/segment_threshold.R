#' Threshold-based cell segmentation
#'
#' Segments cells in an `sg_image` by applying a global or local
#' intensity threshold, followed by morphological cleanup and
#' connected-component labelling with size filtering.
#'
#' @param image An `sg_image` object.
#' @param channel Integer index of the image channel to threshold.
#'   Default is `1L`.
#' @param method Character string specifying the thresholding method.
#'   One of `"otsu"` (default), `"adaptive"`, or `"triangle"`.
#' @param block_size Integer block size for adaptive thresholding.
#'   Must be a positive odd integer. Only used when
#'   `method = "adaptive"`. Default is `51L`.
#' @param offset Numeric offset subtracted from the local mean in
#'   adaptive thresholding. Default is `0.05`.
#' @param morphology A named list controlling morphological cleanup:
#'   \describe{
#'     \item{`open`}{Integer; structuring element size for opening
#'       (erosion then dilation). Set to `0L` to skip. Default `5L`.}
#'     \item{`fill_holes`}{Logical; whether to fill holes inside
#'       objects. Default `TRUE`.}
#'   }
#' @param min_area Integer; minimum object area in pixels. Objects
#'   smaller than this are removed. Default is `50L`.
#' @param max_area Integer; maximum object area in pixels. Objects
#'   larger than this are removed. Default is `5000L`.
#'
#' @return An `sg_mask` object with labelled cell regions.
#' @export
#' @examples
#' set.seed(42)
#' pixels <- matrix(runif(400), nrow = 20, ncol = 20)
#' img <- new_sg_image(pixels)
#' mask <- sg_segment_threshold(img, method = "otsu")
#' print(mask)
sg_segment_threshold <- function(image,
                                 channel = 1L,
                                 method = c("otsu", "adaptive",
                                            "triangle"),
                                 block_size = 51L,
                                 offset = 0.05,
                                 morphology = list(open = 5L,
                                                   fill_holes = TRUE),
                                 min_area = 50L,
                                 max_area = 5000L) {

  stopifnot(inherits(image, "sg_image"))
  method <- match.arg(method)
  channel <- as.integer(channel)
  block_size <- as.integer(block_size)
  min_area <- as.integer(min_area)
  max_area <- as.integer(max_area)

  # Extract the requested channel
  ch <- .extract_channel(image, channel)

  # --- Apply threshold ----------------------------------------------------
  binary <- switch(
    method,
    otsu = {
      thresh <- .otsu_threshold(ch)
      ifelse(ch > thresh, 1L, 0L)
    },
    adaptive = {
      .adaptive_threshold(ch, block_size = block_size, offset = offset)
    },
    triangle = {
      thresh <- .triangle_threshold(ch)
      ifelse(ch > thresh, 1L, 0L)
    }
  )

  cli::cli_inform(c(
    "i" = "Threshold applied using {.val {method}} method."
  ))

  # --- Morphological cleanup ----------------------------------------------
  open_size <- morphology$open %||% 5L
  do_fill <- morphology$fill_holes %||% TRUE
  binary <- .morphological_cleanup(binary, open_size = open_size,
                                   fill_holes = do_fill)

  # --- Connected-component labelling --------------------------------------
  labels <- .connected_components(binary)

  # --- Size filtering -----------------------------------------------------
  labels <- .filter_by_area(labels, min_area = min_area,
                            max_area = max_area)

  n_cells <- max(labels, na.rm = TRUE)
  if (is.na(n_cells) || n_cells < 0L) n_cells <- 0L
  cli::cli_inform(c(
    "v" = "Segmented {n_cells} object{?s} via threshold ({method})."
  ))

  new_sg_mask(
    labels = labels,
    model_info = list(
      method = paste0("threshold:", method),
      channel = channel,
      min_area = min_area,
      max_area = max_area
    )
  )
}


# ---- Internal helpers ---------------------------------------------------

#' Extract a single channel from an sg_image
#' @noRd
.extract_channel <- function(image, channel) {
  pixels <- image$pixels
  if (length(dim(pixels)) == 2L) {
    if (channel != 1L) {
      cli::cli_abort(c(
        "Channel {channel} requested but image has only 1 channel.",
        "i" = "Use {.code channel = 1L} for grayscale images."
      ))
    }
    return(pixels)
  }
  n_ch <- dim(pixels)[3]
  if (channel < 1L || channel > n_ch) {
    cli::cli_abort(c(
      "Channel {channel} is out of range.",
      "i" = "Image has {n_ch} channel{?s} (1 to {n_ch})."
    ))
  }
  pixels[, , channel]
}

#' Remove objects outside size limits and relabel sequentially
#' @noRd
.filter_by_area <- function(labels, min_area, max_area) {
  cell_ids <- unique(as.vector(labels))
  cell_ids <- cell_ids[cell_ids > 0L]
  if (length(cell_ids) == 0L) return(labels)

  areas <- vapply(cell_ids, function(id) sum(labels == id), integer(1))
  keep <- cell_ids[areas >= min_area & areas <= max_area]

  # Remove filtered objects
  labels[!(labels %in% keep)] <- 0L

  # Relabel sequentially
  if (length(keep) > 0L) {
    new_id <- 0L
    for (old_id in sort(keep)) {
      new_id <- new_id + 1L
      labels[labels == old_id] <- new_id
    }
  }
  labels
}
