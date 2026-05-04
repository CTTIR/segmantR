# Annotation task creation and correction application

#' Create an annotation task for human review
#'
#' Samples informative image patches for manual annotation or correction.
#' Patches are selected on a grid or, when an initial mask is provided,
#' prioritised by segmentation uncertainty.
#'
#' @param image An `sg_image` object.
#' @param initial_mask Optional `sg_mask` object. When provided, patches are
#'   scored by segmentation uncertainty and sampled accordingly.
#' @param region Optional numeric vector `c(row_min, row_max, col_min, col_max)`
#'   to restrict patch sampling to a sub-region.
#' @param n_patches Integer. Number of patches to sample. Default `20L`.
#' @param patch_size Integer. Size of each square patch in pixels.
#'   Default `256L`.
#'
#' @return An `sg_annotation_task` S3 object (a list with elements `patches`,
#'   `image_id`, `n_patches`, `patch_size`, and `created`).
#' @export
#' @examples
#' pixels <- matrix(runif(100 * 100), nrow = 100, ncol = 100)
#' img <- new_sg_image(pixels)
#' task <- sg_create_annotation_task(img, n_patches = 4L, patch_size = 32L)
#' print(task)
sg_create_annotation_task <- function(image, initial_mask = NULL,
                                      region = NULL, n_patches = 20L,
                                      patch_size = 256L) {
  if (!inherits(image, "sg_image")) {
    cli::cli_abort("{.arg image} must be an {.cls sg_image} object.")
  }
  n_patches <- as.integer(n_patches)
  patch_size <- as.integer(patch_size)

  if (!is.null(initial_mask) && !inherits(initial_mask, "sg_mask")) {
    cli::cli_abort("{.arg initial_mask} must be an {.cls sg_mask} object or NULL.")
  }

  # Optionally crop image to region
  work_image <- image
  if (!is.null(region)) {
    if (length(region) != 4L) {
      cli::cli_abort("{.arg region} must be a length-4 numeric vector: c(row_min, row_max, col_min, col_max).")
    }
    work_image <- image[region[1]:region[2], region[3]:region[4]]
  }

  strategy <- if (is.null(initial_mask)) "grid" else "uncertainty"
  patches <- .patch_sampler(work_image, mask = initial_mask,
                            n = n_patches, size = patch_size,
                            strategy = ifelse(strategy == "uncertainty",
                                              "grid", "grid"))

  # If we have a mask, score patches by uncertainty and re-rank
  if (!is.null(initial_mask) && length(patches) > 0L) {
    scores <- vapply(patches, function(p) {
      sub_mask <- new_sg_mask(
        initial_mask$labels[
          p$row_start:p$row_end,
          p$col_start:p$col_end
        ]
      )
      sub_img <- work_image[p$row_start:p$row_end, p$col_start:p$col_end]
      .uncertainty_score(sub_mask, sub_img)
    }, numeric(1))

    # Sort by descending uncertainty and take top n
    ord <- order(scores, decreasing = TRUE)
    patches <- patches[ord[seq_len(min(n_patches, length(ord)))]]
  }

  result <- structure(
    list(
      patches = patches,
      image_id = image$metadata$id %||% NA_character_,
      n_patches = length(patches),
      patch_size = patch_size,
      created = Sys.time()
    ),
    class = "sg_annotation_task"
  )

  cli::cli_inform(c(
    "v" = "Created annotation task with {length(patches)} patch{?es}.",
    "i" = "Patch size: {patch_size} x {patch_size} px."
  ))
  result
}

#' @export
print.sg_annotation_task <- function(x, ...) {
  cli::cli_text("{.cls sg_annotation_task}")
  cli::cli_text("Patches: {x$n_patches} ({x$patch_size} x {x$patch_size} px)")
  cli::cli_text("Created: {format(x$created, '%Y-%m-%d %H:%M:%S')}")
  invisible(x)
}

#' Apply manual corrections to a segmentation mask
#'
#' Takes a list of correction operations (split, merge, delete, add) and
#' applies them to produce a corrected mask.
#'
#' @param mask An `sg_mask` object.
#' @param corrections A list of correction operations. Each element is a list
#'   with at least an `$action` field (`"split"`, `"merge"`, `"delete"`, or
#'   `"add"`). See Details.
#'
#' @details
#' Each correction in the list must contain:
#' \describe{
#'   \item{`action = "delete"`}{Remove cell. Requires `$cell_id`.}
#'   \item{`action = "merge"`}{Merge cells. Requires `$cell_ids` (integer vector).}
#'   \item{`action = "split"`}{Split a cell. Requires `$cell_id` and
#'     `$seed_points` (matrix with columns row, col).}
#'   \item{`action = "add"`}{Add a new cell. Requires `$pixels` (matrix of
#'     row/col coordinates).}
#' }
#'
#' @return A corrected `sg_mask` object.
#' @export
#' @examples
#' labels <- matrix(0L, nrow = 20, ncol = 20)
#' labels[3:8, 3:8] <- 1L
#' labels[12:18, 12:18] <- 2L
#' mask <- new_sg_mask(labels)
#' corrected <- sg_apply_corrections(mask, list(
#'   list(action = "delete", cell_id = 2L)
#' ))
#' print(corrected)
sg_apply_corrections <- function(mask, corrections) {
  if (!inherits(mask, "sg_mask")) {
    cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object.")
  }
  if (!is.list(corrections)) {
    cli::cli_abort("{.arg corrections} must be a list of correction operations.")
  }

  labels <- mask$labels
  n_applied <- 0L

  for (corr in corrections) {
    if (!is.list(corr) || is.null(corr$action)) {
      cli::cli_abort("Each correction must be a list with an {.field action} field.")
    }
    action <- match.arg(corr$action, c("split", "merge", "delete", "add"))

    if (action == "delete") {
      if (is.null(corr$cell_id)) {
        cli::cli_abort("Delete correction requires {.field cell_id}.")
      }
      labels[labels == corr$cell_id] <- 0L
      n_applied <- n_applied + 1L

    } else if (action == "merge") {
      if (is.null(corr$cell_ids) || length(corr$cell_ids) < 2L) {
        cli::cli_abort("Merge correction requires {.field cell_ids} with at least 2 IDs.")
      }
      target_id <- corr$cell_ids[1]
      for (mid in corr$cell_ids[-1]) {
        labels[labels == mid] <- target_id
      }
      n_applied <- n_applied + 1L

    } else if (action == "split") {
      if (is.null(corr$cell_id) || is.null(corr$seed_points)) {
        cli::cli_abort("Split correction requires {.field cell_id} and {.field seed_points}.")
      }
      cell_binary <- ifelse(labels == corr$cell_id, 1L, 0L)
      # Place seeds
      max_label <- max(labels, na.rm = TRUE)
      seed_matrix <- matrix(0L, nrow = nrow(labels), ncol = ncol(labels))
      seeds <- corr$seed_points
      for (s in seq_len(nrow(seeds))) {
        r <- seeds[s, 1]
        cc <- seeds[s, 2]
        if (r >= 1L && r <= nrow(labels) && cc >= 1L && cc <= ncol(labels)) {
          seed_matrix[r, cc] <- max_label + s
        }
      }
      # Propagate seeds within the cell
      expanded <- .voronoi_propagate_r(seed_matrix, mask = cell_binary,
                                       expand_max = max(dim(labels)))
      # Replace old cell with new labels
      labels[labels == corr$cell_id] <- 0L
      labels[expanded > 0L] <- expanded[expanded > 0L]
      n_applied <- n_applied + 1L

    } else if (action == "add") {
      if (is.null(corr$pixels)) {
        cli::cli_abort("Add correction requires {.field pixels} (row/col matrix).")
      }
      new_id <- max(labels, na.rm = TRUE) + 1L
      px <- corr$pixels
      for (p in seq_len(nrow(px))) {
        r <- px[p, 1]
        cc <- px[p, 2]
        if (r >= 1L && r <= nrow(labels) && cc >= 1L && cc <= ncol(labels)) {
          labels[r, cc] <- new_id
        }
      }
      n_applied <- n_applied + 1L
    }
  }

  # Relabel contiguously
  unique_ids <- sort(unique(as.vector(labels)))
  unique_ids <- unique_ids[unique_ids > 0L]
  new_labels <- matrix(0L, nrow = nrow(labels), ncol = ncol(labels))
  for (i in seq_along(unique_ids)) {
    new_labels[labels == unique_ids[i]] <- as.integer(i)
  }

  cli::cli_inform(c(
    "v" = "Applied {n_applied} correction{?s}.",
    "i" = "Result: {length(unique_ids)} cell{?s}."
  ))

  new_sg_mask(new_labels, image_id = mask$image_id,
              model_info = mask$model_info)
}
