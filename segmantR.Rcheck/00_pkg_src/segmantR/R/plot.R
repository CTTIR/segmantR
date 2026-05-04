# Visualization functions for segmantR
# All sg_plot_* functions return ggplot2 objects

#' Overlay cell boundaries on an image
#'
#' Renders a single image channel as a raster and overlays cell outlines
#' from a segmentation mask.
#'
#' @param image An `sg_image` object.
#' @param mask An `sg_mask` object, or `NULL` to show the image only.
#' @param channel Integer, which channel to display (default `1L`).
#' @param outline_color Character, colour for cell outlines
#'   (default `"#FF00FF"`).
#' @param outline_width Numeric, width of the outline strokes (default `1`).
#' @param fill_alpha Numeric in \[0, 1\], fill opacity for cell regions
#'   (default `0`).
#' @param label_cells Logical, whether to draw cell-ID labels at centroids
#'   (default `FALSE`).
#' @param highlight Integer vector of cell IDs to highlight, or `NULL`
#'   for all cells.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' img <- new_sg_image(matrix(runif(400), 20, 20))
#' p <- sg_plot_overlay(img)
#' p
sg_plot_overlay <- function(image, mask = NULL, channel = 1L,
                            outline_color = "#FF00FF", outline_width = 1,
                            fill_alpha = 0, label_cells = FALSE,
                            highlight = NULL) {
  stopifnot(inherits(image, "sg_image"))
  pixels <- image$pixels
  if (length(dim(pixels)) == 3L) {
    pixels <- pixels[, , channel]
  }

  nr <- nrow(pixels)
  nc <- ncol(pixels)
  img_df <- expand.grid(
    col = seq_len(nc),
    row = seq_len(nr)
  )
  img_df$value <- as.vector(t(pixels))

  p <- ggplot2::ggplot(img_df, ggplot2::aes(
    x = .data[["col"]], y = .data[["row"]], fill = .data[["value"]]
  )) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_gradient(low = "black", high = "white") +
    ggplot2::scale_y_reverse() +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "none")


  if (!is.null(mask)) {
    stopifnot(inherits(mask, "sg_mask"))
    outline_df <- .mask_to_outline_df(mask$labels, highlight = highlight)
    if (nrow(outline_df) > 0L) {
      p <- p + ggplot2::geom_tile(
        data = outline_df,
        ggplot2::aes(
          x = .data[["col"]], y = .data[["row"]]
        ),
        fill = if (fill_alpha > 0) outline_color else NA,
        colour = outline_color,
        linewidth = outline_width,
        alpha = fill_alpha,
        inherit.aes = FALSE
      )
    }

    if (label_cells) {
      centroid_df <- .mask_centroids(mask$labels, highlight = highlight)
      if (nrow(centroid_df) > 0L) {
        p <- p + ggplot2::geom_text(
          data = centroid_df,
          ggplot2::aes(
            x = .data[["col"]], y = .data[["row"]],
            label = .data[["cell_id"]]
          ),
          colour = outline_color,
          size = 3,
          inherit.aes = FALSE
        )
      }
    }
  }

  p
}

#' Render a mask as a coloured image
#'
#' Assigns colours to cell regions based on cell ID, area, circularity,
#' or cluster membership.
#'
#' @param mask An `sg_mask` object.
#' @param color_by Character, one of `"id"`, `"area"`, `"circularity"`,
#'   or `"cluster"`.
#' @param features A data frame of cell features (required when `color_by`
#'   is `"area"`, `"circularity"`, or `"cluster"`). Must contain a
#'   `cell_id` column.
#' @param palette Character, name of a viridis palette
#'   (default `"viridis"`).
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' labels <- matrix(c(0L, 1L, 1L, 2L, 2L, 0L, 3L, 3L, 0L), 3, 3)
#' mask <- new_sg_mask(labels)
#' p <- sg_plot_mask(mask)
#' p
sg_plot_mask <- function(mask,
                         color_by = c("id", "area", "circularity", "cluster"),
                         features = NULL,
                         palette = "viridis") {
  stopifnot(inherits(mask, "sg_mask"))
  color_by <- match.arg(color_by)

  labels <- mask$labels
  nr <- nrow(labels)
  nc <- ncol(labels)

  mask_df <- expand.grid(col = seq_len(nc), row = seq_len(nr))
  mask_df$cell_id <- as.vector(t(labels))

  if (color_by == "id") {
    mask_df$fill_value <- as.factor(mask_df$cell_id)
    mask_df$fill_value[mask_df$cell_id == 0L] <- NA
  } else {
    if (is.null(features)) {
      cli::cli_abort(
        "A {.arg features} data frame is required when {.arg color_by} is {.val {color_by}}."
      )
    }
    stopifnot("cell_id" %in% names(features))
    merge_col <- color_by
    if (!merge_col %in% names(features)) {
      cli::cli_abort("Column {.val {merge_col}} not found in {.arg features}.")
    }
    lookup <- stats::setNames(features[[merge_col]], features[["cell_id"]])
    mask_df$fill_value <- lookup[as.character(mask_df$cell_id)]
    mask_df$fill_value[mask_df$cell_id == 0L] <- NA
  }

  p <- ggplot2::ggplot(mask_df, ggplot2::aes(
    x = .data[["col"]], y = .data[["row"]], fill = .data[["fill_value"]]
  )) +
    ggplot2::geom_raster() +
    ggplot2::scale_y_reverse() +
    ggplot2::coord_fixed() +
    ggplot2::theme_void()

  if (color_by == "id") {
    p <- p + ggplot2::scale_fill_viridis_d(
      option = palette, na.value = "grey20", name = "Cell ID"
    )
  } else {
    p <- p + ggplot2::scale_fill_viridis_c(
      option = palette, na.value = "grey20", name = color_by
    )
  }

  p
}

#' Scatter plot of cell features
#'
#' Produces a scatter plot of two numeric cell features, with optional
#' colour and faceting variables.
#'
#' @param features A data frame of cell features (e.g., from
#'   `sg_compute_features()`).
#' @param x Character, column name for the x-axis (default `"area"`).
#' @param y Character, column name for the y-axis
#'   (default `"mean_intensity"`).
#' @param color Character column name for point colour, or `NULL`.
#' @param facet Character column name for faceting, or `NULL`.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' feat <- data.frame(
#'   cell_id = 1:10,
#'   area = rpois(10, 200),
#'   mean_intensity = runif(10)
#' )
#' p <- sg_plot_features(feat, x = "area", y = "mean_intensity")
#' p
sg_plot_features <- function(features, x = "area", y = "mean_intensity",
                             color = NULL, facet = NULL) {
  stopifnot(is.data.frame(features))
  if (!x %in% names(features)) {
    cli::cli_abort("Column {.val {x}} not found in {.arg features}.")
  }
  if (!y %in% names(features)) {
    cli::cli_abort("Column {.val {y}} not found in {.arg features}.")
  }

  p <- ggplot2::ggplot(features, ggplot2::aes(
    x = .data[[x]], y = .data[[y]]
  )) +
    ggplot2::geom_point(alpha = 0.7) +
    ggplot2::labs(x = x, y = y) +
    ggplot2::theme_minimal()

  if (!is.null(color)) {
    if (!color %in% names(features)) {
      cli::cli_abort("Column {.val {color}} not found in {.arg features}.")
    }
    p <- ggplot2::ggplot(features, ggplot2::aes(
      x = .data[[x]], y = .data[[y]], colour = .data[[color]]
    )) +
      ggplot2::geom_point(alpha = 0.7) +
      ggplot2::labs(x = x, y = y, colour = color) +
      ggplot2::theme_minimal()
  }

  if (!is.null(facet)) {
    if (!facet %in% names(features)) {
      cli::cli_abort("Column {.val {facet}} not found in {.arg features}.")
    }
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data[[facet]]))
  }

  p
}

#' Side-by-side comparison of two masks
#'
#' Shows two segmentation masks (and optionally the source image) next to
#' each other using faceted panels.
#'
#' @param mask_a An `sg_mask` object (left panel).
#' @param mask_b An `sg_mask` object (right panel).
#' @param image An `sg_image` object, or `NULL`.
#' @param labels Character vector of length 2 giving panel titles
#'   (default `c("Method A", "Method B")`).
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' m1 <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2, 2))
#' m2 <- new_sg_mask(matrix(c(0L, 0L, 1L, 1L), 2, 2))
#' p <- sg_plot_comparison(m1, m2)
#' p
sg_plot_comparison <- function(mask_a, mask_b, image = NULL,
                               labels = c("Method A", "Method B")) {
  stopifnot(inherits(mask_a, "sg_mask"), inherits(mask_b, "sg_mask"))
  stopifnot(length(labels) == 2L)

  df_a <- .mask_to_df(mask_a$labels, panel_label = labels[1])
  df_b <- .mask_to_df(mask_b$labels, panel_label = labels[2])
  combined <- rbind(df_a, df_b)
  combined$panel <- factor(combined$panel, levels = labels)

  p <- ggplot2::ggplot(combined, ggplot2::aes(
    x = .data[["col"]], y = .data[["row"]],
    fill = .data[["cell_id"]]
  )) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_viridis_c(na.value = "grey20", name = "Cell ID") +
    ggplot2::scale_y_reverse() +
    ggplot2::coord_fixed() +
    ggplot2::facet_wrap(ggplot2::vars(.data[["panel"]])) +
    ggplot2::theme_void() +
    ggplot2::theme(strip.text = ggplot2::element_text(size = 12))

  p
}

#' Bar chart of evaluation metrics
#'
#' Displays a bar chart of segmentation evaluation metrics such as IoU,
#' precision, recall, and F1.
#'
#' @param eval_result A data frame with columns `metric` and `value`,
#'   e.g., from `sg_evaluate()`.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' res <- data.frame(
#'   metric = c("IoU", "Precision", "Recall", "F1"),
#'   value = c(0.82, 0.90, 0.85, 0.87)
#' )
#' p <- sg_plot_metrics(res)
#' p
sg_plot_metrics <- function(eval_result) {
  stopifnot(is.data.frame(eval_result))
  if (!all(c("metric", "value") %in% names(eval_result))) {
    cli::cli_abort(
      "{.arg eval_result} must contain columns {.val metric} and {.val value}."
    )
  }

  p <- ggplot2::ggplot(eval_result, ggplot2::aes(
    x = stats::reorder(.data[["metric"]], .data[["value"]]),
    y = .data[["value"]],
    fill = .data[["metric"]]
  )) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "Value") +
    ggplot2::theme_minimal() +
    ggplot2::scale_fill_viridis_d(option = "viridis") +
    ggplot2::ylim(0, 1)

  p
}


# ---- internal helpers -------------------------------------------------------

#' Extract boundary pixels from a label matrix
#' @noRd
.mask_to_outline_df <- function(labels, highlight = NULL) {
  nr <- nrow(labels)
  nc <- ncol(labels)

  is_border <- matrix(FALSE, nrow = nr, ncol = nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      cid <- labels[i, j]
      if (cid == 0L) next
      if (!is.null(highlight) && !cid %in% highlight) next
      if (i == 1L || i == nr || j == 1L || j == nc) {
        is_border[i, j] <- TRUE
        next
      }
      if (labels[i - 1L, j] != cid || labels[i + 1L, j] != cid ||
          labels[i, j - 1L] != cid || labels[i, j + 1L] != cid) {
        is_border[i, j] <- TRUE
      }
    }
  }

  idx <- which(is_border, arr.ind = TRUE)
  if (nrow(idx) == 0L) {
    return(data.frame(row = integer(0), col = integer(0)))
  }
  data.frame(row = idx[, 1], col = idx[, 2])
}

#' Compute centroids for cell IDs
#' @noRd
.mask_centroids <- function(labels, highlight = NULL) {
  cell_ids <- sort(unique(as.vector(labels)))
  cell_ids <- cell_ids[cell_ids > 0L]
  if (!is.null(highlight)) {
    cell_ids <- cell_ids[cell_ids %in% highlight]
  }
  if (length(cell_ids) == 0L) {
    return(data.frame(
      row = numeric(0), col = numeric(0), cell_id = integer(0)
    ))
  }
  rows <- vapply(cell_ids, function(cid) {
    mean(which(labels == cid, arr.ind = TRUE)[, 1])
  }, numeric(1))
  cols <- vapply(cell_ids, function(cid) {
    mean(which(labels == cid, arr.ind = TRUE)[, 2])
  }, numeric(1))
  data.frame(row = rows, col = cols, cell_id = cell_ids)
}

#' Convert label matrix to data frame for ggplot
#' @noRd
.mask_to_df <- function(labels, panel_label = "mask") {
  nr <- nrow(labels)
  nc <- ncol(labels)
  df <- expand.grid(col = seq_len(nc), row = seq_len(nr))
  vals <- as.vector(t(labels))
  df$cell_id <- ifelse(vals == 0L, NA_real_, as.numeric(vals))
  df$panel <- panel_label
  df
}
