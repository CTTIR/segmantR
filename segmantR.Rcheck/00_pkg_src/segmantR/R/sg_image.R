#' Create a new sg_image object
#'
#' Constructor for the `sg_image` S3 class, which represents a
#' multi-channel image with associated metadata.
#'
#' @param pixels Numeric array of dimensions H x W (grayscale) or H x W x C
#'   (multi-channel).
#' @param channels Character vector of channel names. If `NULL`, defaults to
#'   `ch1`, `ch2`, etc.
#' @param resolution Named list with `x_um` and `y_um` (microns per pixel).
#' @param metadata Named list of additional image metadata.
#'
#' @return An object of class `sg_image`.
#' @export
#' @examples
#' pixels <- matrix(runif(100), nrow = 10, ncol = 10)
#' img <- new_sg_image(pixels)
#' print(img)
new_sg_image <- function(pixels, channels = NULL, resolution = NULL,
                         metadata = list()) {
  stopifnot(is.numeric(pixels), length(dim(pixels)) %in% c(2L, 3L))
  n_ch <- if (length(dim(pixels)) == 3L) dim(pixels)[3] else 1L
  if (is.null(channels)) channels <- paste0("ch", seq_len(n_ch))
  structure(
    list(
      pixels = pixels,
      channels = channels,
      resolution = resolution %||% list(x_um = NA_real_, y_um = NA_real_),
      metadata = metadata,
      history = character(0)
    ),
    class = "sg_image"
  )
}

#' @export
print.sg_image <- function(x, ...) {
  dims <- dim(x$pixels)
  if (length(dims) == 2L) {
    cli::cli_text("{.cls sg_image}: {dims[1]} x {dims[2]} (1 channel)")
  } else {
    cli::cli_text("{.cls sg_image}: {dims[1]} x {dims[2]} x {dims[3]} ({length(x$channels)} channels: {paste(x$channels, collapse = ', ')})")

  }
  if (!is.na(x$resolution$x_um)) {
    cli::cli_text("Resolution: {x$resolution$x_um} x {x$resolution$y_um} um/px")
  }
  if (length(x$history) > 0L) {
    cli::cli_text("History: {paste(x$history, collapse = ' -> ')}")
  }
  invisible(x)
}

#' @export
dim.sg_image <- function(x) {
  dim(x$pixels)
}

#' @export
`[.sg_image` <- function(x, i, j, ..., drop = FALSE) {
  pixels <- x$pixels
  if (length(dim(pixels)) == 2L) {
    new_pixels <- pixels[i, j, drop = FALSE]
  } else {
    new_pixels <- pixels[i, j, , drop = FALSE]
  }
  new_sg_image(
    pixels = new_pixels,
    channels = x$channels,
    resolution = x$resolution,
    metadata = x$metadata
  )
}

#' Read an image file
#'
#' Reads TIFF, PNG, or JPEG image files and returns an `sg_image` object.
#' Dispatches to `EBImage::readImage()` when available, otherwise uses
#' `imager::load.image()`.
#'
#' @param path Character string, path to the image file.
#' @param ... Additional arguments passed to the underlying reader.
#'
#' @return An `sg_image` object.
#' @export
#' @examples
#' \donttest{
#' # img <- sg_read_image("path/to/image.tiff")
#' }
sg_read_image <- function(path, ...) {
  if (!file.exists(path)) {
    cli::cli_abort("Image file not found: {.path {path}}")
  }
  ext <- tolower(tools::file_ext(path))
  pixels <- NULL
  if (.check_ebimage()) {
    img <- EBImage::readImage(path)
    pixels <- EBImage::imageData(img)
    if (length(dim(pixels)) == 2L) {
      channels <- "ch1"
    } else {
      channels <- paste0("ch", seq_len(dim(pixels)[3]))
    }
  } else if (ext %in% c("tif", "tiff") &&
             requireNamespace("tiff", quietly = TRUE)) {
    img <- tiff::readTIFF(path, all = FALSE, ...)
    if (is.list(img)) img <- img[[1]]
    if (length(dim(img)) == 2L) {
      pixels <- img
      channels <- "ch1"
    } else {
      pixels <- img
      channels <- paste0("ch", seq_len(dim(img)[3]))
    }
  } else {
    img <- imager::load.image(path)
    arr <- as.array(img)
    if (length(dim(arr)) == 4L) {
      pixels <- arr[, , 1, , drop = TRUE]
    } else {
      pixels <- arr
    }
    if (length(dim(pixels)) == 2L) {
      channels <- "ch1"
    } else {
      channels <- paste0("ch", seq_len(dim(pixels)[3]))
    }
  }
  if (is.null(pixels)) {
    cli::cli_abort("Could not read image: {.path {path}}")
  }
  new_sg_image(pixels = pixels, channels = channels)
}
