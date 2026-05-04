#' Create a new sg_mask object
#'
#' Constructor for the `sg_mask` S3 class, which stores an integer label
#' matrix where 0 represents background and positive integers represent
#' individual cell IDs.
#'
#' @param labels Integer matrix of cell labels. 0 = background,
#'   1..N = cell IDs.
#' @param image_id Optional character string identifying the source image.
#' @param model_info Optional named list of model metadata.
#'
#' @return An object of class `sg_mask`.
#' @export
#' @examples
#' labels <- matrix(c(0L, 0L, 1L, 1L, 0L, 2L, 2L, 0L, 0L), nrow = 3)
#' mask <- new_sg_mask(labels)
#' print(mask)
new_sg_mask <- function(labels, image_id = NULL, model_info = NULL) {
  stopifnot(is.integer(labels) || is.numeric(labels))
  if (!is.matrix(labels)) {
    if (is.null(dim(labels))) {
      cli::cli_abort("{.arg labels} must be a matrix.")
    }
  }
  labels <- matrix(as.integer(labels), nrow = nrow(labels), ncol = ncol(labels))
  n <- max(labels, na.rm = TRUE)
  if (is.na(n) || n < 0L) n <- 0L
  structure(
    list(
      labels = labels,
      n_cells = n,
      image_id = image_id,
      model_info = model_info %||% list()
    ),
    class = "sg_mask"
  )
}

#' @export
print.sg_mask <- function(x, ...) {
  dims <- dim(x$labels)
  cli::cli_text("{.cls sg_mask}: {dims[1]} x {dims[2]}, {x$n_cells} cell{?s}")
  if (length(x$model_info) > 0L && !is.null(x$model_info$method)) {
    cli::cli_text("Method: {x$model_info$method}")
  }
  invisible(x)
}

#' @export
summary.sg_mask <- function(object, ...) {
  labels <- object$labels
  cell_ids <- unique(as.vector(labels))
  cell_ids <- cell_ids[cell_ids > 0L]
  if (length(cell_ids) == 0L) {
    cli::cli_text("Empty mask (no cells)")
    return(invisible(NULL))
  }
  areas <- vapply(cell_ids, function(id) sum(labels == id), integer(1))
  cli::cli_text("{.cls sg_mask}: {length(cell_ids)} cells")
  cli::cli_text("Cell area - min: {min(areas)}, median: {stats::median(areas)}, max: {max(areas)}")
  invisible(tibble::tibble(cell_id = cell_ids, area = areas))
}

#' @export
dim.sg_mask <- function(x) {
  dim(x$labels)
}
