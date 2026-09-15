# Channel/band selection with registered band operations, and an optional
# pure-R ENVI reader with windowed, band-subset reads. No vendor SDK is
# required; Cubert/TIVITA data enter through neutral ENVI/TIFF exports.

.sg_band_operations <- c("none", "band_mean", "ratio", "normalized_difference")

#' Select one analysis channel from an image
#'
#' Produces a single-channel `sg_image` from a channel index, a channel or
#' band name, a band wavelength, or one of the registered band operations
#' `band_mean`, `ratio` and `normalized_difference`. No free expressions are
#' accepted. The result records the source bands, wavelengths, operation,
#' value semantics and a transform digest so declarative protocol runs and
#' direct calls stay comparable.
#'
#' Band operations require band wavelengths (see [new_sg_image()] `bands`
#' or [sg_read_envi()]) and refuse images whose `value_semantics` is
#' `"unknown"` for `ratio` and `normalized_difference`, because such ratios
#' are only interpretable for a declared value scale. Non-finite results
#' (division by zero) are replaced by the smallest finite result and counted
#' in `provenance$band_selection$non_finite_replaced`.
#'
#' @param image An `sg_image` object.
#' @param channel 1-based channel index (used when no other selector is
#'   given).
#' @param channel_name Channel or band name.
#' @param wavelength_nm Band centre wavelength to select.
#' @param wavelength_tolerance_nm Maximum distance to the nearest band
#'   centre.
#' @param band_operation One of `"none"`, `"band_mean"`, `"ratio"`,
#'   `"normalized_difference"`.
#' @param band_a_nm,band_b_nm Wavelengths of bands a and b for `ratio` and
#'   `normalized_difference`.
#' @param band_min_nm,band_max_nm Wavelength interval for `band_mean`.
#'
#' @return A single-channel `sg_image`.
#' @export
#' @examples
#' cube <- array(runif(5 * 5 * 3), dim = c(5, 5, 3))
#' img <- new_sg_image(cube, channels = c("b450", "b550", "b650"),
#'                     bands = data.frame(wavelength_nm = c(450, 550, 650)),
#'                     value_semantics = "reflectance")
#' sg_select_channel(img, wavelength_nm = 552)$channels
#' nd <- sg_select_channel(img, band_operation = "normalized_difference",
#'                         band_a_nm = 650, band_b_nm = 550)
#' nd$provenance$band_selection$operation
sg_select_channel <- function(image, channel = 1L, channel_name = NULL,
                              wavelength_nm = NULL,
                              wavelength_tolerance_nm = 5,
                              band_operation = "none", band_a_nm = NULL,
                              band_b_nm = NULL, band_min_nm = NULL,
                              band_max_nm = NULL) {
  .sg_assert_image(image)
  band_operation <- match.arg(band_operation, .sg_band_operations)
  px <- image$pixels
  if (length(dim(px)) == 2L) px <- array(px, dim = c(dim(px), 1L))
  n_ch <- dim(px)[3]
  names_ch <- image$channels
  if (length(names_ch) != n_ch) names_ch <- paste0("ch", seq_len(n_ch))
  bands <- image$bands
  wl <- if (!is.null(bands)) bands$wavelength_nm else rep(NA_real_, n_ch)
  semantics <- image$value_semantics %||% "unknown"

  nearest <- function(target, what) {
    if (all(is.na(wl))) {
      .sg_abort(
        "Selecting by wavelength needs band wavelengths in the image.",
        code = "VALIDATION_FAILED", details = list(selector = what)
      )
    }
    d <- abs(wl - target)
    best <- which(d == min(d, na.rm = TRUE))
    if (length(best) != 1L) {
      .sg_abort("Wavelength {target} nm is ambiguous (several nearest bands).",
                code = "VALIDATION_FAILED", details = list(selector = what))
    }
    if (d[best] > wavelength_tolerance_nm) {
      .sg_abort(
        "No band within {wavelength_tolerance_nm} nm of {target} nm (nearest: {wl[best]} nm).",
        code = "VALIDATION_FAILED", details = list(selector = what)
      )
    }
    best
  }

  used <- integer(0)
  non_finite <- 0L
  if (band_operation == "none") {
    if (!is.null(channel_name)) {
      idx <- which(names_ch == channel_name)
      if (!is.null(bands) && length(idx) == 0L) {
        idx <- which(bands$name == channel_name)
      }
      if (length(idx) != 1L) {
        .sg_abort(
          "Channel name {.val {channel_name}} matches {length(idx)} channel{?s}; exactly one is required.",
          code = "VALIDATION_FAILED", details = list(selector = "channel_name")
        )
      }
      method <- "name"
    } else if (!is.null(wavelength_nm)) {
      idx <- nearest(wavelength_nm, "wavelength_nm")
      method <- "wavelength"
    } else {
      idx <- as.integer(channel)
      if (length(idx) != 1L || is.na(idx) || idx < 1L || idx > n_ch) {
        .sg_abort(
          c("Channel {channel} is out of range.",
            "i" = "Image has {n_ch} channel{?s} (1 to {n_ch})."),
          code = "VALIDATION_FAILED", details = list(selector = "channel")
        )
      }
      method <- "index"
    }
    values <- px[, , idx]
    used <- idx
    out_name <- names_ch[idx]
  } else {
    if (band_operation %in% c("ratio", "normalized_difference") &&
        semantics == "unknown") {
      .sg_abort(
        c("Band operation {.val {band_operation}} needs declared value semantics.",
          "i" = "Set {.code value_semantics} (e.g. 'reflectance' or 'raw') on the image."),
        code = "VALIDATION_FAILED",
        details = list(selector = "band_operation")
      )
    }
    method <- "operation"
    if (band_operation == "band_mean") {
      if (is.null(band_min_nm) || is.null(band_max_nm) ||
          band_min_nm > band_max_nm) {
        .sg_abort("band_mean needs band_min_nm <= band_max_nm.",
                  code = "VALIDATION_FAILED")
      }
      if (all(is.na(wl))) {
        .sg_abort("band_mean needs band wavelengths in the image.",
                  code = "VALIDATION_FAILED")
      }
      used <- which(!is.na(wl) & wl >= band_min_nm & wl <= band_max_nm)
      if (length(used) == 0L) {
        .sg_abort("No band lies within [{band_min_nm}, {band_max_nm}] nm.",
                  code = "VALIDATION_FAILED")
      }
      values <- apply(px[, , used, drop = FALSE], c(1, 2), mean)
      out_name <- sprintf("band_mean_%s_%s", band_min_nm, band_max_nm)
    } else {
      if (is.null(band_a_nm) || is.null(band_b_nm)) {
        .sg_abort("{band_operation} needs band_a_nm and band_b_nm.",
                  code = "VALIDATION_FAILED")
      }
      a <- nearest(band_a_nm, "band_a_nm")
      b <- nearest(band_b_nm, "band_b_nm")
      used <- c(a, b)
      va <- px[, , a]
      vb <- px[, , b]
      values <- if (band_operation == "ratio") va / vb else (va - vb) / (va + vb)
      bad <- !is.finite(values)
      non_finite <- sum(bad)
      if (non_finite > 0L) {
        if (all(bad)) {
          .sg_abort("Band operation produced no finite values.",
                    code = "VALIDATION_FAILED")
        }
        values[bad] <- min(values[!bad])
      }
      out_name <- sprintf("%s_%s_%s", band_operation, wl[a], wl[b])
    }
  }
  values <- matrix(as.numeric(values), nrow = dim(px)[1], ncol = dim(px)[2])
  selection <- list(
    method = method,
    operation = band_operation,
    channels = as.integer(used),
    c = as.integer(used - 1L),
    names = names_ch[used],
    wavelength_nm = wl[used],
    value_semantics = semantics,
    non_finite_replaced = as.integer(non_finite)
  )
  transform <- .sg_digest_json(list(
    parent = image$transform_digest %||% "identity",
    operation = "select_channel",
    selection = selection[c("method", "operation", "c")]
  ))
  derived_semantics <- if (band_operation %in% c("ratio",
                                                 "normalized_difference")) {
    "unknown"
  } else {
    semantics
  }
  prov <- image$provenance %||% list()
  prov$band_selection <- selection
  new_bands <- if (!is.null(bands) && length(used) == 1L) {
    bands[used, setdiff(names(bands), c("channel", "c")), drop = FALSE]
  } else {
    NULL
  }
  plane <- .sg_image_plane(image)
  if (length(used) == 1L) plane$c <- as.integer(used - 1L)
  out <- new_sg_image(
    values, channels = out_name, resolution = image$resolution,
    metadata = image$metadata, id = image$id, plane = plane,
    origin = .sg_image_origin(image), bands = new_bands,
    value_semantics = derived_semantics,
    source_digest = image$source_digest, transform_digest = transform,
    provenance = prov
  )
  out$history <- c(image$history, paste0("select_channel:", method, ":",
                                         band_operation))
  out
}

# ---- ENVI ------------------------------------------------------------------

.sg_envi_types <- list(
  `1` = list(dtype = "uint8", what = "integer", size = 1L, signed = FALSE),
  `2` = list(dtype = "int16", what = "integer", size = 2L, signed = TRUE),
  `3` = list(dtype = "int32", what = "integer", size = 4L, signed = TRUE),
  `4` = list(dtype = "float32", what = "double", size = 4L, signed = TRUE),
  `5` = list(dtype = "float64", what = "double", size = 8L, signed = TRUE),
  `12` = list(dtype = "uint16", what = "integer", size = 2L, signed = FALSE),
  `13` = list(dtype = "uint32", what = "integer", size = 4L, signed = FALSE)
)

#' Read and validate an ENVI header without reading pixel data
#'
#' @param path Path to the `.hdr` file or to the data file next to it.
#' @param data_file Optional explicit data file path.
#'
#' @return A list of class `sg_envi_info` with `samples`, `lines`, `bands`,
#'   `interleave`, `byte_order`, `data_type`, `dtype`, `header_offset`,
#'   `wavelength_nm`, `fwhm_nm`, `band_names`, `nodata`, `scale_factor`,
#'   `gain`, `offset`, `wavelength_units`, `data_bytes_expected`,
#'   `data_bytes_present` and `header_digest`. Paths are not stored.
#' @export
#' @examples
#' d <- tempfile("envi")
#' dir.create(d)
#' hdr <- file.path(d, "cube.hdr")
#' writeLines(c("ENVI", "samples = 2", "lines = 2", "bands = 2",
#'              "header offset = 0", "data type = 12", "interleave = bsq",
#'              "byte order = 0", "wavelength = {500, 600}"), hdr)
#' writeBin(1:8, file.path(d, "cube"), size = 2L, endian = "little")
#' sg_envi_info(hdr)$wavelength_nm
sg_envi_info <- function(path, data_file = NULL) {
  paths <- .sg_envi_paths(path, data_file)
  lines <- readLines(paths$header, warn = FALSE)
  if (length(lines) == 0L || !grepl("^ENVI", trimws(lines[1]))) {
    .sg_abort("Not an ENVI header (first line must be 'ENVI').",
              code = "VALIDATION_FAILED")
  }
  txt <- paste(lines[-1], collapse = "\n")
  fields <- list()
  pattern <- "(?m)^\\s*([^=\\n]+?)\\s*=\\s*(\\{[^}]*\\}|[^\\n]*)"
  m <- gregexpr(pattern, txt, perl = TRUE)[[1]]
  if (m[1] != -1L) {
    starts <- attr(m, "capture.start")
    lens <- attr(m, "capture.length")
    for (i in seq_along(m)) {
      key <- tolower(trimws(substr(txt, starts[i, 1],
                                   starts[i, 1] + lens[i, 1] - 1L)))
      val <- trimws(substr(txt, starts[i, 2], starts[i, 2] + lens[i, 2] - 1L))
      fields[[key]] <- val
    }
  }
  num <- function(key, default = NULL, required = FALSE) {
    v <- fields[[key]]
    if (is.null(v)) {
      if (required) {
        .sg_abort("ENVI header is missing {.field {key}}.",
                  code = "VALIDATION_FAILED", details = list(field = key))
      }
      return(default)
    }
    out <- suppressWarnings(as.numeric(v))
    if (is.na(out)) {
      .sg_abort("ENVI header field {.field {key}} is not numeric.",
                code = "VALIDATION_FAILED", details = list(field = key))
    }
    out
  }
  vec <- function(key, numeric = TRUE) {
    v <- fields[[key]]
    if (is.null(v)) return(NULL)
    v <- gsub("^\\{|\\}$", "", v)
    parts <- trimws(strsplit(v, ",", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    if (!numeric) return(parts)
    out <- suppressWarnings(as.numeric(parts))
    if (anyNA(out)) {
      .sg_abort("ENVI header field {.field {key}} contains non-numeric values.",
                code = "VALIDATION_FAILED", details = list(field = key))
    }
    out
  }
  samples <- num("samples", required = TRUE)
  n_lines <- num("lines", required = TRUE)
  n_bands <- num("bands", required = TRUE)
  dims <- c(samples = samples, lines = n_lines, bands = n_bands)
  for (nm in names(dims)) {
    v <- dims[[nm]]
    if (v < 1 || v != trunc(v)) {
      .sg_abort("ENVI {.field {nm}} must be a positive integer.",
                code = "VALIDATION_FAILED", details = list(field = nm))
    }
  }
  data_type <- as.character(num("data type", required = TRUE))
  type <- .sg_envi_types[[data_type]]
  if (is.null(type)) {
    .sg_abort("ENVI data type {data_type} is not supported.",
              class = "sg_capability_error", code = "CAPABILITY_UNAVAILABLE",
              details = list(field = "data type", value = data_type))
  }
  interleave <- tolower(fields[["interleave"]] %||% "bsq")
  if (!interleave %in% c("bsq", "bil", "bip")) {
    .sg_abort("ENVI interleave must be bsq, bil or bip.",
              code = "VALIDATION_FAILED", details = list(field = "interleave"))
  }
  byte_order <- num("byte order", default = 0)
  if (!byte_order %in% c(0, 1)) {
    .sg_abort("ENVI byte order must be 0 or 1.",
              code = "VALIDATION_FAILED", details = list(field = "byte order"))
  }
  header_offset <- num("header offset", default = 0)
  wavelength <- vec("wavelength")
  fwhm <- vec("fwhm")
  band_names <- vec("band names", numeric = FALSE)
  for (spec in list(list("wavelength", wavelength), list("fwhm", fwhm),
                    list("band names", band_names))) {
    if (!is.null(spec[[2]]) && length(spec[[2]]) != n_bands) {
      .sg_abort(
        "ENVI {.field {spec[[1]]}} has {length(spec[[2]])} value{?s} for {n_bands} band{?s}.",
        code = "VALIDATION_FAILED", details = list(field = spec[[1]])
      )
    }
  }
  if (!is.null(wavelength) && anyDuplicated(wavelength)) {
    .sg_abort("ENVI wavelengths contain duplicates.",
              code = "VALIDATION_FAILED", details = list(field = "wavelength"))
  }
  units <- tolower(fields[["wavelength units"]] %||% "unknown")
  if (!is.null(wavelength)) {
    if (units %in% c("micrometers", "um", "microns")) {
      wavelength <- wavelength * 1000
      if (!is.null(fwhm)) fwhm <- fwhm * 1000
    } else if (!units %in% c("nanometers", "nm", "unknown")) {
      .sg_abort("Unsupported ENVI wavelength units {.val {units}}.",
                code = "VALIDATION_FAILED",
                details = list(field = "wavelength units"))
    }
  }
  expected <- header_offset + samples * n_lines * n_bands * type$size
  present <- file.info(paths$data)$size
  structure(list(
    samples = as.integer(samples), lines = as.integer(n_lines),
    bands = as.integer(n_bands), interleave = interleave,
    byte_order = as.integer(byte_order), data_type = as.integer(data_type),
    dtype = type$dtype, header_offset = header_offset,
    wavelength_nm = wavelength, fwhm_nm = fwhm,
    wavelength_units = units, band_names = band_names,
    nodata = num("data ignore value"),
    scale_factor = num("reflectance scale factor"),
    gain = vec("data gain values"), offset = vec("data offset values"),
    data_bytes_expected = expected, data_bytes_present = present,
    header_digest = paste0("sha256:", .sg_sha256_file(paths$header)),
    data_name = basename(paths$data)
  ), class = "sg_envi_info")
}

#' @noRd
.sg_envi_paths <- function(path, data_file = NULL) {
  if (!file.exists(path)) {
    .sg_abort("ENVI file not found.", class = "sg_integrity_error",
              code = "INTEGRITY_MISMATCH")
  }
  if (grepl("\\.hdr$", path, ignore.case = TRUE)) {
    header <- path
    base <- sub("\\.hdr$", "", path, ignore.case = TRUE)
    candidates <- c(base, paste0(base, c(".img", ".dat", ".raw", ".bsq",
                                         ".bil", ".bip")))
  } else {
    base <- sub("\\.[^./]*$", "", path)
    header <- c(paste0(path, ".hdr"), paste0(base, ".hdr"))
    header <- header[file.exists(header)][1]
    candidates <- path
  }
  if (is.na(header) || !file.exists(header)) {
    .sg_abort("ENVI header (.hdr) not found next to the data file.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  data <- data_file %||% candidates[file.exists(candidates) &
                                      !dir.exists(candidates)][1]
  if (is.null(data) || is.na(data) || !file.exists(data)) {
    .sg_abort("ENVI data file not found next to the header.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  list(header = header, data = data)
}

#' Read an ENVI cube window into an sg_image
#'
#' Reads only the requested bands and pixel window by seeking in the data
#' file (BSQ, BIL or BIP; either byte order). Values are returned as stored:
#' gain, offset and reflectance scale factors are recorded but never applied,
#' and `value_semantics` is whatever the caller declares (default
#' `"unknown"`), so raw counts, reflectance, radiance, intensity and
#' absorbance are never mixed silently.
#'
#' @param path Path to the `.hdr` file or the data file.
#' @param bands Optional 1-based band indices to read (default all).
#' @param window Optional `c(row_min, row_max, col_min, col_max)` (1-based,
#'   inclusive).
#' @param value_semantics Declared meaning of the stored values.
#' @param nodata_to_na Replace the header `data ignore value` by `NA`.
#' @param source_digest `"full"` hashes header and data file (identity of
#'   the source), `"header"` hashes only the header, `"none"` skips hashing.
#' @param data_file Optional explicit data file path.
#'
#' @return An `sg_image` with pixels `[y, x, band]`, a band table,
#'   `origin` set to the window offset, `calibration_digest`, and
#'   `metadata$read_accounting` (`bytes_read`, `bands_read`).
#' @export
#' @examples
#' d <- tempfile("envi")
#' dir.create(d)
#' writeLines(c("ENVI", "samples = 3", "lines = 2", "bands = 2",
#'              "data type = 12", "interleave = bip", "byte order = 0",
#'              "wavelength = {500, 600}"), file.path(d, "cube.hdr"))
#' writeBin(1:12, file.path(d, "cube"), size = 2L, endian = "little")
#' img <- sg_read_envi(file.path(d, "cube.hdr"), bands = 2,
#'                     value_semantics = "raw")
#' img$pixels
sg_read_envi <- function(path, bands = NULL, window = NULL,
                         value_semantics = "unknown", nodata_to_na = TRUE,
                         source_digest = c("full", "header", "none"),
                         data_file = NULL) {
  value_semantics <- match.arg(value_semantics, .sg_value_semantics)
  source_digest <- match.arg(source_digest)
  info <- sg_envi_info(path, data_file)
  paths <- .sg_envi_paths(path, data_file)
  if (info$data_bytes_present < info$data_bytes_expected) {
    .sg_abort(
      "ENVI data file is shorter than the header declares ({info$data_bytes_present} < {info$data_bytes_expected} bytes).",
      class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
      details = list(expected = info$data_bytes_expected,
                     present = info$data_bytes_present)
    )
  }
  bands <- as.integer(bands %||% seq_len(info$bands))
  if (anyNA(bands) || any(bands < 1L) || any(bands > info$bands) ||
      anyDuplicated(bands)) {
    .sg_abort("{.arg bands} must be unique indices in 1..{info$bands}.",
              code = "VALIDATION_FAILED")
  }
  window <- as.integer(window %||% c(1L, info$lines, 1L, info$samples))
  if (length(window) != 4L || anyNA(window) || window[1] < 1L ||
      window[2] > info$lines || window[1] > window[2] || window[3] < 1L ||
      window[4] > info$samples || window[3] > window[4]) {
    .sg_abort("{.arg window} must be c(row_min, row_max, col_min, col_max) inside the cube.",
              code = "VALIDATION_FAILED")
  }
  type <- .sg_envi_types[[as.character(info$data_type)]]
  endian <- if (info$byte_order == 1L) "big" else "little"
  rows <- window[1]:window[2]
  cols <- window[3]:window[4]
  nr <- length(rows)
  nc <- length(cols)
  s <- info$samples
  l <- info$lines
  nb <- info$bands
  sz <- type$size
  out <- array(NA_real_, dim = c(nr, nc, length(bands)))
  bytes_read <- 0
  con <- file(paths$data, open = "rb")
  on.exit(close(con))
  decode <- function(raw_vals, n) {
    if (type$what == "double") {
      return(readBin(raw_vals, "double", n = n, size = sz, endian = endian))
    }
    v <- readBin(raw_vals, "integer", n = n, size = sz,
                 signed = type$signed || sz == 4L, endian = endian)
    if (!type$signed && sz == 4L) v <- ifelse(v < 0, v + 4294967296, v)
    v
  }
  read_at <- function(offset, n_values) {
    seek(con, info$header_offset + offset * sz)
    r <- readBin(con, "raw", n_values * sz)
    bytes_read <<- bytes_read + length(r)
    decode(r, n_values)
  }
  for (ri in seq_along(rows)) {
    r <- rows[ri] - 1
    if (info$interleave == "bip") {
      vals <- read_at(r * s * nb + (cols[1] - 1) * nb, nc * nb)
      m <- matrix(vals, nrow = nb)
      out[ri, , ] <- t(m[bands, , drop = FALSE])
    } else {
      for (bi in seq_along(bands)) {
        b <- bands[bi] - 1
        off <- if (info$interleave == "bsq") {
          b * l * s + r * s + (cols[1] - 1)
        } else {
          r * nb * s + b * s + (cols[1] - 1)
        }
        out[ri, , bi] <- read_at(off, nc)
      }
    }
  }
  n_nodata <- 0L
  if (nodata_to_na && !is.null(info$nodata)) {
    hit <- !is.na(out) & out == info$nodata
    n_nodata <- sum(hit)
    out[hit] <- NA_real_
  }
  if (length(bands) == 1L) out <- out[, , 1]
  band_names <- info$band_names %||% paste0("band_", seq_len(nb))
  band_tbl <- tibble::tibble(
    name = band_names[bands],
    wavelength_nm = if (is.null(info$wavelength_nm)) NA_real_ else
      info$wavelength_nm[bands],
    fwhm_nm = if (is.null(info$fwhm_nm)) NA_real_ else info$fwhm_nm[bands]
  )
  digest <- switch(
    source_digest,
    full = .sg_digest_json(list(
      header = info$header_digest,
      data = paste0("sha256:", .sg_sha256_file(paths$data))
    )),
    header = info$header_digest,
    none = NULL
  )
  calibration <- .sg_digest_json(list(
    data_type = info$data_type, byte_order = info$byte_order,
    wavelength_nm = I(info$wavelength_nm %||% numeric(0)),
    fwhm_nm = I(info$fwhm_nm %||% numeric(0)),
    wavelength_units = info$wavelength_units,
    scale_factor = info$scale_factor, gain = I(info$gain %||% numeric(0)),
    offset = I(info$offset %||% numeric(0)), nodata = info$nodata
  ))
  img <- new_sg_image(
    out, channels = band_names[bands],
    metadata = list(
      source_name = info$data_name, format = "envi",
      interleave = info$interleave, dtype = info$dtype,
      byte_order = endian, scale_factor = info$scale_factor,
      gain = info$gain, offset = info$offset, nodata = info$nodata,
      nodata_pixels = as.integer(n_nodata), calibration_digest = calibration,
      read_accounting = list(bytes_read = as.integer(bytes_read),
                             bands_read = as.integer(bands - 1L),
                             format = "envi")
    ),
    origin = list(x = window[3] - 1, y = window[1] - 1, downsample = 1),
    bands = band_tbl, value_semantics = value_semantics,
    source_digest = digest
  )
  img
}

#' @export
print.sg_envi_info <- function(x, ...) {
  cli::cli_text("{.cls sg_envi_info}: {x$lines} x {x$samples} x {x$bands} ({x$interleave}, {x$dtype}, {if (x$byte_order == 1L) 'big' else 'little'}-endian)")
  if (!is.null(x$wavelength_nm)) {
    cli::cli_text("Wavelengths: {min(x$wavelength_nm)}-{max(x$wavelength_nm)} nm")
  }
  invisible(x)
}
