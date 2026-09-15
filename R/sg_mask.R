#' Create a new sg_mask object
#'
#' Constructor for the `sg_mask` S3 class, which stores an integer label
#' matrix where 0 represents background and positive integers represent
#' individual cell IDs.
#'
#' Masks follow the segmantR mask contract: integer values, `0` is the
#' background, positive integers are object instances (`mask_type =
#' "instance"`, the default and historic meaning), class codes
#' (`"labelled"`) or foreground (`"binary"`, values 0/1 only). All arguments
#' after `model_info` are optional interchange fields.
#'
#' @param labels Integer matrix of cell labels. 0 = background,
#'   1..N = cell IDs.
#' @param image_id Optional character string identifying the source image.
#' @param model_info Optional named list of model metadata.
#' @param mask_type One of `"instance"`, `"labelled"` or `"binary"`.
#' @param legend Optional data frame with one row per positive label and
#'   columns `label`, `object_id`, `class`, `name`. Missing legends are
#'   generated deterministically when needed (see [sg_mask_legend()]).
#' @param plane Optional plane list (see [new_sg_image()]).
#' @param origin Optional origin list (see [new_sg_image()]).
#' @param status Review status: `"draft"` (default), `"staged"` or
#'   `"reviewed"`. See [sg_review_mask()].
#' @param provenance Named list of provenance records.
#' @param id Optional mask identifier.
#'
#' @return An object of class `sg_mask`.
#' @export
#' @examples
#' labels <- matrix(c(0L, 0L, 1L, 1L, 0L, 2L, 2L, 0L, 0L), nrow = 3)
#' mask <- new_sg_mask(labels)
#' print(mask)
new_sg_mask <- function(labels, image_id = NULL, model_info = NULL,
                        mask_type = c("instance", "labelled", "binary"),
                        legend = NULL, plane = NULL, origin = NULL,
                        status = c("draft", "staged", "reviewed"),
                        provenance = list(), id = NULL) {
  stopifnot(is.integer(labels) || is.numeric(labels))
  if (!is.matrix(labels)) {
    if (is.null(dim(labels))) {
      cli::cli_abort("{.arg labels} must be a matrix.")
    }
  }
  mask_type <- match.arg(mask_type)
  status <- match.arg(status)
  labels <- matrix(as.integer(labels), nrow = nrow(labels), ncol = ncol(labels))
  n <- max(labels, na.rm = TRUE)
  if (is.na(n) || n < 0L) n <- 0L
  mask <- structure(
    list(
      labels = labels,
      n_cells = n,
      image_id = image_id,
      model_info = model_info %||% list(),
      mask_type = mask_type,
      legend = .sg_check_legend(legend),
      plane = .sg_check_plane(plane),
      origin = .sg_check_origin(origin),
      review = list(status = "draft", revision = NA_character_,
                    parent_revision = NA_character_,
                    reviewed_at = NA_character_, reviewer = NA_character_,
                    history = list()),
      provenance = provenance,
      id = id
    ),
    class = "sg_mask"
  )
  if (status != "draft") {
    mask$review$status <- status
    if (status == "reviewed") {
      mask$review$revision <- sg_mask_revision(mask)
      mask$review$reviewed_at <- .sg_utc_now()
    }
    mask$review$history <- list(list(
      status = status, revision = sg_mask_revision(mask),
      at = .sg_utc_now(), note = "constructed"
    ))
  }
  mask
}

#' Validate a legend table
#' @noRd
.sg_check_legend <- function(legend) {
  if (is.null(legend)) return(NULL)
  legend <- tibble::as_tibble(legend)
  if (!"label" %in% names(legend)) {
    .sg_abort("Legend needs a {.field label} column.",
              code = "LEGEND_INCOMPLETE")
  }
  lab <- legend$label
  if (!is.numeric(lab) || anyNA(lab) || any(lab < 1) ||
      any(lab != trunc(lab)) || anyDuplicated(lab)) {
    .sg_abort("Legend labels must be unique positive integers.",
              code = "LEGEND_INCOMPLETE")
  }
  legend$label <- as.integer(lab)
  for (col in c("object_id", "class", "name")) {
    if (!col %in% names(legend)) legend[[col]] <- NA_character_
    legend[[col]] <- as.character(legend[[col]])
  }
  if (anyDuplicated(stats::na.omit(legend$object_id))) {
    .sg_abort("Legend object ids must be unique.",
              code = "LEGEND_INCOMPLETE")
  }
  legend[order(legend$label), c("label", "object_id", "class", "name",
                                setdiff(names(legend), c("label", "object_id",
                                                         "class", "name")))]
}

#' @export
print.sg_mask <- function(x, ...) {
  dims <- dim(x$labels)
  cli::cli_text("{.cls sg_mask}: {dims[1]} x {dims[2]}, {x$n_cells} cell{?s}")
  if (length(x$model_info) > 0L && !is.null(x$model_info$method)) {
    cli::cli_text("Method: {x$model_info$method}")
  }
  if (!is.null(x$mask_type) && x$mask_type != "instance") {
    cli::cli_text("Type: {x$mask_type}")
  }
  if (!is.null(x$review) && x$review$status != "draft") {
    cli::cli_text("Status: {x$review$status}")
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
