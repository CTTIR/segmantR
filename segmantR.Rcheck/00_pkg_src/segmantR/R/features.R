# Per-cell feature extraction

#' Extract per-cell features from an image and mask
#'
#' Computes intensity, morphology, texture, and location features for each
#' segmented cell. Returns a tibble with one row per cell.
#'
#' @param image An `sg_image` object.
#' @param mask An `sg_mask` object with labels matching the image dimensions.
#' @param features Character vector of feature groups to compute. One or more
#'   of `"intensity"`, `"morphology"`, `"texture"`, `"location"`. Default is
#'   all four.
#' @param channels Integer or character vector selecting which image channels
#'   to use for intensity and texture features. `NULL` (default) uses all
#'   channels.
#'
#' @return A tibble with one row per cell and a `cell_id` column, plus columns
#'   for each requested feature.
#' @export
#' @examples
#' pixels <- array(runif(20 * 20 * 2), dim = c(20, 20, 2))
#' img <- new_sg_image(pixels, channels = c("DAPI", "CD3"))
#' labels <- matrix(0L, nrow = 20, ncol = 20)
#' labels[3:8, 3:8] <- 1L
#' labels[12:18, 12:18] <- 2L
#' mask <- new_sg_mask(labels)
#' feats <- sg_extract_features(img, mask, features = c("intensity", "morphology"))
#' print(feats)
sg_extract_features <- function(image, mask,
                                features = c("intensity", "morphology",
                                             "texture", "location"),
                                channels = NULL) {
  if (!inherits(image, "sg_image")) {
    cli::cli_abort("{.arg image} must be an {.cls sg_image} object.")
  }
  if (!inherits(mask, "sg_mask")) {
    cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object.")
  }
  features <- match.arg(features, c("intensity", "morphology", "texture",
                                     "location"),
                        several.ok = TRUE)

  pixels <- image$pixels
  labels <- mask$labels

  # Ensure 3D array

  if (length(dim(pixels)) == 2L) {
    pixels <- array(pixels, dim = c(dim(pixels), 1L))
  }

  # Validate dimensions
  if (nrow(labels) != dim(pixels)[1] || ncol(labels) != dim(pixels)[2]) {
    cli::cli_abort("Image and mask dimensions do not match.")
  }

  n_ch <- dim(pixels)[3]
  ch_names <- image$channels
  if (length(ch_names) != n_ch) {
    ch_names <- paste0("ch", seq_len(n_ch))
  }

  # Resolve channel selection
  if (!is.null(channels)) {
    if (is.character(channels)) {
      ch_idx <- match(channels, ch_names)
      if (any(is.na(ch_idx))) {
        cli::cli_abort("Channel{?s} not found: {.val {channels[is.na(ch_idx)]}}")
      }
    } else {
      ch_idx <- as.integer(channels)
    }
    ch_names <- ch_names[ch_idx]
  } else {
    ch_idx <- seq_len(n_ch)
  }

  cell_ids <- seq_len(mask$n_cells)
  if (length(cell_ids) == 0L) {
    cli::cli_inform("Mask contains no cells. Returning empty tibble.")
    return(tibble::tibble(cell_id = integer(0)))
  }

  result_list <- lapply(cell_ids, function(cid) {
    row <- tibble::tibble(cell_id = cid)

    if ("intensity" %in% features) {
      for (ci in seq_along(ch_idx)) {
        ch <- ch_idx[ci]
        cname <- ch_names[ci]
        cell_vals <- pixels[, , ch][labels == cid]
        row[[paste0(cname, "_mean")]] <- mean(cell_vals, na.rm = TRUE)
        row[[paste0(cname, "_sd")]] <- stats::sd(cell_vals, na.rm = TRUE)
        row[[paste0(cname, "_median")]] <- stats::median(cell_vals,
                                                          na.rm = TRUE)
        row[[paste0(cname, "_min")]] <- min(cell_vals, na.rm = TRUE)
        row[[paste0(cname, "_max")]] <- max(cell_vals, na.rm = TRUE)
        row[[paste0(cname, "_q25")]] <- stats::quantile(cell_vals, 0.25,
                                                         na.rm = TRUE,
                                                         names = FALSE)
        row[[paste0(cname, "_q75")]] <- stats::quantile(cell_vals, 0.75,
                                                         na.rm = TRUE,
                                                         names = FALSE)
      }
    }

    if ("morphology" %in% features) {
      morph <- .compute_morphology(labels, cid)
      row[["area"]] <- morph$area
      row[["perimeter"]] <- morph$perimeter
      row[["circularity"]] <- morph$circularity
      row[["eccentricity"]] <- morph$eccentricity
      row[["solidity"]] <- morph$solidity
    }

    if ("texture" %in% features) {
      for (ci in seq_along(ch_idx)) {
        ch <- ch_idx[ci]
        cname <- ch_names[ci]
        cell_vals <- pixels[, , ch][labels == cid]
        # Simple texture features: entropy and contrast proxy
        if (length(cell_vals) > 1L) {
          p <- table(round(cell_vals, 2)) / length(cell_vals)
          p <- as.numeric(p)
          p <- p[p > 0]
          entropy <- -sum(p * log2(p))
          row[[paste0(cname, "_entropy")]] <- entropy
          row[[paste0(cname, "_iqr")]] <- stats::IQR(cell_vals, na.rm = TRUE)
        } else {
          row[[paste0(cname, "_entropy")]] <- 0
          row[[paste0(cname, "_iqr")]] <- 0
        }
      }
    }

    if ("location" %in% features) {
      cell_pixels <- which(labels == cid, arr.ind = TRUE)
      row[["centroid_row"]] <- mean(cell_pixels[, 1])
      row[["centroid_col"]] <- mean(cell_pixels[, 2])
    }

    row
  })

  result <- do.call(rbind, result_list)

  cli::cli_inform(c(
    "v" = "Extracted {paste(features, collapse = ', ')} features for {length(cell_ids)} cell{?s}."
  ))
  result
}
