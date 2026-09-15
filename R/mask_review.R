# Mask legends, content revisions and the staged/reviewed workflow

#' Effective legend of a mask
#'
#' Returns the stored legend or, when none is stored, a deterministic legend
#' with one row per positive label. Generated object ids are UUID-shaped
#' strings derived from the image binding, the label content and the label
#' value, so the same mask always yields the same ids. Use
#' `sg_mask_legend(mask, materialise = TRUE)` to store the legend in the mask
#' so ids stay stable through later edits.
#'
#' @param mask An `sg_mask` object.
#' @param materialise Logical; if `TRUE`, return the mask with the legend
#'   stored instead of the legend table.
#'
#' @return A tibble with columns `label`, `object_id`, `class`, `name`, or
#'   the updated mask when `materialise = TRUE`.
#' @export
#' @examples
#' labels <- matrix(0L, 6, 6)
#' labels[2:3, 2:3] <- 1L
#' labels[5:6, 5:6] <- 2L
#' sg_mask_legend(new_sg_mask(labels, image_id = "img-1"))
sg_mask_legend <- function(mask, materialise = FALSE) {
  .sg_assert_mask(mask)
  ids <- sort(unique(mask$labels[mask$labels > 0L]))
  legend <- mask$legend
  if (is.null(legend)) {
    content <- .sg_array_digest(mask$labels)
    binding <- mask$image_id %||% "unbound"
    legend <- tibble::tibble(
      label = as.integer(ids),
      object_id = vapply(ids, function(id) {
        .sg_uuid_from_key(c(binding, content, id))
      }, character(1)),
      class = if ((mask$mask_type %||% "instance") == "binary") {
        rep("foreground", length(ids))
      } else {
        rep(NA_character_, length(ids))
      },
      name = NA_character_
    )
  }
  if (materialise) {
    mask$legend <- .sg_check_legend(legend)
    return(mask)
  }
  legend
}

#' Content revision of a mask
#'
#' A `"sha256:<hex>"` digest over the label array (dimensions and row-major
#' little-endian int32 values), the mask type and the effective legend.
#' Identical content always yields the same revision, so repeated imports of
#' the same prediction are idempotent.
#'
#' @param mask An `sg_mask` object.
#' @return Character scalar.
#' @export
#' @examples
#' m <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2))
#' sg_mask_revision(m)
sg_mask_revision <- function(mask) {
  .sg_assert_mask(mask)
  legend <- sg_mask_legend(mask)
  meta <- list(
    labels = .sg_array_digest(mask$labels),
    mask_type = mask$mask_type %||% "instance",
    legend = lapply(seq_len(nrow(legend)), function(i) {
      list(label = legend$label[i], object_id = legend$object_id[i],
           class = legend$class[i])
    })
  )
  .sg_digest_json(meta)
}

#' Review state of a mask
#'
#' @param mask An `sg_mask` object.
#' @return A list with `status`, `revision` (current content revision),
#'   `reviewed_revision`, `parent_revision` and `consistent` (`FALSE` when a
#'   reviewed mask was modified after review).
#' @export
#' @examples
#' sg_mask_status(new_sg_mask(matrix(0L, 3, 3)))
sg_mask_status <- function(mask) {
  .sg_assert_mask(mask)
  review <- .sg_review(mask)
  current <- sg_mask_revision(mask)
  consistent <- review$status != "reviewed" ||
    identical(review$revision, current)
  list(status = review$status, revision = current,
       reviewed_revision = review$revision,
       parent_revision = review$parent_revision,
       consistent = consistent,
       history = review$history)
}

#' Stage, review or replace masks
#'
#' `sg_stage_mask()` marks a mask as a staged candidate (for example an
#' imported prediction). `sg_review_mask()` records that a human reviewed
#' the current content. `sg_replace_mask()` replaces a mask by a candidate
#' while protecting reviewed data: replacing a reviewed mask requires both
#' `expected_revision` equal to its current revision and `overwrite = TRUE`.
#' Replacing with identical content is a no-op that keeps the current
#' status.
#'
#' @param mask,current An `sg_mask` object.
#' @param replacement The candidate `sg_mask`.
#' @param source Optional short description of where the candidate came
#'   from (e.g. `"stardist.2d.v1 prediction"`).
#' @param parent Optional `sg_mask` or revision string the candidate derives
#'   from.
#' @param reviewer Optional reviewer name or identifier.
#' @param note Optional free-text note stored in the review history (never
#'   evaluated).
#' @param expected_revision Revision the caller believes is current. Required
#'   to review a staged mask or to replace a reviewed one.
#' @param overwrite Logical; explicit decision to replace a reviewed mask.
#'
#' @return The updated `sg_mask`.
#' @name sg_mask_review
#' @examples
#' m <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2))
#' staged <- sg_stage_mask(m, source = "example")
#' rev <- sg_mask_revision(staged)
#' reviewed <- sg_review_mask(staged, reviewer = "me", expected_revision = rev)
#' sg_mask_status(reviewed)$status
#'
#' candidate <- new_sg_mask(matrix(c(1L, 1L, 1L, 0L), 2))
#' try(sg_replace_mask(reviewed, candidate))
#' replaced <- sg_replace_mask(reviewed, candidate,
#'                             expected_revision = rev, overwrite = TRUE)
#' sg_mask_status(replaced)$status
NULL

#' @rdname sg_mask_review
#' @export
sg_stage_mask <- function(mask, source = NULL, parent = NULL) {
  .sg_assert_mask(mask)
  review <- .sg_review(mask)
  if (review$status == "reviewed") {
    .sg_abort(
      c("A reviewed mask cannot be moved back to staged.",
        "i" = "Use {.fn sg_replace_mask} with an explicit revision instead."),
      class = "sg_conflict_error", code = "REVIEWED_OVERWRITE_DENIED"
    )
  }
  parent_rev <- if (inherits(parent, "sg_mask")) {
    sg_mask_revision(parent)
  } else {
    parent %||% review$parent_revision
  }
  mask <- sg_mask_legend(mask, materialise = TRUE)
  review$status <- "staged"
  review$parent_revision <- parent_rev %||% NA_character_
  review$history <- c(review$history, list(list(
    status = "staged", revision = sg_mask_revision(mask),
    at = .sg_utc_now(), note = source %||% NA_character_
  )))
  mask$review <- review
  mask
}

#' @rdname sg_mask_review
#' @export
sg_review_mask <- function(mask, reviewer = NULL, note = NULL,
                           expected_revision = NULL) {
  .sg_assert_mask(mask)
  review <- .sg_review(mask)
  current <- sg_mask_revision(mask)
  if (review$status == "reviewed" && identical(review$revision, current)) {
    return(mask)
  }
  if (!is.null(expected_revision) && !identical(expected_revision, current)) {
    .sg_abort(
      c("The mask changed since it was inspected.",
        "i" = "Expected revision {.val {expected_revision}}, current {.val {current}}."),
      class = "sg_conflict_error", code = "REVISION_CONFLICT",
      details = list(expected = expected_revision, current = current)
    )
  }
  if (review$status != "draft" && is.null(expected_revision)) {
    .sg_abort(
      c("Reviewing a {review$status} mask requires {.arg expected_revision}.",
        "i" = "Pass {.code sg_mask_revision(mask)} after inspecting it."),
      class = "sg_conflict_error", code = "REVISION_CONFLICT"
    )
  }
  mask <- sg_mask_legend(mask, materialise = TRUE)
  review$status <- "reviewed"
  review$revision <- current
  review$reviewed_at <- .sg_utc_now()
  review$reviewer <- reviewer %||% NA_character_
  review$history <- c(review$history, list(list(
    status = "reviewed", revision = current, at = review$reviewed_at,
    note = note %||% NA_character_
  )))
  mask$review <- review
  mask
}

#' @rdname sg_mask_review
#' @export
sg_replace_mask <- function(current, replacement, expected_revision = NULL,
                            overwrite = FALSE) {
  .sg_assert_mask(current)
  .sg_assert_mask(replacement)
  stopifnot(is.logical(overwrite), length(overwrite) == 1L)
  cur_rev <- sg_mask_revision(current)
  new_rev <- sg_mask_revision(replacement)
  if (identical(cur_rev, new_rev)) {
    return(current)
  }
  if (!identical(dim(current$labels), dim(replacement$labels))) {
    .sg_abort("Replacement mask has different dimensions.",
              code = "DIMENSION_MISMATCH",
              details = list(current = dim(current$labels),
                             replacement = dim(replacement$labels)))
  }
  if (!is.null(expected_revision) && !identical(expected_revision, cur_rev)) {
    .sg_abort(
      "The current mask changed since {.arg expected_revision} was read.",
      class = "sg_conflict_error", code = "REVISION_CONFLICT",
      details = list(expected = expected_revision, current = cur_rev)
    )
  }
  if (.sg_review(current)$status == "reviewed") {
    if (is.null(expected_revision) || !isTRUE(overwrite)) {
      .sg_abort(
        c("Refusing to replace a reviewed mask.",
          "i" = "Pass {.arg expected_revision} = {.val {cur_rev}} and {.code overwrite = TRUE} to replace it."),
        class = "sg_conflict_error", code = "REVIEWED_OVERWRITE_DENIED",
        details = list(current = cur_rev)
      )
    }
  }
  out <- replacement
  review <- .sg_review(out)
  review$status <- "staged"
  review$revision <- NA_character_
  review$parent_revision <- cur_rev
  review$history <- c(.sg_review(current)$history, list(list(
    status = "staged", revision = new_rev, at = .sg_utc_now(),
    note = paste0("replaces ", cur_rev)
  )))
  out$review <- review
  sg_mask_legend(out, materialise = TRUE)
}

#' Review record with defaults for legacy masks
#' @noRd
.sg_review <- function(mask) {
  def <- list(status = "draft", revision = NA_character_,
              parent_revision = NA_character_, reviewed_at = NA_character_,
              reviewer = NA_character_, history = list())
  if (is.null(mask$review)) return(def)
  utils::modifyList(def, mask$review)
}

#' @noRd
.sg_assert_mask <- function(mask, arg = "mask") {
  if (!inherits(mask, "sg_mask")) {
    .sg_abort("{.arg {arg}} must be an {.cls sg_mask} object.",
              code = "VALIDATION_FAILED")
  }
  invisible(mask)
}

#' @noRd
.sg_assert_image <- function(image, arg = "image") {
  if (!inherits(image, "sg_image")) {
    .sg_abort("{.arg {arg}} must be an {.cls sg_image} object.",
              code = "VALIDATION_FAILED")
  }
  invisible(image)
}

#' Derive a new mask from an existing one after a label operation
#'
#' Carries image binding, geometry and provenance; remaps the legend through
#' `label_map` (named by old label, values new label); new labels get fresh
#' legend rows. Derived masks of staged or reviewed parents are staged.
#' @noRd
.sg_mask_derive <- function(parent, labels, label_map = NULL,
                            operation = "derive", model_info = NULL,
                            mask_type = NULL) {
  out <- new_sg_mask(labels, image_id = parent$image_id,
                     model_info = model_info %||% parent$model_info,
                     mask_type = mask_type %||% parent$mask_type %||%
                       "instance",
                     plane = parent$plane, origin = parent$origin,
                     provenance = parent$provenance %||% list(),
                     id = parent$id)
  if (!is.null(label_map)) {
    # Materialise the parent's effective legend so object ids survive edits.
    old <- sg_mask_legend(parent)
    new_ids <- sort(unique(labels[labels > 0L]))
    rows <- lapply(new_ids, function(nid) {
      src <- as.integer(names(label_map)[label_map == nid])
      hit <- old[old$label %in% src, , drop = FALSE]
      if (nrow(hit) > 0L) {
        r <- hit[1, , drop = FALSE]
        r$label <- nid
        r
      } else {
        tibble::tibble(label = nid, object_id = NA_character_,
                       class = NA_character_, name = NA_character_)
      }
    })
    leg <- do.call(rbind, rows)
    if (!is.null(leg) && nrow(leg)) {
      missing_id <- is.na(leg$object_id) | duplicated(leg$object_id)
      leg$object_id[missing_id] <- vapply(leg$label[missing_id], function(l) {
        .sg_uuid_from_key(c(parent$image_id %||% "unbound", operation,
                            .sg_array_digest(labels), l))
      }, character(1))
      out$legend <- .sg_check_legend(leg)
    }
  }
  pstat <- .sg_review(parent)
  if (pstat$status != "draft") {
    out$review$status <- "staged"
    out$review$parent_revision <- sg_mask_revision(parent)
    out$review$history <- c(pstat$history, list(list(
      status = "staged", revision = sg_mask_revision(out),
      at = .sg_utc_now(), note = operation
    )))
  }
  out
}
