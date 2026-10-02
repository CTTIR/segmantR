#' Create a new sg_image object
#'
#' Constructor for the `sg_image` S3 class, which represents a
#' multi-channel image with associated metadata.
#'
#' The pixel array order is always `[y, x, channel]`: the first array row
#' is the top image row. All arguments after `metadata` are optional
#' interchange fields added in segmantR 0.1.0.9000; objects created by older
#' code simply lack them and are treated with the documented defaults.
#'
#' @param pixels Numeric array of dimensions H x W (grayscale) or H x W x C
#'   (multi-channel).
#' @param channels Character vector of channel names. If `NULL`, defaults to
#'   `ch1`, `ch2`, etc.
#' @param resolution Named list with `x_um` and `y_um`: microns per current
#'   array pixel. Divide these by `origin$downsample` for the full-resolution
#'   reference pixel sizes.
#' @param metadata Named list of additional image metadata.
#' @param id Optional stable image identifier (string). Absolute file paths
#'   must not be used as identity.
#' @param plane Optional list with zero-based `level`, `series`, `c`, `z`
#'   and `t`. `c = NA` means that the array holds all channels.
#' @param origin Optional list with `x`, `y` (position of the array's
#'   top-left corner in full-resolution pixel coordinates) and `downsample`
#'   (full-resolution pixels per array pixel).
#' @param bands Optional data frame describing channels/bands with columns
#'   `name`, `wavelength_nm`, `fwhm_nm` (one row per channel).
#' @param value_semantics What pixel values represent: one of `"unknown"`,
#'   `"intensity"`, `"raw"`, `"reflectance"`, `"radiance"`, `"absorbance"`,
#'   `"probability"`.
#' @param source_digest Optional `"sha256:<hex>"` digest of the source file
#'   or pixel content.
#' @param transform_digest Optional digest of transformations applied to
#'   the source.
#' @param provenance Named list of provenance records.
#'
#' @return An object of class `sg_image`.
#' @export
#' @examples
#' pixels <- matrix(runif(100), nrow = 10, ncol = 10)
#' img <- new_sg_image(pixels)
#' print(img)
#'
#' # With interchange metadata
#' img2 <- new_sg_image(pixels, channels = "DAPI",
#'                      resolution = list(x_um = 0.5, y_um = 0.5),
#'                      id = "slide-001", value_semantics = "intensity")
new_sg_image <- function(pixels, channels = NULL, resolution = NULL,
                         metadata = list(), id = NULL, plane = NULL,
                         origin = NULL, bands = NULL,
                         value_semantics = "unknown", source_digest = NULL,
                         transform_digest = NULL, provenance = list()) {
  stopifnot(is.numeric(pixels), length(dim(pixels)) %in% c(2L, 3L))
  n_ch <- if (length(dim(pixels)) == 3L) dim(pixels)[3] else 1L
  if (is.null(channels)) channels <- paste0("ch", seq_len(n_ch))
  value_semantics <- match.arg(value_semantics, .sg_value_semantics)
  if (!is.null(id)) {
    stopifnot(is.character(id), length(id) == 1L, !is.na(id), nzchar(id))
  }
  structure(
    list(
      pixels = pixels,
      channels = channels,
      resolution = resolution %||% list(x_um = NA_real_, y_um = NA_real_),
      metadata = metadata,
      history = character(0),
      id = id,
      plane = .sg_check_plane(plane),
      origin = .sg_check_origin(origin),
      bands = .sg_check_bands(bands, n_ch, channels),
      value_semantics = value_semantics,
      source_digest = source_digest,
      transform_digest = transform_digest,
      provenance = provenance
    ),
    class = "sg_image"
  )
}

.sg_value_semantics <- c("unknown", "intensity", "raw", "reflectance",
                         "radiance", "absorbance", "probability")

#' Validate and normalise a plane description
#' @noRd
.sg_check_plane <- function(plane) {
  def <- list(level = 0L, series = 0L, c = NA_integer_, z = 0L, t = 0L)
  if (is.null(plane)) return(def)
  if (!is.list(plane)) {
    .sg_abort("{.arg plane} must be a list with level, series, c, z, t.",
              code = "INVALID_PLANE")
  }
  unknown <- setdiff(names(plane), names(def))
  if (length(unknown)) {
    .sg_abort("Unknown plane field{?s}: {.val {unknown}}.",
              code = "INVALID_PLANE", details = list(fields = unknown))
  }
  out <- utils::modifyList(def, plane)
  for (nm in names(def)) {
    v <- out[[nm]]
    na_ok <- nm == "c"
    bad <- length(v) != 1L || (!is.numeric(v) && !(is.logical(v) && is.na(v))) ||
      (is.na(v) && !na_ok) || (!is.na(v) && (v < 0 || v != trunc(v)))
    if (bad) {
      .sg_abort(
        "Plane field {.field {nm}} must be a zero-based integer{if (na_ok) ' or NA' else ''}.",
        code = "INVALID_PLANE", details = list(field = nm)
      )
    }
    out[[nm]] <- as.integer(v)
  }
  out[names(def)]
}

#' Validate and normalise an origin description
#' @noRd
.sg_check_origin <- function(origin) {
  def <- list(x = 0, y = 0, downsample = 1)
  if (is.null(origin)) return(def)
  out <- utils::modifyList(def, as.list(origin))
  unknown <- setdiff(names(out), names(def))
  num1 <- function(v) (is.numeric(v) || is.logical(v)) && length(v) == 1L
  ok <- length(unknown) == 0L && num1(out$x) && num1(out$y) &&
    (is.na(out$x) || is.finite(out$x)) && (is.na(out$y) || is.finite(out$y)) &&
    num1(out$downsample) && is.finite(out$downsample) && out$downsample > 0
  if (!ok) {
    .sg_abort(
      "{.arg origin} must be a list of numeric {.field x}, {.field y} (NA if unknown) and a positive {.field downsample}.",
      code = "VALIDATION_FAILED"
    )
  }
  lapply(out[names(def)], as.numeric)
}

#' Validate a band table
#' @noRd
.sg_check_bands <- function(bands, n_ch, channels) {
  if (is.null(bands)) return(NULL)
  bands <- tibble::as_tibble(bands)
  if (nrow(bands) != n_ch) {
    .sg_abort(
      "{.arg bands} has {nrow(bands)} row{?s} but the image has {n_ch} channel{?s}.",
      code = "DIMENSION_MISMATCH"
    )
  }
  if (!"name" %in% names(bands)) bands$name <- channels
  for (col in c("wavelength_nm", "fwhm_nm")) {
    if (!col %in% names(bands)) bands[[col]] <- NA_real_
    bands[[col]] <- as.numeric(bands[[col]])
  }
  bands$channel <- seq_len(n_ch)
  bands$c <- seq_len(n_ch) - 1L
  bands[, c("channel", "c", "name", "wavelength_nm", "fwhm_nm",
            setdiff(names(bands), c("channel", "c", "name", "wavelength_nm",
                                    "fwhm_nm")))]
}

#' Effective plane/origin/semantics with defaults for legacy objects
#' @noRd
.sg_image_plane <- function(x) .sg_check_plane(x$plane)

#' @noRd
.sg_image_origin <- function(x) .sg_check_origin(x$origin)

#' @export
print.sg_image <- function(x, ...) {
  dims <- dim(x$pixels)
  if (length(dims) == 2L) {
    cli::cli_text("{.cls sg_image}: {dims[1]} x {dims[2]} (1 channel)")
  } else {
    cli::cli_text("{.cls sg_image}: {dims[1]} x {dims[2]} x {dims[3]} ({length(x$channels)} channels: {paste(x$channels, collapse = ', ')})")

  }
  if (!is.null(x$id)) {
    cli::cli_text("ID: {x$id}")
  }
  if (!is.na(x$resolution$x_um)) {
    cli::cli_text("Resolution: {x$resolution$x_um} x {x$resolution$y_um} um/px")
  }
  if (!is.null(x$value_semantics) && x$value_semantics != "unknown") {
    cli::cli_text("Values: {x$value_semantics}")
  }
  if (length(x$history) > 0L) {
    cli::cli_text("History: {paste(x$history, collapse = ' -> ')}")
  }
  invisible(x)
}

#' @export
dim.sg_image <- function(x) {
  dim(x$pixels)
}

#' @export
`[.sg_image` <- function(x, i, j, ..., drop = FALSE) {
  pixels <- x$pixels
  if (length(dim(pixels)) == 2L) {
    new_pixels <- pixels[i, j, drop = FALSE]
  } else {
    new_pixels <- pixels[i, j, , drop = FALSE]
  }
  origin <- .sg_image_origin(x)
  rows <- if (missing(i)) seq_len(dim(pixels)[1]) else
    seq_len(dim(pixels)[1])[i]
  cols <- if (missing(j)) seq_len(dim(pixels)[2]) else
    seq_len(dim(pixels)[2])[j]
  contiguous <- length(rows) > 0L && length(cols) > 0L &&
    all(diff(rows) == 1L) && all(diff(cols) == 1L)
  history <- x$history
  transform_digest <- x$transform_digest
  if (contiguous) {
    origin$x <- origin$x + (cols[1] - 1) * origin$downsample
    origin$y <- origin$y + (rows[1] - 1) * origin$downsample
  } else {
    origin <- list(x = NA_real_, y = NA_real_, downsample = origin$downsample)
    history <- c(history, "subset:non_contiguous")
    transform_digest <- .sg_digest_json(list(
      parent = transform_digest %||% "identity",
      op = "subset", rows = I(rows), cols = I(cols)
    ))
  }
  out <- new_sg_image(
    pixels = new_pixels,
    channels = x$channels,
    resolution = x$resolution,
    metadata = x$metadata,
    id = x$id,
    plane = x$plane,
    origin = origin,
    bands = if (is.null(x$bands)) NULL else
      x$bands[, setdiff(names(x$bands), c("channel", "c"))],
    value_semantics = x$value_semantics %||% "unknown",
    source_digest = x$source_digest,
    transform_digest = transform_digest,
    provenance = x$provenance %||% list()
  )
  out$history <- history
  out
}

#' Read an image file
#'
#' Reads TIFF, PNG, or JPEG image files and returns an `sg_image` object.
#' Dispatches to `EBImage::readImage()` when available, otherwise uses
#' `imager::load.image()`. The returned pixel array is always ordered
#' `[y, x, channel]`, and the object records the SHA-256 digest of the file
#' in `source_digest` plus its base name (never the full path) in
#' `metadata$source_name`.
#'
#' @param path Character string, path to the image file.
#' @param ... Additional arguments passed to the underlying reader.
#'
#' @return An `sg_image` object.
#' @export
#' @examples
#' \donttest{
#' # img <- sg_read_image("path/to/image.tiff")
#' }
sg_read_image <- function(path, ...) {
  if (!file.exists(path)) {
    cli::cli_abort("Image file not found: {.path {path}}")
  }
  ext <- tolower(tools::file_ext(path))
  pixels <- NULL
  if (.check_ebimage()) {
    img <- EBImage::readImage(path)
    # EBImage stores arrays as [x, y, channel]; convert to [y, x, channel].
    pixels <- .sg_xy_to_yx(EBImage::imageData(img))
    if (length(dim(pixels)) == 2L) {
      channels <- "ch1"
    } else {
      channels <- paste0("ch", seq_len(dim(pixels)[3]))
    }
  } else if (ext %in% c("tif", "tiff") &&
             requireNamespace("tiff", quietly = TRUE)) {
    img <- tiff::readTIFF(path, all = FALSE, ...)
    if (is.list(img)) img <- img[[1]]
    if (length(dim(img)) == 2L) {
      pixels <- img
      channels <- "ch1"
    } else {
      pixels <- img
      channels <- paste0("ch", seq_len(dim(img)[3]))
    }
  } else {
    img <- imager::load.image(path)
    arr <- as.array(img)
    # imager stores arrays as [x, y, z, channel]; take z = 1 and reorder.
    if (length(dim(arr)) == 4L) {
      pixels <- arr[, , 1, , drop = TRUE]
    } else {
      pixels <- arr
    }
    pixels <- .sg_xy_to_yx(pixels)
    if (length(dim(pixels)) == 2L) {
      channels <- "ch1"
    } else {
      channels <- paste0("ch", seq_len(dim(pixels)[3]))
    }
  }
  if (is.null(pixels)) {
    cli::cli_abort("Could not read image: {.path {path}}")
  }
  new_sg_image(
    pixels = pixels, channels = channels,
    metadata = list(source_name = basename(path)),
    source_digest = paste0("sha256:", .sg_sha256_file(path))
  )
}

#' Swap the first two array axes (x, y order to y, x order)
#' @noRd
.sg_xy_to_yx <- function(a) {
  d <- dim(a)
  if (length(d) == 2L) return(t(a))
  if (length(d) == 3L) return(aperm(a, c(2L, 1L, 3L)))
  a
}
