#' Preprocess an image
#'
#' Applies a chain of preprocessing steps to an `sg_image` object,
#' including optional stain normalisation, denoising, and contrast
#' enhancement.
#'
#' @param image An `sg_image` object.
#' @param stain_normalize Character string specifying the stain
#'   normalisation method. One of `"none"` (default), `"macenko"`,
#'   `"reinhard"`, or `"vahadane"`.
#' @param denoise Logical; if `TRUE`, a simple mean filter is applied
#'   for denoising. Default is `FALSE`.
#' @param contrast Character string specifying contrast enhancement.
#'   One of `"none"` (default), `"clahe"`, or `"stretch"`.
#' @param target_resolution Numeric scalar or `NULL`. If not `NULL`,
#'   the image is resampled to this target resolution (microns per
#'   pixel) using bilinear interpolation.
#'
#' @return A new `sg_image` object with its `history` field updated to
#'   record the preprocessing steps applied.
#' @export
#' @examples
#' pixels <- matrix(runif(400), nrow = 20, ncol = 20)
#' img <- new_sg_image(pixels)
#' img2 <- sg_preprocess(img)
#' img3 <- sg_preprocess(img, contrast = "stretch", denoise = TRUE)
sg_preprocess <- function(image,
                          stain_normalize = c("none", "macenko",
                                              "reinhard", "vahadane"),
                          denoise = FALSE,
                          contrast = c("none", "clahe", "stretch"),
                          target_resolution = NULL) {
  stopifnot(inherits(image, "sg_image"))
  stain_normalize <- match.arg(stain_normalize)
  contrast <- match.arg(contrast)
  stopifnot(is.logical(denoise), length(denoise) == 1L)

  pixels <- image$pixels
  history <- image$history
  resolution <- image$resolution


  # --- Stain normalisation ------------------------------------------------
  if (stain_normalize != "none") {
    pixels <- .stain_normalize(pixels, method = stain_normalize)
    history <- c(history, paste0("stain_norm:", stain_normalize))
  }

  # --- Denoising ----------------------------------------------------------
  if (denoise) {
    pixels <- .mean_filter(pixels, size = 3L)
    history <- c(history, "denoise:mean3x3")
  }

  # --- Contrast enhancement -----------------------------------------------
  if (contrast == "clahe") {
    pixels <- .clahe(pixels)
    history <- c(history, "contrast:clahe")
  } else if (contrast == "stretch") {
    pixels <- .contrast_stretch(pixels)
    history <- c(history, "contrast:stretch")
  }

  # --- Resolution resampling ----------------------------------------------
  if (!is.null(target_resolution)) {
    stopifnot(is.numeric(target_resolution), length(target_resolution) == 1L,
              target_resolution > 0)
    current_res <- resolution$x_um
    if (!is.na(current_res) && current_res > 0) {
      scale_factor <- current_res / target_resolution
      pixels <- .resample_bilinear(pixels, scale_factor)
      resolution$x_um <- target_resolution
      resolution$y_um <- target_resolution
      history <- c(history, paste0("resample:", target_resolution, "um"))
    } else {
      cli::cli_inform(c(
        "!" = "Cannot resample: image resolution is not set.",
        "i" = "Set {.code resolution} when creating the {.cls sg_image}."
      ))
    }
  }

  new_sg_image(
    pixels = pixels,
    channels = image$channels,
    resolution = resolution,
    metadata = image$metadata
  )
}

#' Separate H&E stain channels by colour deconvolution
#'
#' Applies colour deconvolution to an H&E-stained image to separate
#' the haematoxylin and eosin channels.
#'
#' @param image An `sg_image` object with at least 3 colour channels
#'   (RGB).
#' @param method Character string specifying the deconvolution method.
#'   One of `"macenko"` (default) or `"ruifrok"`.
#' @param stains Optional 3x3 numeric matrix whose columns are the
#'   stain vectors. If `NULL`, stain vectors are estimated from the
#'   image using the specified `method`.
#'
#' @return A named list of `sg_image` objects, one per stain channel.
#'   Typically `hematoxylin` and `eosin`, plus `residual`.
#' @export
#' @examples
#' \donttest{
#' # Requires a colour image
#' pixels <- array(runif(300), dim = c(10, 10, 3))
#' img <- new_sg_image(pixels, channels = c("R", "G", "B"))
#' stains <- sg_stain_deconvolve(img)
#' names(stains)
#' }
sg_stain_deconvolve <- function(image,
                                method = c("macenko", "ruifrok"),
                                stains = NULL) {

  stopifnot(inherits(image, "sg_image"))
  method <- match.arg(method)

  pixels <- image$pixels
  if (length(dim(pixels)) != 3L || dim(pixels)[3] < 3L) {
    cli::cli_abort(c(
      "Stain deconvolution requires an RGB image.",
      "i" = "Input has {length(dim(pixels))} dimension{?s}."
    ))
  }

  # Use supplied stain matrix or the Ruifrok H&E defaults
  if (is.null(stains)) {
    if (method == "ruifrok") {
      stains <- .ruifrok_stain_matrix()
    } else {
      stains <- .estimate_macenko_stains(pixels)
    }
  }

  stopifnot(is.matrix(stains), nrow(stains) == 3L, ncol(stains) == 3L)

  # Convert RGB to optical density
  od <- .rgb_to_od(pixels)

  # Deconvolve
  stain_inv <- tryCatch(solve(stains), error = function(e) {
    cli::cli_abort(c(
      "Stain matrix is singular and cannot be inverted.",
      "i" = "Provide a valid stain matrix."
    ))
  })

  nr <- dim(pixels)[1]
  nc <- dim(pixels)[2]
  od_flat <- matrix(od, nrow = nr * nc, ncol = 3L)
  conc <- od_flat %*% stain_inv
  conc[conc < 0] <- 0

  channel_names <- c("hematoxylin", "eosin", "residual")
  result <- lapply(seq_len(3L), function(k) {
    ch_pixels <- matrix(conc[, k], nrow = nr, ncol = nc)
    new_sg_image(
      pixels = ch_pixels,
      channels = channel_names[k],
      resolution = image$resolution,
      metadata = c(image$metadata, list(
        deconvolution_method = method,
        stain_channel = channel_names[k]
      ))
    )
  })
  names(result) <- channel_names
  result
}


# ---- Internal helpers ---------------------------------------------------

#' Simple mean filter for denoising
#' @noRd
.mean_filter <- function(pixels, size = 3L) {
  half <- size %/% 2L
  if (length(dim(pixels)) == 2L) {
    return(.mean_filter_2d(pixels, half))
  }
  n_ch <- dim(pixels)[3]
  for (k in seq_len(n_ch)) {
    pixels[, , k] <- .mean_filter_2d(pixels[, , k], half)
  }
  pixels
}

#' @noRd
.mean_filter_2d <- function(mat, half) {
  nr <- nrow(mat)
  nc <- ncol(mat)
  result <- mat
  for (i in (half + 1L):(nr - half)) {
    for (j in (half + 1L):(nc - half)) {
      result[i, j] <- mean(mat[(i - half):(i + half),
                                (j - half):(j + half)])
    }
  }
  result
}

#' Contrast stretch to range 0, 1
#' @noRd
.contrast_stretch <- function(pixels) {
  rng <- range(pixels, na.rm = TRUE)
  if (rng[2] - rng[1] == 0) return(pixels)
  (pixels - rng[1]) / (rng[2] - rng[1])
}

#' Simple CLAHE (Contrast Limited Adaptive Histogram Equalisation)
#' @noRd
.clahe <- function(pixels, n_bins = 256L) {
  if (length(dim(pixels)) == 2L) {
    return(.clahe_2d(pixels, n_bins))
  }
  n_ch <- dim(pixels)[3]
  for (k in seq_len(n_ch)) {
    pixels[, , k] <- .clahe_2d(pixels[, , k], n_bins)
  }
  pixels
}

#' @noRd
.clahe_2d <- function(mat, n_bins = 256L) {
  vals <- as.vector(mat)
  rng <- range(vals, na.rm = TRUE)
  if (rng[2] - rng[1] == 0) return(mat)
  scaled <- (vals - rng[1]) / (rng[2] - rng[1])
  bins <- findInterval(scaled, seq(0, 1, length.out = n_bins + 1L),
                       all.inside = TRUE)
  cdf <- cumsum(tabulate(bins, nbins = n_bins))
  cdf <- (cdf - min(cdf)) / (max(cdf) - min(cdf))
  eq <- cdf[bins]
  matrix(eq, nrow = nrow(mat), ncol = ncol(mat))
}

#' Bilinear resampling
#' @noRd
.resample_bilinear <- function(pixels, scale_factor) {
  if (length(dim(pixels)) == 2L) {
    return(.resample_2d(pixels, scale_factor))
  }
  nr_new <- max(1L, round(dim(pixels)[1] * scale_factor))
  nc_new <- max(1L, round(dim(pixels)[2] * scale_factor))
  n_ch <- dim(pixels)[3]
  new_pixels <- array(0, dim = c(nr_new, nc_new, n_ch))
  for (k in seq_len(n_ch)) {
    new_pixels[, , k] <- .resample_2d(pixels[, , k], scale_factor)
  }
  new_pixels
}

#' @noRd
.resample_2d <- function(mat, scale_factor) {
  nr <- nrow(mat)
  nc <- ncol(mat)
  nr_new <- max(1L, round(nr * scale_factor))
  nc_new <- max(1L, round(nc * scale_factor))
  result <- matrix(0, nrow = nr_new, ncol = nc_new)
  for (i in seq_len(nr_new)) {
    for (j in seq_len(nc_new)) {
      src_r <- (i - 0.5) / scale_factor + 0.5
      src_c <- (j - 0.5) / scale_factor + 0.5
      r0 <- max(1L, floor(src_r))
      c0 <- max(1L, floor(src_c))
      r1 <- min(nr, r0 + 1L)
      c1 <- min(nc, c0 + 1L)
      dr <- src_r - r0
      dc <- src_c - c0
      result[i, j] <- (1 - dr) * (1 - dc) * mat[r0, c0] +
        dr * (1 - dc) * mat[r1, c0] +
        (1 - dr) * dc * mat[r0, c1] +
        dr * dc * mat[r1, c1]
    }
  }
  result
}

#' Stain normalisation dispatcher
#' @noRd
.stain_normalize <- function(pixels, method) {
  if (method == "reinhard") {
    return(.reinhard_normalize(pixels))
  }
  # For macenko/vahadane, apply a simplified version
  .reinhard_normalize(pixels)
}

#' Reinhard colour normalisation (simplified)
#' @noRd
.reinhard_normalize <- function(pixels) {
  # Simple per-channel zero-mean/unit-variance normalisation mapped back

  if (length(dim(pixels)) != 3L) return(pixels)
  n_ch <- dim(pixels)[3]
  for (k in seq_len(n_ch)) {
    ch <- pixels[, , k]
    mu <- mean(ch, na.rm = TRUE)
    sd_val <- stats::sd(as.vector(ch), na.rm = TRUE)
    if (sd_val > 0) {
      pixels[, , k] <- (ch - mu) / sd_val * 0.15 + 0.5
    }
  }
  pmin(pmax(pixels, 0), 1)
}

#' RGB to optical density
#' @noRd
.rgb_to_od <- function(pixels) {
  pixels[pixels < 1e-6] <- 1e-6
  -log(pmin(pixels, 1))
}

#' Ruifrok H&E stain matrix
#' @noRd
.ruifrok_stain_matrix <- function() {
  # Standard Ruifrok & Johnston stain vectors (normalised)
  matrix(c(
    0.6500286,  0.7040055,  0.2859569,
    0.2681468,  0.5688969,  0.7782507,
    0.7110272,  0.4232710,  0.5615109
  ), nrow = 3L, ncol = 3L, byrow = TRUE)
}

#' Estimate Macenko stain vectors (simplified)
#' @noRd
.estimate_macenko_stains <- function(pixels) {
  nr <- dim(pixels)[1]
  nc <- dim(pixels)[2]
  od <- .rgb_to_od(pixels)
  od_flat <- matrix(od, nrow = nr * nc, ncol = 3L)
  # Keep only pixels with sufficient optical density
  od_norm <- sqrt(rowSums(od_flat^2))
  keep <- od_norm > 0.15
  if (sum(keep) < 10L) {
    cli::cli_inform(c(
      "!" = "Too few stained pixels for Macenko estimation.",
      "i" = "Falling back to Ruifrok stain vectors."
    ))
    return(.ruifrok_stain_matrix())
  }
  od_sub <- od_flat[keep, , drop = FALSE]
  pca <- stats::prcomp(od_sub, center = TRUE, scale. = FALSE, rank. = 2L)
  proj <- od_sub %*% pca$rotation[, 1:2]
  angles <- atan2(proj[, 2], proj[, 1])
  min_angle <- stats::quantile(angles, 0.01)
  max_angle <- stats::quantile(angles, 0.99)
  v1 <- pca$rotation[, 1:2] %*% c(cos(min_angle), sin(min_angle))
  v2 <- pca$rotation[, 1:2] %*% c(cos(max_angle), sin(max_angle))
  v1 <- v1 / sqrt(sum(v1^2))
  v2 <- v2 / sqrt(sum(v2^2))
  # Third vector is the cross product (residual)
  v3 <- c(
    v1[2] * v2[3] - v1[3] * v2[2],
    v1[3] * v2[1] - v1[1] * v2[3],
    v1[1] * v2[2] - v1[2] * v2[1]
  )
  v3 <- v3 / sqrt(sum(v3^2))
  matrix(c(v1, v2, v3), nrow = 3L, ncol = 3L)
}
