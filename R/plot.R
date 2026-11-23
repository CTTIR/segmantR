# Visualization functions for segmantR
# All sg_plot_* functions return ggplot2 objects

#' Overlay cell boundaries on an image
#'
#' Renders a single image channel as a greyscale raster and overlays cell
#' outlines from a segmentation mask. Outlines follow the pixel edges between
#' a cell and its surroundings, so they stay sharp at any image size.
#'
#' @param image An `sg_image` object.
#' @param mask An `sg_mask` object with the same height and width as
#'   `image`, or `NULL` to show the image only.
#' @param channel Integer, which channel to display (default `1L`).
#' @param outline_color Character, colour for cell outlines, fills and labels
#'   (default `"#FF00FF"`).
#' @param outline_width Numeric, width of the outline strokes (default `1`).
#'   The width is in absolute units, as `linewidth` in 'ggplot2': reduce it
#'   (for example to `0.3`) for large images with many small cells.
#' @param fill_alpha Numeric in \[0, 1\], fill opacity for cell regions
#'   (default `0`, outlines only).
#' @param label_cells Logical, whether to draw cell-ID labels at centroids
#'   (default `FALSE`).
#' @param highlight Integer vector of cell IDs to highlight, or `NULL`
#'   for all cells.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' mask <- sg_example_mask("fluorescence_nuclei")
#' sg_plot_overlay(img, mask)
#'
#' # Fill and label two selected cells
#' sg_plot_overlay(img, mask, fill_alpha = 0.3, label_cells = TRUE,
#'                 highlight = c(1L, 5L))
sg_plot_overlay <- function(image, mask = NULL, channel = 1L,
                            outline_color = "#FF00FF", outline_width = 1,
                            fill_alpha = 0, label_cells = FALSE,
                            highlight = NULL) {
  if (!inherits(image, "sg_image")) {
    cli::cli_abort("{.arg image} must be an {.cls sg_image} object.")
  }
  if (!is.numeric(channel) || length(channel) != 1L || is.na(channel)) {
    cli::cli_abort("{.arg channel} must be a single channel number.")
  }
  if (!is.numeric(fill_alpha) || length(fill_alpha) != 1L ||
        is.na(fill_alpha) || fill_alpha < 0 || fill_alpha > 1) {
    cli::cli_abort("{.arg fill_alpha} must be a single number between 0 and 1.")
  }
  pixels <- .extract_channel(image, as.integer(channel))

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
    if (!inherits(mask, "sg_mask")) {
      cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object or {.code NULL}.")
    }
    if (!identical(dim(mask$labels), c(nr, nc))) {
      cli::cli_abort(c(
        "{.arg mask} and {.arg image} must have the same height and width.",
        "x" = "The image is {nr} x {nc}, the mask is {nrow(mask$labels)} x {ncol(mask$labels)}."
      ))
    }
    labels <- .mask_select_labels(mask$labels, highlight)

    if (fill_alpha > 0) {
      fill_idx <- which(labels > 0L, arr.ind = TRUE)
      if (nrow(fill_idx) > 0L) {
        fill_df <- data.frame(row = fill_idx[, 1], col = fill_idx[, 2])
        p <- p + ggplot2::geom_tile(
          data = fill_df,
          ggplot2::aes(x = .data[["col"]], y = .data[["row"]]),
          fill = outline_color,
          colour = NA,
          alpha = fill_alpha,
          inherit.aes = FALSE
        )
      }
    }

    outline_df <- .mask_outline_segments(labels)
    if (nrow(outline_df) > 0L) {
      p <- p + ggplot2::geom_segment(
        data = outline_df,
        ggplot2::aes(
          x = .data[["x"]], y = .data[["y"]],
          xend = .data[["xend"]], yend = .data[["yend"]]
        ),
        colour = outline_color,
        linewidth = outline_width,
        lineend = "square",
        inherit.aes = FALSE
      )
    }

    if (label_cells) {
      centroid_df <- .mask_centroids(labels)
      if (nrow(centroid_df) > 0L) {
        p <- p + ggplot2::geom_text(
          data = centroid_df,
          ggplot2::aes(
            x = .data[["col"]], y = .data[["row"]],
            label = .data[["cell_id"]]
          ),
          colour = outline_color,
          size = 3,
          fontface = "bold",
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
#'   is `"area"`, `"circularity"`, or `"cluster"`), for example from
#'   [sg_extract_features()]. Must contain a `cell_id` column and a column
#'   named like `color_by`. Numeric columns are drawn with a continuous
#'   colour scale; character, factor and logical columns (such as cluster
#'   names) with a discrete one.
#' @param palette Character, name of a viridis palette
#'   (default `"viridis"`).
#'
#' @details Background pixels are dark grey; cell colours skip the darkest
#'   fifth of the palette so that every cell stands out against it. With
#'   `color_by = "id"` the legend lists every cell and is therefore hidden
#'   for masks with more than 20 cells.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' mask <- sg_example_mask("fluorescence_nuclei")
#' sg_plot_mask(mask)
#'
#' # Colour by a measured feature
#' img <- sg_example_image("fluorescence_nuclei")
#' feat <- sg_extract_features(img, mask, features = "morphology")
#' sg_plot_mask(mask, color_by = "area", features = feat)
sg_plot_mask <- function(mask,
                         color_by = c("id", "area", "circularity", "cluster"),
                         features = NULL,
                         palette = "viridis") {
  if (!inherits(mask, "sg_mask")) {
    cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object.")
  }
  color_by <- match.arg(color_by)

  labels <- mask$labels
  nr <- nrow(labels)
  nc <- ncol(labels)

  mask_df <- expand.grid(col = seq_len(nc), row = seq_len(nr))
  mask_df$cell_id <- as.vector(t(labels))
  discrete <- TRUE
  n_levels <- 0L

  if (color_by == "id") {
    ids <- mask_df$cell_id
    ids[ids == 0L] <- NA
    mask_df$fill_value <- factor(ids)
    n_levels <- nlevels(mask_df$fill_value)
  } else {
    if (is.null(features)) {
      cli::cli_abort(
        "A {.arg features} data frame is required when {.arg color_by} is {.val {color_by}}."
      )
    }
    if (!is.data.frame(features) || !"cell_id" %in% names(features)) {
      cli::cli_abort(
        "{.arg features} must be a data frame with a {.field cell_id} column."
      )
    }
    merge_col <- color_by
    if (!merge_col %in% names(features)) {
      cli::cli_abort("Column {.val {merge_col}} not found in {.arg features}.")
    }
    values <- features[[merge_col]]
    discrete <- !is.numeric(values)
    if (discrete && !is.factor(values)) values <- factor(values)
    fill <- values[match(mask_df$cell_id, features[["cell_id"]])]
    fill[mask_df$cell_id == 0L] <- NA
    mask_df$fill_value <- fill
    if (discrete) n_levels <- nlevels(values)
  }

  p <- ggplot2::ggplot(mask_df, ggplot2::aes(
    x = .data[["col"]], y = .data[["row"]], fill = .data[["fill_value"]]
  )) +
    ggplot2::geom_raster() +
    ggplot2::scale_y_reverse() +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::theme(plot.margin = .sg_plot_margin())

  if (discrete) {
    # Fixed limits keep the background (NA, drawn in `na.value`) out of the
    # legend and unused factor levels in it.
    p <- p + ggplot2::scale_fill_viridis_d(
      option = palette, begin = .sg_viridis_begin, na.value = "grey20",
      limits = levels(mask_df$fill_value),
      name = if (color_by == "id") "Cell ID" else color_by
    )
    # A legend with one key per cell crowds out the image.
    if (color_by == "id" && n_levels > 20L) {
      p <- p + ggplot2::theme(legend.position = "none")
    }
  } else {
    p <- p + ggplot2::scale_fill_viridis_c(
      option = palette, begin = .sg_viridis_begin, na.value = "grey20",
      name = color_by
    )
  }

  p
}

#' Scatter plot of cell features
#'
#' Produces a scatter plot of two numeric cell features, with optional
#' colour and faceting variables.
#'
#' @param features A data frame of cell features with one row per cell, for
#'   example from [sg_extract_features()].
#' @param x Character, column name for the x-axis (default `"area"`).
#' @param y Character, column name for the y-axis
#'   (default `"mean_intensity"`). [sg_extract_features()] names intensity
#'   columns after the channel (for example `"ch1_mean"`), so pass that
#'   name for its output.
#' @param color Character column name for point colour, or `NULL`.
#' @param facet Character column name for faceting, or `NULL`.
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' mask <- sg_example_mask("fluorescence_nuclei")
#' feat <- sg_extract_features(img, mask,
#'                             features = c("intensity", "morphology"))
#' sg_plot_features(feat, x = "area", y = "DAPI_mean",
#'                  color = "circularity")
sg_plot_features <- function(features, x = "area", y = "mean_intensity",
                             color = NULL, facet = NULL) {
  if (!is.data.frame(features)) {
    cli::cli_abort("{.arg features} must be a data frame.")
  }
  if (!x %in% names(features)) {
    cli::cli_abort("Column {.val {x}} not found in {.arg features}.")
  }
  if (!y %in% names(features)) {
    cli::cli_abort("Column {.val {y}} not found in {.arg features}.")
  }

  mapping <- ggplot2::aes(x = .data[[x]], y = .data[[y]])
  if (!is.null(color)) {
    if (!color %in% names(features)) {
      cli::cli_abort("Column {.val {color}} not found in {.arg features}.")
    }
    mapping <- ggplot2::aes(
      x = .data[[x]], y = .data[[y]], colour = .data[[color]]
    )
  }

  p <- ggplot2::ggplot(features, mapping) +
    ggplot2::geom_point(alpha = 0.7) +
    ggplot2::labs(x = x, y = y, colour = color) +
    ggplot2::theme_minimal()

  if (!is.null(color)) {
    # Other column types (dates, date-times) keep the default scale of
    # 'ggplot2'; a discrete viridis scale does not accept them.
    values <- features[[color]]
    if (is.numeric(values)) {
      p <- p + ggplot2::scale_colour_viridis_c(end = 0.9)
    } else if (is.character(values) || is.factor(values) ||
                 is.logical(values)) {
      p <- p + ggplot2::scale_colour_viridis_d(end = 0.9)
    }
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
#' Shows two segmentation masks next to each other using faceted panels.
#' Cells are coloured by their label; the labels of the two masks are
#' independent, so equal colours do not mark matching cells.
#'
#' @param mask_a An `sg_mask` object (left panel).
#' @param mask_b An `sg_mask` object (right panel).
#' @param image An `sg_image` object, or `NULL`. Currently not drawn; use
#'   [sg_plot_overlay()] to show a mask on its image.
#' @param labels Character vector of two different panel titles
#'   (default `c("Method A", "Method B")`).
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' reference <- sg_example_mask("fluorescence_nuclei")
#' otsu <- sg_segment_threshold(img, min_area = 5)
#' sg_plot_comparison(reference, otsu, labels = c("Reference", "Otsu"))
sg_plot_comparison <- function(mask_a, mask_b, image = NULL,
                               labels = c("Method A", "Method B")) {
  if (!inherits(mask_a, "sg_mask") || !inherits(mask_b, "sg_mask")) {
    cli::cli_abort(
      "{.arg mask_a} and {.arg mask_b} must be {.cls sg_mask} objects."
    )
  }
  if (!is.character(labels) || length(labels) != 2L || anyNA(labels) ||
        labels[1] == labels[2]) {
    cli::cli_abort(
      "{.arg labels} must be a character vector of two different panel titles."
    )
  }

  df_a <- .mask_to_df(mask_a$labels, panel_label = labels[1])
  df_b <- .mask_to_df(mask_b$labels, panel_label = labels[2])
  combined <- rbind(df_a, df_b)
  combined$panel <- factor(combined$panel, levels = labels)

  p <- ggplot2::ggplot(combined, ggplot2::aes(
    x = .data[["col"]], y = .data[["row"]],
    fill = .data[["cell_id"]]
  )) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_viridis_c(
      begin = .sg_viridis_begin, na.value = "grey20", name = "Cell ID"
    ) +
    ggplot2::scale_y_reverse() +
    ggplot2::coord_fixed() +
    ggplot2::facet_wrap(ggplot2::vars(.data[["panel"]])) +
    ggplot2::theme_void() +
    ggplot2::theme(
      strip.text = ggplot2::element_text(
        size = 12, margin = ggplot2::margin(b = 6)
      ),
      plot.margin = .sg_plot_margin()
    )

  p
}

#' Bar chart of evaluation metrics
#'
#' Displays a bar chart of segmentation evaluation metrics on a 0 to 1
#' scale, such as Dice, Jaccard, panoptic quality and F1.
#'
#' @param eval_result A data frame with columns `metric` and `value`,
#'   for example from [sg_evaluate_segmentation()].
#'
#' @return A `ggplot2` object.
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' reference <- sg_example_mask("fluorescence_nuclei")
#' otsu <- sg_segment_threshold(img, min_area = 5)
#' sg_plot_metrics(sg_evaluate_segmentation(otsu, reference))
sg_plot_metrics <- function(eval_result) {
  if (!is.data.frame(eval_result)) {
    cli::cli_abort("{.arg eval_result} must be a data frame.")
  }
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
    ggplot2::scale_fill_viridis_d(option = "viridis", end = 0.9) +
    ggplot2::ylim(0, 1)

  p
}


# ---- internal helpers -------------------------------------------------------

# The darkest fifth of the viridis palettes is nearly indistinguishable from
# the dark grey ("grey20") mask background, so cell colours start above it.
.sg_viridis_begin <- 0.2

# theme_void() has no plot margin, which puts the legend flush against the
# edge of the device and clips its labels.
.sg_plot_margin <- function() {
  ggplot2::margin(5.5, 5.5, 5.5, 5.5)
}

#' Keep only the highlighted labels of a label matrix
#' @noRd
.mask_select_labels <- function(labels, highlight = NULL) {
  if (!is.null(highlight)) {
    labels[!(labels %in% highlight)] <- 0L
  }
  labels
}

#' Extract boundary pixels from a label matrix
#'
#' A foreground pixel is a boundary pixel when it lies on the image border
#' or when one of its four neighbours carries another label.
#' @noRd
.mask_to_outline_df <- function(labels, highlight = NULL) {
  nr <- nrow(labels)
  nc <- ncol(labels)

  differs <- matrix(FALSE, nrow = nr, ncol = nc)
  for (o in .sg_offsets(4L)) {
    # Out-of-image neighbours count as "another label" (-1 never occurs).
    differs <- differs | (.sg_shift(labels, o[1], o[2], -1L) != labels)
  }
  is_border <- differs & labels > 0L
  if (!is.null(highlight)) {
    is_border <- is_border & matrix(labels %in% highlight, nr, nc)
  }

  idx <- which(is_border, arr.ind = TRUE)
  if (nrow(idx) == 0L) {
    return(data.frame(row = integer(0), col = integer(0)))
  }
  data.frame(row = unname(idx[, 1]), col = unname(idx[, 2]))
}

#' Outline segments along the pixel edges of a label matrix
#'
#' Returns one segment per pixel edge that separates two different labels
#' (or a label from the image border), in the plotting coordinates of the
#' `sg_plot_*` functions: pixel `[row, col]` covers `col - 0.5` to
#' `col + 0.5` in x and `row - 0.5` to `row + 0.5` in y.
#' @noRd
.mask_outline_segments <- function(labels) {
  nr <- nrow(labels)
  nc <- ncol(labels)
  empty <- data.frame(x = numeric(0), y = numeric(0),
                      xend = numeric(0), yend = numeric(0))
  if (nr == 0L || nc == 0L || !any(labels > 0L)) return(empty)

  padded <- matrix(0L, nr + 2L, nc + 2L)
  padded[seq_len(nr) + 1L, seq_len(nc) + 1L] <- labels
  inner_rows <- seq_len(nr) + 1L
  inner_cols <- seq_len(nc) + 1L

  # Horizontal edges: between padded rows r and r + 1, at y = r - 0.5.
  h <- which(
    padded[seq_len(nr + 1L), inner_cols, drop = FALSE] !=
      padded[seq_len(nr + 1L) + 1L, inner_cols, drop = FALSE],
    arr.ind = TRUE
  )
  # Vertical edges: between padded columns c and c + 1, at x = c - 0.5.
  v <- which(
    padded[inner_rows, seq_len(nc + 1L), drop = FALSE] !=
      padded[inner_rows, seq_len(nc + 1L) + 1L, drop = FALSE],
    arr.ind = TRUE
  )
  data.frame(
    x = c(h[, 2] - 0.5, v[, 2] - 0.5),
    y = c(h[, 1] - 0.5, v[, 1] - 0.5),
    xend = c(h[, 2] + 0.5, v[, 2] - 0.5),
    yend = c(h[, 1] - 0.5, v[, 1] + 0.5)
  )
}

#' Compute centroids for cell IDs
#' @noRd
.mask_centroids <- function(labels, highlight = NULL) {
  labels <- .mask_select_labels(labels, highlight)
  pos <- which(labels > 0L)
  if (length(pos) == 0L) {
    return(data.frame(
      row = numeric(0), col = numeric(0), cell_id = integer(0)
    ))
  }
  ids <- labels[pos]
  sums <- rowsum(
    cbind(row = row(labels)[pos], col = col(labels)[pos], n = 1),
    group = ids
  )
  data.frame(
    row = unname(sums[, "row"] / sums[, "n"]),
    col = unname(sums[, "col"] / sums[, "n"]),
    cell_id = as.integer(rownames(sums))
  )
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
