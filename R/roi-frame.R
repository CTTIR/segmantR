#' Declare the coordinate frame for histology ROIs
#'
#' A metadata-only frame; no image reader, spectral backend, or pixel data is
#' loaded. Coordinates have top-left origin, x right, y down. Pyramid dimensions
#' are supplied explicitly, permitting anisotropic and non-power-of-two levels.
#' Calibration is the physical size of a level-zero pixel along x and y.
#' @param dims Integer-valued width and height at level zero.
#' @param level_dims List of width/height vectors, starting with `dims`.
#' @param pixel_size Positive finite x/y pixel sizes at level zero.
#' @param pixel_unit Unit of the calibration, e.g. `"um"` or `"px"`.
#' @param source Image identifier or path, recorded without reading the file.
#' @return A `sg_roi_frame` for [sg_roi_project()] and [sg_roi_transform()].
#' @export
#' @examples
#' frame <- sg_roi_frame(c(100, 80), list(c(100, 80), c(30, 20)), c(0.5, 0.8), "um")
#' sg_roi_dims(frame, 1)
sg_roi_frame <- function(dims, level_dims = list(dims), pixel_size = c(1, 1),
                         pixel_unit = "px", source = "") {
  valid_dims <- function(x) {
    typeof(x) %in% c("integer", "double") && !is.object(x) &&
      is.null(dim(x)) && length(x) == 2L && !anyNA(x) &&
      all(is.finite(x) & x >= 1 & x <= .Machine$integer.max & x == floor(x))
  }
  if (!valid_dims(dims) || !is.list(level_dims) || !length(level_dims) ||
      !all(vapply(level_dims, valid_dims, logical(1))) ||
      !identical(as.integer(dims), as.integer(level_dims[[1L]]))) {
    cli::cli_abort("Dimensions must be positive whole width/height pairs with level zero matching dims.")
  }
  if (length(level_dims) > 1L && any(vapply(seq.int(2L, length(level_dims)),
      function(i) any(level_dims[[i]] > level_dims[[i - 1L]]), logical(1)))) {
    cli::cli_abort("Pyramid dimensions must not increase at coarser levels.")
  }
  if (!typeof(pixel_size) %in% c("integer", "double") || is.object(pixel_size) ||
      !is.null(dim(pixel_size)) || length(pixel_size) != 2L ||
      anyNA(pixel_size) || any(!is.finite(pixel_size) | pixel_size <= 0)) {
    cli::cli_abort("pixel_size must contain two positive finite numbers.")
  }
  .sg_roi_check_string(pixel_unit)
  .sg_roi_check_string(source)
  .new_sg_roi_frame(source, "metadata", dims, length(level_dims), level_dims,
                    n_bands = 1L, pixel_size = pixel_size, pixel_unit = pixel_unit)
}
