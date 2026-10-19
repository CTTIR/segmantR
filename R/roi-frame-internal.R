# The sg_roi_frame class: a lightweight, backend-agnostic image handle holding
# metadata and a lazy accessor, never pixel data for large images.

# Internal constructor. Users obtain a frame from sg_roi_frame().
.new_sg_roi_frame <- function(source,
                            backend,
                            dims,
                            n_levels,
                            level_dims,
                            n_bands,
                            band_names = NA_character_,
                            wavelengths = NULL,
                            wavelength_unit = NULL,
                            pixel_size = c(1, 1),
                            pixel_unit = "px",
                            dtype = "uint8",
                            handle = NULL,
                            meta = list()) {
  structure(
    list(
      source          = as.character(source),
      backend         = as.character(backend),
      dims            = as.integer(dims),
      n_levels        = as.integer(n_levels),
      level_dims      = lapply(level_dims, as.integer),
      n_bands         = as.integer(n_bands),
      band_names      = band_names,
      wavelengths     = wavelengths,
      wavelength_unit = wavelength_unit,
      pixel_size      = as.numeric(pixel_size),
      pixel_unit      = as.character(pixel_unit),
      dtype           = as.character(dtype),
      handle          = handle,
      meta            = meta
    ),
    class = "sg_roi_frame"
  )
}

#' Image dimensions at a pyramid level
#'
#' Return the pixel dimensions `c(width, height)` of an [sg_roi_frame] at a
#' given pyramid level.
#'
#' @param x An [sg_roi_frame].
#' @param level Integer pyramid level, `0` for full resolution. Must be in
#'   the declared zero-based pyramid range.
#' @param call The calling environment, for error reporting.
#'
#' @return An integer vector of length 2, `c(width, height)`.
#' @family images
#' @seealso [sg_roi_frame()]
#' @export
#' @examples
#' sg_roi_dims(sg_roi_frame(c(100, 80)))
sg_roi_dims <- function(x, level = 0L, call = rlang::caller_env()) {
  .sg_roi_check_image(x, call = call)
  level <- .sg_roi_check_count(level, call = call)
  if (level > x$n_levels - 1L) {
    cli::cli_abort(
      c(
        "{.arg level} exceeds the available pyramid levels.",
        "x" = "Level {level} was requested but only levels {.val {0:(x$n_levels - 1L)}} exist."
      ),
      call = call
    )
  }
  x$level_dims[[level + 1L]]
}
