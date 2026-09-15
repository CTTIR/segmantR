#' Clean up a label mask
#'
#' Applies the `postprocess.label-cleanup.v1` rules to an `sg_mask` in a
#' fixed order: handling of disconnected label parts, hole filling,
#' separation of touching objects, border removal, area filtering and
#' relabelling. The legend (object ids, classes) follows the labels.
#'
#' @param mask An `sg_mask` object.
#' @param min_area Minimum object area in pixels (full-resolution pixels
#'   for downsampled masks are not assumed; areas are array pixels).
#' @param max_area Maximum object area in pixels, or `NULL` for no limit.
#' @param min_area_um2,max_area_um2 Area limits in square micrometres;
#'   require `pixel_size`.
#' @param fill_holes Logical; fill background holes enclosed by one label.
#' @param connectivity `4L` or `8L`; used for hole detection and
#'   disconnected-part handling.
#' @param border `"keep"` or `"remove"` objects touching the array border.
#' @param touching `"keep"` or `"separate"`; `"separate"` sets contact
#'   pixels of the higher label to background (4-neighbourhood).
#' @param disconnected `"keep"`, `"split"` (new labels for extra parts) or
#'   `"keep_largest"` for labels consisting of several parts.
#' @param relabel `"value"` (1..N keeping order), `"raster"` (1..N by first
#'   appearance) or `"none"`.
#' @param pixel_size Optional list with `x` and `y` in micrometres.
#'
#' @return A new `sg_mask`. Masks derived from staged or reviewed masks are
#'   staged.
#' @export
#' @examples
#' labels <- matrix(0L, 12, 12)
#' labels[2:4, 2:4] <- 1L
#' labels[7:11, 7:11] <- 2L
#' labels[9, 9] <- 0L
#' out <- sg_cleanup_labels(new_sg_mask(labels), min_area = 10L,
#'                          fill_holes = TRUE)
#' out$n_cells
sg_cleanup_labels <- function(mask, min_area = 0L, max_area = NULL,
                              min_area_um2 = NULL, max_area_um2 = NULL,
                              fill_holes = FALSE, connectivity = 4L,
                              border = c("keep", "remove"),
                              touching = c("keep", "separate"),
                              disconnected = c("keep", "split",
                                               "keep_largest"),
                              relabel = c("value", "raster", "none"),
                              pixel_size = NULL) {
  .sg_assert_mask(mask)
  border <- match.arg(border)
  touching <- match.arg(touching)
  disconnected <- match.arg(disconnected)
  relabel <- match.arg(relabel)
  connectivity <- as.integer(connectivity)
  if (!connectivity %in% c(4L, 8L)) {
    .sg_abort("{.arg connectivity} must be 4 or 8.",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  if (!is.null(min_area_um2) || !is.null(max_area_um2)) {
    px <- pixel_size$x %||% NA_real_
    py <- pixel_size$y %||% NA_real_
    if (!is.numeric(px) || !is.numeric(py) || !is.finite(px) ||
        !is.finite(py) || px <= 0 || py <= 0) {
      .sg_abort(
        c("Area limits in um^2 need a pixel calibration.",
          "i" = "Provide {.arg pixel_size} or use the pixel limits."),
        class = "sg_calibration_error", code = "CALIBRATION_MISSING"
      )
    }
  }
  labels <- mask$labels
  labels[is.na(labels)] <- 0L
  original <- labels
  labels <- .sg_disconnected(labels, connectivity, disconnected)
  if (isTRUE(fill_holes)) labels <- .sg_fill_label_holes(labels, connectivity)
  if (touching == "separate") labels <- .sg_separate_touching(labels)
  if (border == "remove") labels <- .sg_remove_border(labels)
  max_px <- max_area %||% Inf
  labels <- .sg_area_filter(labels, min_area = min_area %||% 0,
                            max_area = max_px)
  if (!is.null(min_area_um2) || !is.null(max_area_um2)) {
    a_px <- pixel_size$x * pixel_size$y
    labels <- .sg_area_filter(labels,
                              min_area = (min_area_um2 %||% 0) / a_px,
                              max_area = (max_area_um2 %||% Inf) / a_px)
  }
  before <- labels
  if (relabel != "none") labels <- .sg_relabel(labels, relabel)
  ids_before <- before[before > 0L]
  ids_after <- labels[before > 0L]
  pairs <- unique(cbind(ids_before, ids_after))
  keep_old <- pairs[pairs[, 1] <= max(original, 0L), , drop = FALSE]
  label_map <- stats::setNames(keep_old[, 2], keep_old[, 1])
  .sg_mask_derive(mask, labels, label_map = label_map,
                  operation = "postprocess.label-cleanup")
}
