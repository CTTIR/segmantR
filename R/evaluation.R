# Segmentation evaluation metrics

#' Evaluate segmentation quality
#'
#' Computes standard instance segmentation metrics by comparing a predicted
#' mask against a ground truth mask.
#'
#' @param predicted An `sg_mask` object with predicted segmentation.
#' @param ground_truth An `sg_mask` object with ground truth segmentation.
#' @param metrics Character vector of metrics to compute. One or more of
#'   `"dice"`, `"jaccard"`, `"aji"`, `"panoptic_quality"`, `"ap50"`,
#'   `"ap75"`, `"f1_detection"`. Default is all.
#'
#' @return An `sg_eval` S3 object (a tibble with columns `metric` and `value`)
#'   with a custom print method.
#' @export
#' @examples
#' pred_labels <- matrix(0L, nrow = 20, ncol = 20)
#' pred_labels[3:8, 3:8] <- 1L
#' pred_labels[12:18, 12:18] <- 2L
#' gt_labels <- matrix(0L, nrow = 20, ncol = 20)
#' gt_labels[3:9, 3:9] <- 1L
#' gt_labels[12:17, 12:17] <- 2L
#' pred <- new_sg_mask(pred_labels)
#' gt <- new_sg_mask(gt_labels)
#' result <- sg_evaluate_segmentation(pred, gt)
#' print(result)
sg_evaluate_segmentation <- function(predicted, ground_truth,
                                     metrics = c("dice", "jaccard", "aji",
                                                 "panoptic_quality", "ap50",
                                                 "ap75", "f1_detection")) {
  if (!inherits(predicted, "sg_mask")) {
    cli::cli_abort("{.arg predicted} must be an {.cls sg_mask} object.")
  }
  if (!inherits(ground_truth, "sg_mask")) {
    cli::cli_abort("{.arg ground_truth} must be an {.cls sg_mask} object.")
  }
  if (!identical(dim(predicted$labels), dim(ground_truth$labels))) {
    cli::cli_abort("Predicted and ground truth masks must have the same dimensions.")
  }
  metrics <- match.arg(metrics,
                       c("dice", "jaccard", "aji", "panoptic_quality",
                         "ap50", "ap75", "f1_detection"),
                       several.ok = TRUE)

  pred_lab <- predicted$labels
  gt_lab <- ground_truth$labels

  results <- tibble::tibble(
    metric = character(0),
    value = numeric(0)
  )

  # Binary masks for pixel-level metrics
  pred_binary <- as.integer(pred_lab > 0L)
  gt_binary <- as.integer(gt_lab > 0L)
  intersection_binary <- sum(pred_binary & gt_binary)
  union_binary <- sum(pred_binary | gt_binary)

  if ("dice" %in% metrics) {
    dice_val <- if (sum(pred_binary) + sum(gt_binary) == 0L) {
      1.0
    } else {
      2 * intersection_binary / (sum(pred_binary) + sum(gt_binary))
    }
    results <- rbind(results, tibble::tibble(metric = "dice", value = dice_val))
  }

  if ("jaccard" %in% metrics) {
    jaccard_val <- if (union_binary == 0L) 1.0 else intersection_binary / union_binary
    results <- rbind(results, tibble::tibble(metric = "jaccard",
                                             value = jaccard_val))
  }

  # Build IoU matrix for instance-level metrics
  pred_ids <- seq_len(predicted$n_cells)
  gt_ids <- seq_len(ground_truth$n_cells)

  iou_matrix <- NULL
  if (any(c("aji", "panoptic_quality", "ap50", "ap75", "f1_detection") %in% metrics)) {
    if (length(pred_ids) > 0L && length(gt_ids) > 0L) {
      iou_matrix <- matrix(0, nrow = length(pred_ids), ncol = length(gt_ids))
      for (pi in seq_along(pred_ids)) {
        pred_px <- pred_lab == pred_ids[pi]
        for (gi in seq_along(gt_ids)) {
          gt_px <- gt_lab == gt_ids[gi]
          inter <- sum(pred_px & gt_px)
          un <- sum(pred_px | gt_px)
          iou_matrix[pi, gi] <- if (un > 0L) inter / un else 0
        }
      }
    }
  }

  if ("aji" %in% metrics) {
    aji_val <- .compute_aji(pred_lab, gt_lab, pred_ids, gt_ids, iou_matrix)
    results <- rbind(results, tibble::tibble(metric = "aji", value = aji_val))
  }

  if ("panoptic_quality" %in% metrics) {
    pq_val <- .compute_panoptic_quality(iou_matrix, pred_ids, gt_ids)
    results <- rbind(results, tibble::tibble(metric = "panoptic_quality",
                                             value = pq_val))
  }

  if ("ap50" %in% metrics) {
    ap50_val <- .compute_ap_at_threshold(iou_matrix, pred_ids, gt_ids, 0.5)
    results <- rbind(results, tibble::tibble(metric = "ap50", value = ap50_val))
  }

  if ("ap75" %in% metrics) {
    ap75_val <- .compute_ap_at_threshold(iou_matrix, pred_ids, gt_ids, 0.75)
    results <- rbind(results, tibble::tibble(metric = "ap75", value = ap75_val))
  }

  if ("f1_detection" %in% metrics) {
    f1_val <- .compute_f1_detection(iou_matrix, pred_ids, gt_ids, 0.5)
    results <- rbind(results, tibble::tibble(metric = "f1_detection",
                                             value = f1_val))
  }

  class(results) <- c("sg_eval", class(results))

  cli::cli_inform(c("v" = "Computed {nrow(results)} segmentation metric{?s}."))
  results
}

#' @export
print.sg_eval <- function(x, ...) {
  cli::cli_text("{.cls sg_eval} \u2014 Segmentation Evaluation")
  cli::cli_rule()
  for (i in seq_len(nrow(x))) {
    cli::cli_text("{.strong {x$metric[i]}}: {round(x$value[i], 4)}")
  }
  cli::cli_rule()
  invisible(x)
}

# --- Internal metric helpers ---

#' Aggregated Jaccard Index
#' @noRd
.compute_aji <- function(pred_lab, gt_lab, pred_ids, gt_ids, iou_matrix) {
  if (length(gt_ids) == 0L && length(pred_ids) == 0L) return(1.0)
  if (length(gt_ids) == 0L || length(pred_ids) == 0L) return(0.0)

  numerator <- 0
  denominator <- 0

  matched_pred <- logical(length(pred_ids))

  for (gi in seq_along(gt_ids)) {
    gt_px <- gt_lab == gt_ids[gi]
    best_pi <- which.max(iou_matrix[, gi])
    if (length(best_pi) > 0L && iou_matrix[best_pi, gi] > 0) {
      pred_px <- pred_lab == pred_ids[best_pi]
      inter <- sum(gt_px & pred_px)
      un <- sum(gt_px | pred_px)
      numerator <- numerator + inter
      denominator <- denominator + un
      matched_pred[best_pi] <- TRUE
    } else {
      denominator <- denominator + sum(gt_px)
    }
  }

  # Add unmatched predictions to denominator
  for (pi in which(!matched_pred)) {
    denominator <- denominator + sum(pred_lab == pred_ids[pi])
  }

  if (denominator == 0) return(1.0)
  numerator / denominator
}

#' Panoptic Quality
#' @noRd
.compute_panoptic_quality <- function(iou_matrix, pred_ids, gt_ids) {
  if (length(gt_ids) == 0L && length(pred_ids) == 0L) return(1.0)
  if (is.null(iou_matrix) || length(gt_ids) == 0L || length(pred_ids) == 0L) {
    return(0.0)
  }

  tp <- 0L
  sum_iou <- 0
  matched_pred <- logical(length(pred_ids))
  matched_gt <- logical(length(gt_ids))

  for (gi in seq_along(gt_ids)) {
    best_pi <- which.max(iou_matrix[, gi])
    if (length(best_pi) > 0L && iou_matrix[best_pi, gi] > 0.5) {
      if (!matched_pred[best_pi]) {
        tp <- tp + 1L
        sum_iou <- sum_iou + iou_matrix[best_pi, gi]
        matched_pred[best_pi] <- TRUE
        matched_gt[gi] <- TRUE
      }
    }
  }

  fp <- sum(!matched_pred)
  fn <- sum(!matched_gt)

  sq <- if (tp > 0L) sum_iou / tp else 0
  rq <- if (tp + 0.5 * fp + 0.5 * fn > 0) tp / (tp + 0.5 * fp + 0.5 * fn) else 0
  sq * rq
}

#' Average Precision at IoU threshold
#' @noRd
.compute_ap_at_threshold <- function(iou_matrix, pred_ids, gt_ids, threshold) {
  if (length(gt_ids) == 0L && length(pred_ids) == 0L) return(1.0)
  if (is.null(iou_matrix) || length(gt_ids) == 0L || length(pred_ids) == 0L) {
    return(0.0)
  }

  tp <- 0L
  matched_gt <- logical(length(gt_ids))

  for (pi in seq_along(pred_ids)) {
    best_gi <- which.max(iou_matrix[pi, ])
    if (length(best_gi) > 0L && iou_matrix[pi, best_gi] >= threshold &&
        !matched_gt[best_gi]) {
      tp <- tp + 1L
      matched_gt[best_gi] <- TRUE
    }
  }

  fp <- length(pred_ids) - tp
  fn <- sum(!matched_gt)

  precision <- if (tp + fp > 0L) tp / (tp + fp) else 0
  recall <- if (tp + fn > 0L) tp / (tp + fn) else 0

  # AP approximated as precision * recall for single threshold
  if (precision + recall > 0) {
    2 * precision * recall / (precision + recall)
  } else {
    0
  }
}

#' F1 detection score
#' @noRd
.compute_f1_detection <- function(iou_matrix, pred_ids, gt_ids, threshold) {
  if (length(gt_ids) == 0L && length(pred_ids) == 0L) return(1.0)
  if (is.null(iou_matrix) || length(gt_ids) == 0L || length(pred_ids) == 0L) {
    return(0.0)
  }

  matched_gt <- logical(length(gt_ids))
  tp <- 0L

  for (pi in seq_along(pred_ids)) {
    best_gi <- which.max(iou_matrix[pi, ])
    if (length(best_gi) > 0L && iou_matrix[pi, best_gi] >= threshold &&
        !matched_gt[best_gi]) {
      tp <- tp + 1L
      matched_gt[best_gi] <- TRUE
    }
  }

  fp <- length(pred_ids) - tp
  fn <- sum(!matched_gt)

  precision <- if (tp + fp > 0L) tp / (tp + fp) else 0
  recall <- if (tp + fn > 0L) tp / (tp + fn) else 0

  if (precision + recall > 0) {
    2 * precision * recall / (precision + recall)
  } else {
    0
  }
}
