# Mask operations: filtering, merging, polygon conversion, export

#' Filter cells by morphological criteria
#'
#' Removes cells from a segmentation mask that fall outside specified
#' morphological thresholds. Useful for quality control after initial
#' segmentation.
#'
#' @param mask An `sg_mask` object.
#' @param min_area Integer. Minimum cell area in pixels. Default `50L`.
#' @param max_area Integer. Maximum cell area in pixels. Default `5000L`.
#' @param min_circularity Numeric in \[0, 1\]. Minimum circularity
#'   (4 * pi * area / perimeter^2). Default `0.3`.
#' @param max_eccentricity Numeric in \[0, 1\]. Maximum eccentricity.
#'   Default `0.95`.
#' @param border_cells Character. How to handle cells touching the image
#'   border: `"keep"` (default), `"remove"`, or `"flag"`.
#'
#' @return A filtered `sg_mask` object. When `border_cells = "flag"`, the
#'   returned mask has an additional `border_cell_ids` element.
#' @export
#' @examples
#' labels <- matrix(0L, nrow = 20, ncol = 20)
#' labels[3:8, 3:8] <- 1L
#' labels[12:18, 12:18] <- 2L
#' mask <- new_sg_mask(labels)
#' filtered <- sg_filter_cells(mask, min_area = 10L, max_area = 100L)
#' print(filtered)
sg_filter_cells <- function(mask, min_area = 50L, max_area = 5000L,
                            min_circularity = 0.3, max_eccentricity = 0.95,
                            border_cells = c("keep", "remove", "flag")) {
  if (!inherits(mask, "sg_mask")) {
    cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object.")
  }
  border_cells <- match.arg(border_cells)
  min_area <- as.integer(min_area)
  max_area <- as.integer(max_area)

  labels <- mask$labels
  cell_ids <- seq_len(mask$n_cells)
  if (length(cell_ids) == 0L) {
    return(mask)
  }

  nr <- nrow(labels)
  nc <- ncol(labels)

  # Identify border cells
  border_ids <- integer(0)
  if (border_cells != "keep") {
    edge_vals <- unique(c(
      labels[1L, ], labels[nr, ],
      labels[, 1L], labels[, nc]
    ))
    border_ids <- edge_vals[edge_vals > 0L]
  }

  keep_ids <- integer(0)
  flagged_ids <- integer(0)


  for (cid in cell_ids) {
    morph <- .compute_morphology(labels, cid)
    if (morph$area == 0L) next

    passes <- morph$area >= min_area &&
      morph$area <= max_area &&
      (is.na(morph$circularity) || morph$circularity >= min_circularity) &&
      (is.na(morph$eccentricity) || morph$eccentricity <= max_eccentricity)

    is_border <- cid %in% border_ids

    if (border_cells == "remove" && is_border) {
      next
    }
    if (border_cells == "flag" && is_border) {
      flagged_ids <- c(flagged_ids, cid)
    }

    if (passes) {
      keep_ids <- c(keep_ids, cid)
    }
  }

  # Relabel
  new_labels <- matrix(0L, nrow = nr, ncol = nc)
  new_id <- 0L
  for (cid in keep_ids) {
    new_id <- new_id + 1L
    new_labels[labels == cid] <- new_id
  }

  n_removed <- length(cell_ids) - length(keep_ids)
  cli::cli_inform(c(
    "v" = "Kept {length(keep_ids)} of {length(cell_ids)} cell{?s}.",
    "i" = "Removed {n_removed} cell{?s} by morphological filtering."
  ))

  result <- new_sg_mask(new_labels, image_id = mask$image_id,
                        model_info = mask$model_info)
  if (border_cells == "flag") {
    result$border_cell_ids <- flagged_ids
  }
  result
}

#' Merge nuclear and cell body masks
#'
#' Combines a nuclear segmentation mask with a cell body segmentation mask
#' to produce paired nuclear-cell assignments.
#'
#' @param nuclear_mask An `sg_mask` object for nuclei.
#' @param cell_mask An `sg_mask` object for cell bodies.
#' @param method Character. `"assign"` (default) assigns nuclei to overlapping
#'   cells; `"expand"` expands nuclear labels outward to fill cell boundaries.
#'
#' @return A list with elements `$nuclear` and `$cell`, both `sg_mask` objects
#'   with matched cell IDs.
#' @export
#' @examples
#' nuc_labels <- matrix(0L, nrow = 20, ncol = 20)
#' nuc_labels[5:7, 5:7] <- 1L
#' nuc_labels[14:16, 14:16] <- 2L
#' cell_labels <- matrix(0L, nrow = 20, ncol = 20)
#' cell_labels[3:9, 3:9] <- 1L
#' cell_labels[12:18, 12:18] <- 2L
#' nuc_mask <- new_sg_mask(nuc_labels)
#' cell_mask <- new_sg_mask(cell_labels)
#' merged <- sg_merge_masks(nuc_mask, cell_mask)
#' print(merged$nuclear)
sg_merge_masks <- function(nuclear_mask, cell_mask,
                           method = c("assign", "expand")) {
  if (!inherits(nuclear_mask, "sg_mask")) {
    cli::cli_abort("{.arg nuclear_mask} must be an {.cls sg_mask} object.")
  }
  if (!inherits(cell_mask, "sg_mask")) {
    cli::cli_abort("{.arg cell_mask} must be an {.cls sg_mask} object.")
  }
  method <- match.arg(method)

  nuc_lab <- nuclear_mask$labels
  cell_lab <- cell_mask$labels

  if (!identical(dim(nuc_lab), dim(cell_lab))) {
    cli::cli_abort("Nuclear and cell masks must have the same dimensions.")
  }

  if (method == "assign") {
    # For each nucleus, find the most common overlapping cell label
    nuc_ids <- seq_len(nuclear_mask$n_cells)
    mapping <- vapply(nuc_ids, function(nid) {
      overlap <- cell_lab[nuc_lab == nid]
      overlap <- overlap[overlap > 0L]
      if (length(overlap) == 0L) return(0L)
      tbl <- table(overlap)
      as.integer(names(tbl)[which.max(tbl)])
    }, integer(1))

    # Relabel nuclei to match cell IDs
    new_nuc <- matrix(0L, nrow = nrow(nuc_lab), ncol = ncol(nuc_lab))
    for (i in seq_along(nuc_ids)) {
      if (mapping[i] > 0L) {
        new_nuc[nuc_lab == nuc_ids[i]] <- mapping[i]
      }
    }
    result_nuc <- new_sg_mask(new_nuc, image_id = nuclear_mask$image_id,
                              model_info = nuclear_mask$model_info)
    result_cell <- cell_mask

  } else {
    # Expand: use nuclear labels as seeds and expand into cell mask
    expanded <- .voronoi_propagate_r(
      seeds = nuc_lab,
      mask = ifelse(cell_lab > 0L, 1L, 0L),
      expand_max = max(dim(nuc_lab))
    )
    result_nuc <- nuclear_mask
    result_cell <- new_sg_mask(expanded, image_id = cell_mask$image_id,
                               model_info = cell_mask$model_info)
  }

  cli::cli_inform(c(
    "v" = "Merged nuclear ({nuclear_mask$n_cells} nuclei) and cell ({cell_mask$n_cells} cells) masks.",
    "i" = "Method: {.val {method}}"
  ))

  list(nuclear = result_nuc, cell = result_cell)
}

#' Convert mask to polygon geometries
#'
#' Extracts cell boundaries from a label mask and returns them as polygon
#' geometries. If the \pkg{sf} package is available, returns an `sf` data
#' frame; otherwise returns a tibble of boundary coordinates.
#'
#' @param mask An `sg_mask` object.
#' @param simplify Logical. Simplify polygon geometries? Default `TRUE`.
#' @param tolerance Numeric. Simplification tolerance in pixels when
#'   `simplify = TRUE`. Default `1.0`.
#'
#' @return An `sf` data frame with one row per cell (columns `cell_id` and
#'   `geometry`) when \pkg{sf} is available, or a tibble with columns
#'   `cell_id`, `row`, `col` listing boundary coordinates.
#' @export
#' @examples
#' labels <- matrix(0L, nrow = 20, ncol = 20)
#' labels[3:8, 3:8] <- 1L
#' labels[12:18, 12:18] <- 2L
#' mask <- new_sg_mask(labels)
#' polys <- sg_mask_to_polygons(mask, simplify = FALSE)
#' head(polys)
sg_mask_to_polygons <- function(mask, simplify = TRUE, tolerance = 1.0) {
  if (!inherits(mask, "sg_mask")) {
    cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object.")
  }

  labels <- mask$labels
  cell_ids <- seq_len(mask$n_cells)
  if (length(cell_ids) == 0L) {
    cli::cli_inform("Mask contains no cells.")
    return(tibble::tibble(cell_id = integer(0), row = numeric(0),
                          col = numeric(0)))
  }

  use_sf <- requireNamespace("sf", quietly = TRUE)

  if (use_sf) {
    polys <- lapply(cell_ids, function(cid) {
      coords <- which(labels == cid, arr.ind = TRUE)
      if (nrow(coords) < 3L) return(NULL)
      hull_idx <- grDevices::chull(coords[, 2], coords[, 1])
      hull_coords <- coords[hull_idx, , drop = FALSE]
      # sf polygon: close ring, x = col, y = row
      ring <- cbind(hull_coords[, 2], hull_coords[, 1])
      ring <- rbind(ring, ring[1L, , drop = FALSE])
      sf::st_polygon(list(ring))
    })

    valid <- !vapply(polys, is.null, logical(1))
    valid_ids <- cell_ids[valid]
    valid_polys <- polys[valid]

    sfc <- sf::st_sfc(valid_polys)
    result <- sf::st_sf(
      cell_id = valid_ids,
      geometry = sfc
    )

    if (simplify && tolerance > 0) {
      result <- sf::st_simplify(result, dTolerance = tolerance)
    }
    return(result)
  }

  # Fallback: return boundary coordinates as tibble
  boundary_list <- lapply(cell_ids, function(cid) {
    coords <- which(labels == cid, arr.ind = TRUE)
    if (nrow(coords) < 3L) {
      return(tibble::tibble(cell_id = integer(0), row = numeric(0),
                            col = numeric(0)))
    }
    hull_idx <- grDevices::chull(coords[, 2], coords[, 1])
    hull_coords <- coords[hull_idx, , drop = FALSE]
    tibble::tibble(
      cell_id = rep(cid, nrow(hull_coords)),
      row = as.numeric(hull_coords[, 1]),
      col = as.numeric(hull_coords[, 2])
    )
  })

  result <- do.call(rbind, boundary_list)
  cli::cli_inform(c(
    "i" = "Install {.pkg sf} for proper polygon output.",
    "i" = "Returning boundary coordinates as tibble."
  ))
  result
}

#' Export mask to file
#'
#' Writes a segmentation mask to disk in one of several formats.
#'
#' @param mask An `sg_mask` object.
#' @param path Character. Output file path.
#' @param format Character. Export format: `"tiff"` (default), `"png"`,
#'   `"geojson"`, `"qupath"`, or `"csv"`.
#'
#' @return The output file path, returned invisibly.
#' @export
#' @examples
#' \donttest{
#' labels <- matrix(0L, nrow = 10, ncol = 10)
#' labels[3:8, 3:8] <- 1L
#' mask <- new_sg_mask(labels)
#' tmp <- tempfile(fileext = ".csv")
#' sg_export_mask(mask, tmp, format = "csv")
#' }
sg_export_mask <- function(mask, path, format = c("tiff", "png", "geojson",
                                                   "qupath", "csv")) {
  if (!inherits(mask, "sg_mask")) {
    cli::cli_abort("{.arg mask} must be an {.cls sg_mask} object.")
  }
  format <- match.arg(format)

  labels <- mask$labels
  dir_path <- dirname(path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }

  switch(format,
    tiff = {
      if (!requireNamespace("tiff", quietly = TRUE)) {
        cli::cli_abort(c(
          "TIFF export requires the {.pkg tiff} package.",
          "i" = "Install with: {.code install.packages('tiff')}"
        ))
      }
      # Normalize to [0, 1] for writeTIFF
      max_val <- max(labels)
      if (max_val == 0L) max_val <- 1L
      tiff::writeTIFF(labels / max_val, path, bits.per.sample = 16L)
    },
    png = {
      max_val <- max(labels)
      if (max_val == 0L) max_val <- 1L
      grDevices::png(path, width = ncol(labels), height = nrow(labels))
      graphics::par(mar = c(0, 0, 0, 0))
      graphics::image(t(labels[rev(seq_len(nrow(labels))), ]),
                      col = c("black", grDevices::rainbow(max_val)),
                      axes = FALSE)
      grDevices::dev.off()
    },
    geojson = {
      polys <- sg_mask_to_polygons(mask, simplify = TRUE)
      if (requireNamespace("sf", quietly = TRUE) && inherits(polys, "sf")) {
        sf::st_write(polys, path, driver = "GeoJSON", quiet = TRUE)
      } else {
        jsonlite::write_json(polys, path, pretty = TRUE)
      }
    },
    qupath = {
      # QuPath-compatible GeoJSON
      cell_ids <- seq_len(mask$n_cells)
      features <- lapply(cell_ids, function(cid) {
        coords <- which(labels == cid, arr.ind = TRUE)
        if (nrow(coords) < 3L) return(NULL)
        hull_idx <- grDevices::chull(coords[, 2], coords[, 1])
        hull_coords <- coords[hull_idx, , drop = FALSE]
        ring <- cbind(hull_coords[, 2], hull_coords[, 1])
        ring <- rbind(ring, ring[1L, , drop = FALSE])
        list(
          type = "Feature",
          id = paste0("cell-", cid),
          geometry = list(
            type = "Polygon",
            coordinates = list(as.list(as.data.frame(t(ring))))
          ),
          properties = list(
            objectType = "detection",
            classification = list(name = "Cell"),
            cellID = cid
          )
        )
      })
      features <- Filter(Negate(is.null), features)
      geojson <- list(type = "FeatureCollection", features = features)
      jsonlite::write_json(geojson, path, auto_unbox = TRUE, pretty = TRUE)
    },
    csv = {
      cell_ids <- seq_len(mask$n_cells)
      rows <- lapply(cell_ids, function(cid) {
        morph <- .compute_morphology(labels, cid)
        morph$cell_id <- cid
        morph
      })
      result <- do.call(rbind, rows)
      utils::write.csv(result, path, row.names = FALSE)
    }
  )

  cli::cli_inform(c("v" = "Mask exported to {.path {path}} ({.val {format}})."))

  invisible(path)
}
