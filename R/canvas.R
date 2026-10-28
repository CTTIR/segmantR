# The offline drawing engine is adapted from annotatR (MIT, Raban Heller,
# 2026). This package owns its copy and has no runtime dependency on it.

#' Draw cell boundaries on a microscopy image
#'
#' The canvas uses local array pixel coordinates (top-left origin, x right,
#' y down). Drawing emits Shiny inputs suffixed `_created`, `_edited`, and
#' `_erased`. Use [sg_canvas_correct()] to stage changes to a mask.
#' @param image An `sg_image`.
#' @param mask Optional `sg_mask` bound to the same image.
#' @param channel One-based display channel.
#' @param tool Drawing tool.
#' @param width,height Widget dimensions.
#' @param elementId Optional widget id.
#' @return An HTML widget.
#' @export
#' @examplesIf rlang::is_installed(c("htmlwidgets", "magick"))
#' img <- new_sg_image(matrix(seq_len(72), 8, 9), id = "slide")
#' msk <- new_sg_mask(matrix(0L, 8, 9), image_id = "slide")
#' widget <- sg_canvas(img, msk, tool = "polygon")
#' class(widget)
#' if (interactive()) widget
sg_canvas <- function(image, mask = NULL, channel = 1L, tool = "pan",
                      width = NULL, height = 600, elementId = NULL) {
  .sg_assert_image(image)
  for (pkg in c("htmlwidgets", "magick")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      .sg_abort("Install {.pkg {pkg}} to use the cell annotation canvas.")
    }
  }
  tool <- match.arg(tool, c("pan", "rect", "polygon", "freehand", "circle", "edit", "erase"))
  pixels <- image$pixels
  n <- if (length(dim(pixels)) == 3L) dim(pixels)[3] else 1L
  if (length(channel) != 1L || !is.finite(channel) || channel != as.integer(channel) || channel < 1 || channel > n) {
    .sg_abort("Invalid display channel.")
  }
  if (length(dim(pixels)) == 3L) pixels <- pixels[, , channel]
  q <- stats::quantile(pixels, c(.02, .98), na.rm = TRUE)
  display <- if (all(is.finite(q)) && diff(q) > 0) pmin(1, pmax(0, (pixels - q[1]) / diff(q))) else pixels * 0
  display <- matrix(display, nrow(pixels), ncol(pixels))
  display[!is.finite(display)] <- 0
  rgb <- array(rep(display, 3), c(dim(display), 3L))
  png <- magick::image_write(magick::image_read(rgb), format = "png")
  features <- list()
  if (!is.null(mask)) {
    .sg_canvas_binding(image, mask)
    polys <- .sg_label_polygons(mask$labels)
    features <- lapply(names(polys), function(id) list(
      type = "Feature", properties = list(roi_id = id, label = id),
      geometry = .sg_geojson_geometry(polys[[id]])))
  }
  htmlwidgets::createWidget("sgcanvas", list(
    tileSource = list(width = ncol(pixels), height = nrow(pixels),
      dataUri = paste0("data:image/png;base64,", jsonlite::base64_enc(png))),
    annotations = list(type = "FeatureCollection", features = features),
    tool = tool, revision = if (!is.null(mask)) sg_mask_revision(mask) else NULL,
    options = list()), width = width, height = height,
    package = "segmantR", elementId = elementId)
}

.sg_require_htmlwidgets <- function() {
  if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
    .sg_abort("Install {.pkg htmlwidgets} to use the cell annotation canvas.")
  }
  invisible(TRUE)
}

.sg_canvas_binding <- function(image, mask) {
  .sg_assert_image(image)
  .sg_assert_mask(mask)
  if (!identical(dim(image$pixels)[1:2], dim(mask$labels)) ||
      !identical(image$id, mask$image_id) ||
      !identical(image$origin, mask$origin) ||
      !identical(image$plane, mask$plane)) {
    .sg_abort("Canvas image and mask must have matching dimensions, identity, origin and plane.")
  }
}

#' Apply a cell canvas correction
#'
#' Geometry is in local array pixels. Changes retain image binding and are
#' staged for explicit review. Overlapping cells are rejected.
#' @param mask An `sg_mask`.
#' @param geometry GeoJSON Polygon or MultiPolygon, required for add/edit.
#' @param action One of `add`, `edit`, `erase`.
#' @param cell_id Existing integer label for edit/erase.
#' @param expected_revision Revision shown when the edit began.
#' @return A staged `sg_mask`.
#' @export
#' @examples
#' msk <- new_sg_mask(matrix(0L, 8, 9))
#' box <- list(type = "Polygon",
#'             coordinates = list(list(c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1))))
#' added <- sg_canvas_correct(msk, box, expected_revision = sg_mask_revision(msk))
#' sum(added$labels > 0)
#' added$review$status
sg_canvas_correct <- function(mask, geometry = NULL, action = "add",
                              cell_id = NULL, expected_revision) {
  .sg_assert_mask(mask)
  if (!identical(expected_revision, sg_mask_revision(mask))) {
    .sg_abort("Mask changed since the canvas was displayed.", code = "REVISION_CONFLICT")
  }
  action <- match.arg(action, c("add", "edit", "erase"))
  labels <- mask$labels
  ids <- sort(unique(labels[labels > 0L]))
  if (action != "add" && (length(cell_id) != 1L || is.na(cell_id) || !cell_id %in% ids)) {
    .sg_abort("Select an existing cell label.")
  }
  if (action != "add") labels[labels == cell_id] <- 0L
  if (action != "erase") {
    parsed <- tryCatch(.sg_geometry_rings(geometry), error = function(e) NULL)
    rings <- if (!is.null(parsed)) unlist(parsed$polygons, recursive = FALSE) else list()
    valid <- length(rings) > 0L && all(vapply(rings, function(r) {
      is.matrix(r) && nrow(r) >= 4L && all(is.finite(r)) &&
        identical(r[1, ], r[nrow(r), ]) &&
        all(r[, 1] >= 0 & r[, 1] <= ncol(labels)) &&
        all(r[, 2] >= 0 & r[, 2] <= nrow(labels))
    }, logical(1)))
    if (!valid) .sg_abort("Supply closed, finite cell polygons inside the image.")
    sel <- .sg_rasterise_polygons(parsed$polygons, dim(labels))
    if (!any(sel)) .sg_abort("The cell polygon contains no pixel centres.")
    if (any(labels[sel] > 0L)) .sg_abort("Cell polygons must not overlap other cells.")
    id <- if (action == "add") max(ids, 0L) + 1L else as.integer(cell_id)
    labels[sel] <- id
  }
  out <- .sg_mask_derive(mask, labels, label_map = stats::setNames(ids, ids),
                         operation = paste0("canvas_", action))
  sg_stage_mask(out, parent = mask, source = paste0("canvas_", action))
}

#' Shiny bindings for the cell canvas
#' @param outputId Output id.
#' @param width,height Output dimensions.
#' @return A Shiny output element or render function.
#' @export
#' @examples
#' if (interactive() && requireNamespace("htmlwidgets", quietly = TRUE) &&
#'     requireNamespace("magick", quietly = TRUE)) {
#'   img <- new_sg_image(matrix(seq_len(72), 8, 9))
#'   ui <- shiny::fluidPage(sgCanvasOutput("canvas"))
#'   server <- function(input, output, session) {
#'     output$canvas <- renderSgCanvas(sg_canvas(img))
#'   }
#'   shiny::shinyApp(ui, server)
#' }
sgCanvasOutput <- function(outputId, width = "100%", height = "600px") {
  .sg_require_htmlwidgets()
  htmlwidgets::shinyWidgetOutput(outputId, "sgcanvas", width, height, package = "segmantR")
}

#' @rdname sgCanvasOutput
#' @param expr Expression returning [sg_canvas()].
#' @param env Evaluation environment.
#' @param quoted Whether expr is quoted.
#' @export
renderSgCanvas <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  .sg_require_htmlwidgets()
  htmlwidgets::shinyRenderWidget(expr, sgCanvasOutput, env, quoted = TRUE)
}
