# Internal utility functions for segmantR
# None of these are exported

#' Null-coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Check if Cellpose is available
#' @noRd
.check_cellpose <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(c(
      "Cellpose segmentation requires the {.pkg reticulate} package.",
      "i" = "Install with: {.code install.packages('reticulate')}"
    ))
  }
  if (!reticulate::py_module_available("cellpose")) {
    cli::cli_abort(c(
      "Cellpose Python module not found.",
      "i" = "Run {.code sg_setup_python(backends = 'cellpose')} to install."
    ))
  }
  invisible(TRUE)
}

#' Check if StarDist is available
#' @noRd
.check_stardist <- function() {

  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(c(
      "StarDist segmentation requires the {.pkg reticulate} package.",
      "i" = "Install with: {.code install.packages('reticulate')}"
    ))
  }
  if (!reticulate::py_module_available("stardist")) {
    cli::cli_abort(c(
      "StarDist Python module not found.",
      "i" = "Run {.code sg_setup_python(backends = 'stardist')} to install."
    ))
  }
  invisible(TRUE)
}

#' Check if Mesmer/DeepCell is available
#' @noRd
.check_mesmer <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(c(
      "Mesmer segmentation requires the {.pkg reticulate} package.",
      "i" = "Install with: {.code install.packages('reticulate')}"
    ))
  }
  if (!reticulate::py_module_available("deepcell")) {
    cli::cli_abort(c(
      "DeepCell Python module not found.",
      "i" = "Install with: {.code pip install deepcell} in your Python environment."
    ))
  }
  invisible(TRUE)
}

#' Check if EBImage is available
#' @noRd
.check_ebimage <- function() {
  if (!requireNamespace("EBImage", quietly = TRUE)) {
    return(FALSE)
  }

  TRUE
}

#' Adaptive threshold on a single-channel image
#' @param channel Numeric matrix (single channel).
#' @param block_size Integer, must be odd.
#' @param offset Numeric offset subtracted from local mean.
#' @return Binary matrix (0/1).
#' @noRd
.adaptive_threshold <- function(channel, block_size = 51L, offset = 0.05) {
  nr <- nrow(channel)
  nc <- ncol(channel)
  block_size <- as.integer(block_size)
  if (block_size %% 2L == 0L) block_size <- block_size + 1L
  half <- block_size %/% 2L
  padded <- matrix(0, nrow = nr + 2L * half, ncol = nc + 2L * half)
  padded[(half + 1L):(half + nr), (half + 1L):(half + nc)] <- channel
  cum <- .cumsum2d(padded)
  local_mean <- matrix(0, nrow = nr, ncol = nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      r1 <- i
      c1 <- j
      r2 <- i + 2L * half
      c2 <- j + 2L * half
      total <- cum[r2, c2] - cum[r1 - 1L, c2] - cum[r2, c1 - 1L] + cum[r1 - 1L, c1 - 1L]
      local_mean[i, j] <- total / (block_size * block_size)
    }
  }
  result <- ifelse(channel > local_mean - offset, 1L, 0L)
  result
}

#' 2D cumulative sum (integral image)
#' @noRd
.cumsum2d <- function(mat) {
  nr <- nrow(mat)
  nc <- ncol(mat)
  cum <- matrix(0, nrow = nr, ncol = nc)
  for (i in seq_len(nr)) {
    row_sum <- 0
    for (j in seq_len(nc)) {
      row_sum <- row_sum + mat[i, j]
      cum[i, j] <- row_sum
      if (i > 1L) cum[i, j] <- cum[i, j] + cum[i - 1L, j]
    }
  }
  cum
}

#' Otsu thresholding
#' @noRd
.otsu_threshold <- function(channel) {
  vals <- as.vector(channel)
  vals <- vals[is.finite(vals)]
  breaks <- seq(min(vals), max(vals), length.out = 257L)
  h <- graphics::hist(vals, breaks = breaks, plot = FALSE)
  counts <- h$counts
  mids <- h$mids
  total <- sum(counts)
  if (total == 0) return(stats::median(vals))
  sum_all <- sum(counts * mids)
  sum_bg <- 0
  w_bg <- 0
  best_var <- -Inf
  best_thresh <- mids[1]
  for (i in seq_along(counts)) {
    w_bg <- w_bg + counts[i]
    if (w_bg == 0) next
    w_fg <- total - w_bg
    if (w_fg == 0) break
    sum_bg <- sum_bg + counts[i] * mids[i]
    mean_bg <- sum_bg / w_bg
    mean_fg <- (sum_all - sum_bg) / w_fg
    between_var <- w_bg * w_fg * (mean_bg - mean_fg)^2
    if (between_var > best_var) {
      best_var <- between_var
      best_thresh <- mids[i]
    }
  }
  best_thresh
}

#' Triangle thresholding
#' @noRd
.triangle_threshold <- function(channel) {
  vals <- as.vector(channel)
  vals <- vals[is.finite(vals)]
  breaks <- seq(min(vals), max(vals), length.out = 257L)
  h <- graphics::hist(vals, breaks = breaks, plot = FALSE)
  counts <- h$counts
  mids <- h$mids
  peak_idx <- which.max(counts)
  if (peak_idx <= length(counts) / 2) {
    end_idx <- length(counts)
  } else {
    end_idx <- 1L
  }
  x1 <- mids[peak_idx]
  y1 <- counts[peak_idx]
  x2 <- mids[end_idx]
  y2 <- counts[end_idx]
  len <- sqrt((x2 - x1)^2 + (y2 - y1)^2)
  if (len == 0) return(stats::median(vals))
  best_dist <- -Inf
  best_idx <- peak_idx
  idx_range <- if (peak_idx < end_idx) seq(peak_idx, end_idx) else seq(end_idx, peak_idx)
  for (i in idx_range) {
    dist <- abs((y2 - y1) * mids[i] - (x2 - x1) * counts[i] + x2 * y1 - y2 * x1) / len
    if (dist > best_dist) {
      best_dist <- dist
      best_idx <- i
    }
  }
  mids[best_idx]
}

#' Morphological cleanup operations
#' @noRd
.morphological_cleanup <- function(binary, open_size = 5L, fill_holes = TRUE) {
  result <- binary
  if (open_size > 0L) {
    result <- .morpho_erode(result, open_size)
    result <- .morpho_dilate(result, open_size)
  }
  if (fill_holes) {
    result <- .fill_holes(result)
  }
  result
}

#' Simple morphological erosion
#' @noRd
.morpho_erode <- function(binary, size = 3L) {
  half <- size %/% 2L
  nr <- nrow(binary)
  nc <- ncol(binary)
  result <- matrix(0L, nrow = nr, ncol = nc)
  for (i in (half + 1L):(nr - half)) {
    for (j in (half + 1L):(nc - half)) {
      patch <- binary[(i - half):(i + half), (j - half):(j + half)]
      if (all(patch == 1L)) result[i, j] <- 1L
    }
  }
  result
}

#' Simple morphological dilation
#' @noRd
.morpho_dilate <- function(binary, size = 3L) {
  half <- size %/% 2L
  nr <- nrow(binary)
  nc <- ncol(binary)
  result <- matrix(0L, nrow = nr, ncol = nc)
  for (i in (half + 1L):(nr - half)) {
    for (j in (half + 1L):(nc - half)) {
      patch <- binary[(i - half):(i + half), (j - half):(j + half)]
      if (any(patch == 1L)) result[i, j] <- 1L
    }
  }
  result
}

#' Fill holes in binary image
#' @noRd
.fill_holes <- function(binary) {
  nr <- nrow(binary)
  nc <- ncol(binary)
  filled <- matrix(1L, nrow = nr, ncol = nc)
  visited <- matrix(FALSE, nrow = nr, ncol = nc)
  queue <- list()
  for (i in c(1L, nr)) {
    for (j in seq_len(nc)) {
      if (binary[i, j] == 0L) {
        queue <- c(queue, list(c(i, j)))
        visited[i, j] <- TRUE
      }
    }
  }
  for (j in c(1L, nc)) {
    for (i in seq_len(nr)) {
      if (binary[i, j] == 0L && !visited[i, j]) {
        queue <- c(queue, list(c(i, j)))
        visited[i, j] <- TRUE
      }
    }
  }
  while (length(queue) > 0L) {
    pt <- queue[[1L]]
    queue <- queue[-1L]
    r <- pt[1]
    cc <- pt[2]
    filled[r, cc] <- 0L
    neighbors <- list(c(r - 1L, cc), c(r + 1L, cc), c(r, cc - 1L), c(r, cc + 1L))
    for (nb in neighbors) {
      ni <- nb[1]
      nj <- nb[2]
      if (ni >= 1L && ni <= nr && nj >= 1L && nj <= nc &&
          !visited[ni, nj] && binary[ni, nj] == 0L) {
        visited[ni, nj] <- TRUE
        queue <- c(queue, list(c(ni, nj)))
      }
    }
  }
  filled
}

#' Connected component labeling
#' @noRd
.connected_components <- function(binary) {
  nr <- nrow(binary)
  nc <- ncol(binary)
  labels <- matrix(0L, nrow = nr, ncol = nc)
  current_label <- 0L
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      if (binary[i, j] == 1L && labels[i, j] == 0L) {
        current_label <- current_label + 1L
        queue <- list(c(i, j))
        labels[i, j] <- current_label
        while (length(queue) > 0L) {
          pt <- queue[[1L]]
          queue <- queue[-1L]
          r <- pt[1]
          cc <- pt[2]
          neighbors <- list(c(r - 1L, cc), c(r + 1L, cc), c(r, cc - 1L), c(r, cc + 1L))
          for (nb in neighbors) {
            ni <- nb[1]
            nj <- nb[2]
            if (ni >= 1L && ni <= nr && nj >= 1L && nj <= nc &&
                binary[ni, nj] == 1L && labels[ni, nj] == 0L) {
              labels[ni, nj] <- current_label
              queue <- c(queue, list(c(ni, nj)))
            }
          }
        }
      }
    }
  }
  labels
}

#' Watershed seeds from distance transform
#' @noRd
.watershed_seeds <- function(channel, method = "distance", h = 0.05,
                             min_distance = 10L) {
  method <- match.arg(method, c("h_minima", "distance", "markers"))
  binary <- ifelse(channel > .otsu_threshold(channel), 1L, 0L)
  dt <- .distance_transform(binary)
  if (method == "distance") {
    threshold <- max(dt) * h
    seeds <- ifelse(dt > threshold, 1L, 0L)
    seeds <- .connected_components(seeds)
  } else {
    seeds <- .connected_components(ifelse(dt > max(dt) * h, 1L, 0L))
  }
  seeds
}

#' Simple distance transform (Chamfer 3-4)
#' @noRd
.distance_transform <- function(binary) {
  nr <- nrow(binary)
  nc <- ncol(binary)
  dt <- matrix(Inf, nrow = nr, ncol = nc)
  dt[binary == 1L] <- 0
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      if (i > 1L) dt[i, j] <- min(dt[i, j], dt[i - 1L, j] + 1)
      if (j > 1L) dt[i, j] <- min(dt[i, j], dt[i, j - 1L] + 1)
    }
  }
  for (i in rev(seq_len(nr))) {
    for (j in rev(seq_len(nc))) {
      if (i < nr) dt[i, j] <- min(dt[i, j], dt[i + 1L, j] + 1)
      if (j < nc) dt[i, j] <- min(dt[i, j], dt[i, j + 1L] + 1)
    }
  }
  max_val <- max(dt[is.finite(dt)])
  dt[!is.finite(dt)] <- max_val + 1
  max_val + 1 - dt
}

#' Pure-R Voronoi propagation
#' @noRd
.voronoi_propagate_r <- function(seeds, mask = NULL, expand_max = 20L) {
  nr <- nrow(seeds)
  nc <- ncol(seeds)
  result <- seeds
  changed <- TRUE
  iter <- 0L
  while (changed && iter < expand_max) {
    changed <- FALSE
    iter <- iter + 1L
    new_result <- result
    for (i in seq_len(nr)) {
      for (j in seq_len(nc)) {
        if (result[i, j] != 0L) next
        if (!is.null(mask) && mask[i, j] == 0L) next
        neighbors <- integer(0)
        if (i > 1L && result[i - 1L, j] > 0L) neighbors <- c(neighbors, result[i - 1L, j])
        if (i < nr && result[i + 1L, j] > 0L) neighbors <- c(neighbors, result[i + 1L, j])
        if (j > 1L && result[i, j - 1L] > 0L) neighbors <- c(neighbors, result[i, j - 1L])
        if (j < nc && result[i, j + 1L] > 0L) neighbors <- c(neighbors, result[i, j + 1L])
        if (length(neighbors) > 0L) {
          tbl <- table(neighbors)
          new_result[i, j] <- as.integer(names(tbl)[which.max(tbl)])
          changed <- TRUE
        }
      }
    }
    result <- new_result
  }
  result
}

#' Convert Cellpose numpy array to R matrix
#' @noRd
.cellpose_array_to_r <- function(np_array) {
  arr <- reticulate::py_to_r(np_array)
  if (length(dim(arr)) == 2L) {
    return(as.integer(arr))
  }
  as.integer(arr)
}

#' Convert R array to Cellpose numpy format
#' @noRd
.r_array_to_cellpose <- function(image) {
  pixels <- image$pixels
  if (length(dim(pixels)) == 2L) {
    pixels <- array(pixels, dim = c(dim(pixels), 1L))
  }
  np <- reticulate::import("numpy", convert = FALSE)
  np_array <- np$array(pixels, dtype = np$float32)
  np_array <- np_array$transpose(as.integer(c(2, 0, 1)))
  np_array
}

#' Convert Cellpose mask to sg_mask
#' @noRd
.cellpose_mask_to_sg <- function(np_mask, model_info = list()) {
  mask_r <- .cellpose_array_to_r(np_mask)
  dim(mask_r) <- dim(reticulate::py_to_r(np_mask))
  new_sg_mask(mask_r, model_info = model_info)
}

#' Convert StarDist output to sg_mask
#' @noRd
.stardist_to_sg <- function(labels, details = NULL, model_info = list()) {
  mask_r <- as.integer(reticulate::py_to_r(labels))
  dim(mask_r) <- dim(reticulate::py_to_r(labels))
  mi <- model_info
  if (!is.null(details)) {
    mi$details <- reticulate::py_to_r(details)
  }
  new_sg_mask(mask_r, model_info = mi)
}

#' Compute basic morphology features for a single cell
#' @noRd
.compute_morphology <- function(mask_labels, cell_id) {
  cell_pixels <- which(mask_labels == cell_id, arr.ind = TRUE)
  if (nrow(cell_pixels) == 0L) {
    return(tibble::tibble(
      area = 0L,
      perimeter = 0,
      circularity = NA_real_,
      eccentricity = NA_real_,
      solidity = NA_real_,
      centroid_row = NA_real_,
      centroid_col = NA_real_,
      bbox_row_min = NA_integer_,
      bbox_row_max = NA_integer_,
      bbox_col_min = NA_integer_,
      bbox_col_max = NA_integer_
    ))
  }
  area <- nrow(cell_pixels)
  centroid_row <- mean(cell_pixels[, 1])
  centroid_col <- mean(cell_pixels[, 2])
  bbox_row_min <- min(cell_pixels[, 1])
  bbox_row_max <- max(cell_pixels[, 1])
  bbox_col_min <- min(cell_pixels[, 2])

  bbox_col_max <- max(cell_pixels[, 2])

  perim <- .estimate_perimeter(mask_labels, cell_id)
  circ <- if (perim > 0) 4 * pi * area / (perim^2) else NA_real_

  cov_mat <- stats::cov(cell_pixels)
  eigenvals <- eigen(cov_mat, symmetric = TRUE)$values
  ecc <- if (all(eigenvals > 0)) {
    sqrt(1 - min(eigenvals) / max(eigenvals))
  } else {
    NA_real_
  }

  hull_area <- .convex_hull_area(cell_pixels)
  solid <- if (hull_area > 0) area / hull_area else NA_real_

  tibble::tibble(
    area = area,
    perimeter = perim,
    circularity = circ,
    eccentricity = ecc,
    solidity = solid,
    centroid_row = centroid_row,
    centroid_col = centroid_col,
    bbox_row_min = bbox_row_min,
    bbox_row_max = bbox_row_max,
    bbox_col_min = bbox_col_min,
    bbox_col_max = bbox_col_max
  )
}

#' Estimate perimeter of a labeled region
#' @noRd
.estimate_perimeter <- function(mask_labels, cell_id) {
  nr <- nrow(mask_labels)
  nc <- ncol(mask_labels)
  perim <- 0L
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      if (mask_labels[i, j] != cell_id) next
      is_border <- FALSE
      if (i == 1L || i == nr || j == 1L || j == nc) {
        is_border <- TRUE
      } else {
        if (mask_labels[i - 1L, j] != cell_id) is_border <- TRUE
        if (mask_labels[i + 1L, j] != cell_id) is_border <- TRUE
        if (mask_labels[i, j - 1L] != cell_id) is_border <- TRUE
        if (mask_labels[i, j + 1L] != cell_id) is_border <- TRUE
      }
      if (is_border) perim <- perim + 1L
    }
  }
  as.numeric(perim)
}

#' Convex hull area approximation
#' @noRd
.convex_hull_area <- function(pts) {
  if (nrow(pts) < 3L) return(nrow(pts))
  hull_idx <- grDevices::chull(pts[, 1], pts[, 2])
  hull_pts <- pts[hull_idx, , drop = FALSE]
  n <- nrow(hull_pts)
  area <- 0
  for (i in seq_len(n)) {
    j <- if (i == n) 1L else i + 1L
    area <- area + hull_pts[i, 1] * hull_pts[j, 2]
    area <- area - hull_pts[j, 1] * hull_pts[i, 2]
  }
  abs(area) / 2
}

#' Uncertainty score for active learning
#' @noRd
.uncertainty_score <- function(mask, image) {
  nr <- nrow(mask$labels)
  nc <- ncol(mask$labels)
  n_cells <- mask$n_cells
  if (n_cells == 0L) return(0)
  border_count <- 0L
  total <- 0L
  for (i in 2L:(nr - 1L)) {
    for (j in 2L:(nc - 1L)) {
      if (mask$labels[i, j] > 0L) {
        total <- total + 1L
        neighbors <- c(
          mask$labels[i - 1L, j], mask$labels[i + 1L, j],
          mask$labels[i, j - 1L], mask$labels[i, j + 1L]
        )
        if (any(neighbors != mask$labels[i, j])) border_count <- border_count + 1L
      }
    }
  }
  if (total == 0L) return(0)
  border_count / total
}

#' Patch sampler for informative patches
#' @noRd
.patch_sampler <- function(image, mask = NULL, n = 20L, size = 256L,
                           strategy = "grid") {
  nr <- nrow(image$pixels)
  nc <- ncol(image$pixels)
  if (length(dim(image$pixels)) == 3L) {
    nr <- dim(image$pixels)[1]
    nc <- dim(image$pixels)[2]
  }
  max_row <- max(1L, nr - size + 1L)
  max_col <- max(1L, nc - size + 1L)
  if (strategy == "grid") {
    rows_n <- ceiling(sqrt(n * nr / nc))
    cols_n <- ceiling(n / rows_n)
    row_starts <- round(seq(1, max_row, length.out = min(rows_n, max_row)))
    col_starts <- round(seq(1, max_col, length.out = min(cols_n, max_col)))
    grid <- expand.grid(row = row_starts, col = col_starts)
    if (nrow(grid) > n) grid <- grid[seq_len(n), ]
  } else {
    grid <- data.frame(
      row = sample.int(max_row, min(n, max_row), replace = n > max_row),
      col = sample.int(max_col, min(n, max_col), replace = n > max_col)
    )
  }
  patches <- lapply(seq_len(nrow(grid)), function(k) {
    r <- grid$row[k]
    cc <- grid$col[k]
    list(
      row_start = r, col_start = cc,
      row_end = min(r + size - 1L, nr),
      col_end = min(cc + size - 1L, nc)
    )
  })
  patches
}

#' Parse Shiny corrections into mask operations
#' @noRd
.corrections_to_mask_ops <- function(corrections) {
  if (!is.list(corrections)) {
    cli::cli_abort("{.arg corrections} must be a list of correction operations.")
  }
  corrections
}

#' Export mask as training pair for Cellpose
#' @noRd
.mask_to_training_pair <- function(image, mask, patch_size = 256L) {
  list(image = image, mask = mask, patch_size = patch_size)
}

# Global variables to avoid R CMD check NOTEs for tidy eval
utils::globalVariables(c(
  "cell_id", "metric", "value", "method", "n_cells",
  ".data", "channel", "x", "y", "label", "row", "col",
  "area", "mean_intensity", "name", "description",
  "fill_value", "panel"
))
