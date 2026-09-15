# Vectorised label-matrix utilities used by protocols, post-processing,
# interchange validation and dataset preparation. Label matrices follow the
# segmantR mask contract: integer, 0 = background, positive integers =
# objects (instances) or class codes (labelled masks).

#' Shift a matrix by one pixel, padding with a fill value
#' @param dr,dc Row/column offset of the neighbour to read.
#' @noRd
.sg_shift <- function(m, dr, dc, fill) {
  nr <- nrow(m)
  nc <- ncol(m)
  out <- matrix(fill, nr, nc)
  r_lo <- max(1L, 1L - dr)
  r_hi <- min(nr, nr - dr)
  c_lo <- max(1L, 1L - dc)
  c_hi <- min(nc, nc - dc)
  if (r_lo <= r_hi && c_lo <= c_hi) {
    rs <- r_lo:r_hi
    cs <- c_lo:c_hi
    out[rs, cs] <- m[rs + dr, cs + dc]
  }
  out
}

#' Neighbour offsets for 4- or 8-connectivity
#' @noRd
.sg_offsets <- function(connectivity) {
  four <- list(c(-1L, 0L), c(1L, 0L), c(0L, -1L), c(0L, 1L))
  if (identical(as.integer(connectivity), 8L)) {
    return(c(four, list(c(-1L, -1L), c(-1L, 1L), c(1L, -1L), c(1L, 1L))))
  }
  four
}

#' Connected components of a logical/0-1 matrix
#'
#' Min-label propagation with pointer jumping. Components are numbered in
#' raster order (row-major: top row first, left to right), matching the
#' historic `.connected_components()` numbering for 4-connectivity.
#' @return Integer matrix of component ids (0 = background).
#' @noRd
.sg_components <- function(binary, connectivity = 4L) {
  fg <- matrix(as.logical(binary), nrow(binary), ncol(binary))
  fg[is.na(fg)] <- FALSE
  n <- length(fg)
  lab <- integer(n)
  idx <- which(fg)
  if (length(idx) == 0L) return(matrix(0L, nrow(fg), ncol(fg)))
  lab[idx] <- idx
  big <- n + 1L
  offs <- .sg_offsets(connectivity)
  repeat {
    cur <- matrix(lab, nrow(fg), ncol(fg))
    cur[!fg] <- big
    best <- cur
    for (o in offs) {
      best <- pmin(best, .sg_shift(cur, o[1], o[2], big))
    }
    new <- as.vector(best)
    new[!fg] <- 0L
    for (k in 1:4) new[idx] <- new[new[idx]]
    if (identical(new, lab)) break
    lab <- new
  }
  roots <- lab[idx]
  rows <- (idx - 1L) %% nrow(fg) + 1L
  cols <- (idx - 1L) %/% nrow(fg) + 1L
  raster_pos <- (rows - 1L) * ncol(fg) + cols
  first <- tapply(raster_pos, roots, min)
  ord <- order(as.numeric(first))
  map <- stats::setNames(seq_along(ord), names(first)[ord])
  out <- integer(n)
  out[idx] <- as.integer(map[as.character(roots)])
  matrix(out, nrow(fg), ncol(fg))
}

#' Relabel positive values to 1..K
#' @param order `"value"` keeps the relative order of existing ids;
#'   `"raster"` numbers objects by first appearance in row-major order.
#' @noRd
.sg_relabel <- function(labels, order = c("value", "raster")) {
  order <- match.arg(order)
  pos <- labels > 0L
  if (!any(pos)) {
    return(matrix(0L, nrow(labels), ncol(labels)))
  }
  if (order == "value") {
    ids <- sort(unique(labels[pos]))
  } else {
    ids <- unique(as.vector(t(labels))[as.vector(t(pos))])
  }
  out <- matrix(0L, nrow(labels), ncol(labels))
  out[pos] <- match(labels[pos], ids)
  out
}

#' Pixel count per positive label
#' @return Named integer vector (names = labels).
#' @noRd
.sg_label_areas <- function(labels) {
  v <- labels[labels > 0L]
  if (length(v) == 0L) return(stats::setNames(integer(0), character(0)))
  tab <- table(v)
  stats::setNames(as.integer(tab), names(tab))
}

#' Remove labels outside the min_area..max_area range (areas in pixels)
#' @noRd
.sg_area_filter <- function(labels, min_area = 0, max_area = Inf) {
  areas <- .sg_label_areas(labels)
  if (length(areas) == 0L) return(labels)
  drop <- as.integer(names(areas)[areas < min_area | areas > max_area])
  labels[labels %in% drop] <- 0L
  labels
}

#' Remove labels touching the array border
#' @noRd
.sg_remove_border <- function(labels) {
  nr <- nrow(labels)
  nc <- ncol(labels)
  edge <- unique(c(labels[1L, ], labels[nr, ], labels[, 1L], labels[, nc]))
  edge <- edge[edge > 0L]
  labels[labels %in% edge] <- 0L
  labels
}

#' Fill background holes enclosed by exactly one label
#'
#' Background components use the complementary connectivity (8 for 4-
#' connected objects and vice versa). A component is filled when it does not
#' touch the border and all its 4-neighbours belong to one label.
#' @noRd
.sg_fill_label_holes <- function(labels, connectivity = 4L) {
  bg_conn <- if (identical(as.integer(connectivity), 8L)) 4L else 8L
  bg <- .sg_components(labels == 0L, bg_conn)
  if (max(bg) == 0L) return(labels)
  nr <- nrow(labels)
  nc <- ncol(labels)
  border <- unique(c(bg[1L, ], bg[nr, ], bg[, 1L], bg[, nc]))
  pairs <- NULL
  for (o in .sg_offsets(4L)) {
    nb <- .sg_shift(labels, o[1], o[2], 0L)
    sel <- bg > 0L & nb > 0L
    if (any(sel)) pairs <- rbind(pairs, cbind(bg[sel], nb[sel]))
  }
  if (is.null(pairs)) return(labels)
  pairs <- unique(pairs)
  n_lab <- table(pairs[, 1])
  single <- as.integer(names(n_lab)[n_lab == 1L])
  single <- setdiff(single, border)
  if (length(single) == 0L) return(labels)
  target <- pairs[match(single, pairs[, 1]), 2]
  hit <- bg %in% single
  labels[hit] <- target[match(bg[hit], single)]
  labels
}

#' Split, keep largest, or keep disconnected parts of each label
#' @noRd
.sg_disconnected <- function(labels, connectivity = 4L,
                             policy = c("split", "keep_largest", "keep")) {
  policy <- match.arg(policy)
  if (policy == "keep" || !any(labels > 0L)) return(labels)
  offset <- max(labels) + 1L
  # Components of the label image: two pixels join only if equal labels.
  comp <- .sg_components_by_value(labels, connectivity)
  pos <- labels > 0L
  pairs <- unique(cbind(labels[pos], comp[pos]))
  multi <- as.integer(names(which(table(pairs[, 1]) > 1L)))
  if (length(multi) == 0L) return(labels)
  if (policy == "keep_largest") {
    carea <- table(comp[pos])
    for (lab in multi) {
      parts <- pairs[pairs[, 1] == lab, 2]
      a <- as.integer(carea[as.character(parts)])
      keep <- parts[which.max(a)]
      labels[labels == lab & comp != keep] <- 0L
    }
    return(labels)
  }
  next_id <- offset
  for (lab in multi) {
    parts <- sort(pairs[pairs[, 1] == lab, 2])
    for (p in parts[-1]) {
      labels[comp == p] <- next_id
      next_id <- next_id + 1L
    }
  }
  labels
}

#' Connected components where neighbours must share the same label value
#' @noRd
.sg_components_by_value <- function(labels, connectivity = 4L) {
  n <- length(labels)
  pos <- as.vector(labels > 0L)
  idx <- which(pos)
  lab <- integer(n)
  if (length(idx) == 0L) return(matrix(0L, nrow(labels), ncol(labels)))
  lab[idx] <- idx
  big <- n + 1L
  offs <- .sg_offsets(connectivity)
  repeat {
    cur <- matrix(lab, nrow(labels), ncol(labels))
    cur[!pos] <- big
    best <- cur
    for (o in offs) {
      nb_val <- .sg_shift(labels, o[1], o[2], -1L)
      nb_lab <- .sg_shift(cur, o[1], o[2], big)
      nb_lab[nb_val != labels] <- big
      best <- pmin(best, nb_lab)
    }
    new <- as.vector(best)
    new[!pos] <- 0L
    for (k in 1:4) new[idx] <- new[new[idx]]
    if (identical(new, lab)) break
    lab <- new
  }
  matrix(lab, nrow(labels), ncol(labels))
}

#' Zero pixels of the higher label where two labels touch (4-neighbourhood)
#' @noRd
.sg_separate_touching <- function(labels) {
  out <- labels
  for (o in .sg_offsets(4L)) {
    nb <- .sg_shift(labels, o[1], o[2], 0L)
    touch <- labels > 0L & nb > 0L & nb < labels
    out[touch] <- 0L
  }
  out
}

#' Check a label matrix against a mask type
#' @return List with `ok`, `problems` (character), and summary counts.
#' @noRd
.sg_check_labels <- function(labels, mask_type = "instance",
                             connectivity = 4L, require_objects = FALSE) {
  problems <- character(0)
  if (!is.matrix(labels) || !is.numeric(labels)) {
    return(list(ok = FALSE, problems = "labels must be a numeric matrix",
                n_labels = NA_integer_))
  }
  if (anyNA(labels)) problems <- c(problems, "labels contain NA values")
  vals <- labels[!is.na(labels)]
  if (!is.integer(labels) && any(vals != trunc(vals))) {
    problems <- c(problems, "labels contain non-integer values")
  }
  if (any(vals < 0)) problems <- c(problems, "labels contain negative values")
  ids <- sort(unique(vals[vals > 0]))
  if (require_objects && length(ids) == 0L) {
    problems <- c(problems, "mask contains no objects")
  }
  if (mask_type == "binary" && any(!vals %in% c(0, 1))) {
    problems <- c(problems, "binary masks may only contain 0 and 1")
  }
  n_parts <- NA_integer_
  if (mask_type == "instance" && length(problems) == 0L && length(ids)) {
    li <- matrix(as.integer(labels), nrow(labels), ncol(labels))
    comp <- .sg_components_by_value(li, connectivity)
    pos <- li > 0L
    pairs <- unique(cbind(li[pos], comp[pos]))
    n_parts <- nrow(pairs)
    split_ids <- as.integer(names(which(table(pairs[, 1]) > 1L)))
    if (length(split_ids)) {
      problems <- c(problems, sprintf(
        "%d instance label(s) consist of several disconnected parts (e.g. %s)",
        length(split_ids), paste(utils::head(split_ids, 5L), collapse = ", ")
      ))
    }
  }
  list(ok = length(problems) == 0L, problems = problems,
       n_labels = length(ids), max_label = if (length(ids)) max(ids) else 0L,
       n_parts = n_parts)
}

#' Smallest unsigned integer dtype able to hold the labels
#' @noRd
.sg_label_dtype <- function(labels) {
  m <- if (length(labels)) max(labels, 0L, na.rm = TRUE) else 0L
  if (m <= 255) "uint8" else if (m <= 65535) "uint16" else "uint32"
}

#' Per-object measurements in the canonical long format
#'
#' @param labels Integer label matrix.
#' @param pixels Optional matrix or array `[y, x, channel]` for intensity.
#' @param channels Channel names for `pixels`.
#' @param origin List with `x`, `y`, `downsample`.
#' @param pixel_size List with `x`, `y` in um (NA if unknown).
#' @param which Measurement names to compute.
#' @return Wide tibble (one row per label).
#' @noRd
.sg_measure_labels <- function(labels, pixels = NULL, channels = NULL,
                               origin = list(x = 0, y = 0, downsample = 1),
                               pixel_size = list(x = NA_real_, y = NA_real_),
                               which = c("area", "centroid", "bbox",
                                         "mean_intensity")) {
  pos <- which(labels > 0L)
  if (length(pos) == 0L) {
    return(tibble::tibble(label = integer(0)))
  }
  nr <- nrow(labels)
  lab <- labels[pos]
  rows <- (pos - 1L) %% nr + 1L
  cols <- (pos - 1L) %/% nr + 1L
  ids <- sort(unique(lab))
  f <- factor(lab, levels = ids)
  ds <- origin$downsample %||% 1
  ox <- origin$x %||% 0
  oy <- origin$y %||% 0
  out <- tibble::tibble(label = as.integer(ids))
  area <- as.integer(tabulate(f, nbins = length(ids)))
  if ("area" %in% which) {
    out$area_px <- area * ds * ds
    if (is.finite(pixel_size$x %||% NA_real_) &&
        is.finite(pixel_size$y %||% NA_real_)) {
      out$area_um2 <- out$area_px * pixel_size$x * pixel_size$y
    }
  }
  if ("centroid" %in% which) {
    out$centroid_x_px <- ox + (as.numeric(tapply(cols, f, mean)) - 0.5) * ds
    out$centroid_y_px <- oy + (as.numeric(tapply(rows, f, mean)) - 0.5) * ds
  }
  if ("bbox" %in% which) {
    out$bbox_x_px <- ox + (as.numeric(tapply(cols, f, min)) - 1) * ds
    out$bbox_y_px <- oy + (as.numeric(tapply(rows, f, min)) - 1) * ds
    out$bbox_width_px <- (as.numeric(tapply(cols, f, max)) -
                            as.numeric(tapply(cols, f, min)) + 1) * ds
    out$bbox_height_px <- (as.numeric(tapply(rows, f, max)) -
                             as.numeric(tapply(rows, f, min)) + 1) * ds
  }
  if ("mean_intensity" %in% which && !is.null(pixels)) {
    if (length(dim(pixels)) == 2L) {
      pixels <- array(pixels, dim = c(dim(pixels), 1L))
    }
    n_ch <- dim(pixels)[3]
    if (is.null(channels) || length(channels) != n_ch) {
      channels <- paste0("ch", seq_len(n_ch))
    }
    for (k in seq_len(n_ch)) {
      v <- pixels[, , k][pos]
      out[[paste0("mean_intensity_", channels[k])]] <-
        as.numeric(tapply(v, f, mean))
    }
  }
  out
}

#' Convert wide measurements to the canonical long format
#' @noRd
.sg_measurements_long <- function(wide, image_id = NA_character_,
                                  object_ids = NULL, provider = "segmantR",
                                  namespace = "derived") {
  if (nrow(wide) == 0L) {
    return(tibble::tibble(
      image_id = character(0), object_id = character(0), label = integer(0),
      name = character(0), namespace = character(0), value = numeric(0),
      value_state = character(0), unit = character(0),
      provider_id = character(0)
    ))
  }
  cols <- setdiff(names(wide), "label")
  unit_of <- function(nm) {
    if (grepl("_um2$", nm)) "um^2" else if (grepl("_px$", nm)) "px" else
      if (grepl("^mean_intensity_", nm)) "intensity" else "unknown"
  }
  oid <- object_ids %||% rep(NA_character_, nrow(wide))
  rows <- lapply(cols, function(nm) {
    v <- as.numeric(wide[[nm]])
    tibble::tibble(
      image_id = image_id,
      object_id = oid,
      label = wide$label,
      name = nm,
      namespace = namespace,
      value = ifelse(is.finite(v), v, NA_real_),
      value_state = .sg_value_state(v),
      unit = unit_of(nm),
      provider_id = provider
    )
  })
  do.call(rbind, rows)
}

#' Classify numeric values into value_state
#' @noRd
.sg_value_state <- function(v) {
  ifelse(is.nan(v), "nan",
         ifelse(is.na(v), "missing",
                ifelse(v == Inf, "pos_inf",
                       ifelse(v == -Inf, "neg_inf", "finite"))))
}

#' Restore numeric values from value and value_state columns
#' @noRd
.sg_value_from_state <- function(value, state) {
  out <- suppressWarnings(as.numeric(value))
  out[state == "missing"] <- NA_real_
  out[state == "nan"] <- NaN
  out[state == "pos_inf"] <- Inf
  out[state == "neg_inf"] <- -Inf
  out
}
