# Minimal baseline TIFF reader/writer for exact integer label masks and raw
# image planes. Writing is always uncompressed little-endian classic TIFF,
# one strip per page. Reading parses the IFDs directly (dtype, sample
# format, description) and decodes uncompressed strips itself; compressed
# files are decoded through the optional 'tiff' package.

.sg_tiff_types <- list(
  uint8 = list(bits = 8L, fmt = 1L, what = "integer", size = 1L,
               signed = FALSE),
  uint16 = list(bits = 16L, fmt = 1L, what = "integer", size = 2L,
                signed = FALSE),
  uint32 = list(bits = 32L, fmt = 1L, what = "double", size = 4L,
                signed = FALSE),
  int32 = list(bits = 32L, fmt = 2L, what = "integer", size = 4L,
               signed = TRUE),
  float32 = list(bits = 32L, fmt = 3L, what = "double", size = 4L,
                 signed = TRUE),
  float64 = list(bits = 64L, fmt = 3L, what = "double", size = 8L,
                 signed = TRUE)
)

#' Write a 2D matrix or y-x-channel array as a baseline TIFF
#'
#' Channels are written as separate pages (planes).
#' @param description Optional ImageDescription (e.g. OME-XML), first page.
#' @noRd
.sg_write_tiff <- function(x, path, dtype = NULL, description = NULL) {
  d <- dim(x)
  if (is.null(d) || !length(d) %in% c(2L, 3L)) {
    .sg_abort("TIFF writer needs a matrix or a [y, x, channel] array.",
              code = "DIMENSION_MISMATCH")
  }
  if (length(d) == 2L) x <- array(x, dim = c(d, 1L))
  h <- dim(x)[1]
  w <- dim(x)[2]
  n_pages <- dim(x)[3]
  dtype <- dtype %||% if (is.integer(x)) .sg_label_dtype(x) else "float32"
  spec <- .sg_tiff_types[[dtype]]
  if (is.null(spec)) {
    .sg_abort("Unsupported TIFF dtype {.val {dtype}}.",
              code = "DTYPE_MISMATCH")
  }
  if (spec$fmt %in% c(1L, 2L)) {
    vals <- x[is.finite(x)]
    if (length(vals) && any(vals != trunc(vals))) {
      .sg_abort("Integer TIFF output requires integer values.",
                code = "DTYPE_MISMATCH")
    }
    lim <- switch(dtype, uint8 = c(0, 255), uint16 = c(0, 65535),
                  uint32 = c(0, 4294967295), int32 = c(-2147483648,
                                                       2147483647))
    if (anyNA(x) || (length(vals) && (min(vals) < lim[1] ||
                                        max(vals) > lim[2]))) {
      .sg_abort("Values do not fit into {.val {dtype}}.",
                code = "DTYPE_MISMATCH")
    }
  }
  bytes_per_page <- as.numeric(h) * w * spec$size
  if (bytes_per_page * n_pages > 3.5e9) {
    .sg_abort("Image too large for classic TIFF output.",
              class = "sg_validation_error", code = "PAYLOAD_TOO_LARGE")
  }

  con <- file(path, open = "wb")
  on.exit(close(con))
  w16 <- function(v) writeBin(as.integer(v), con, size = 2L,
                              endian = "little")
  w32 <- function(v) {
    v <- as.numeric(v)
    lo <- v %% 65536
    hi <- (v - lo) / 65536
    lo <- ifelse(lo > 32767, lo - 65536, lo)
    hi <- ifelse(hi > 32767, hi - 65536, hi)
    writeBin(as.integer(rbind(lo, hi)), con, size = 2L, endian = "little")
  }
  writeBin(charToRaw("II"), con)
  w16(42L)
  desc_raw <- if (!is.null(description)) {
    c(charToRaw(enc2utf8(description)), as.raw(0))
  } else {
    raw(0)
  }
  n_tags_first <- if (length(desc_raw)) 11L else 10L
  ifd_size <- function(n_tags) 2 + 12 * n_tags + 4
  # Layout: header(8) | per page: [desc] pixel data, IFD
  offset <- 8
  pages <- vector("list", n_pages)
  for (p in seq_len(n_pages)) {
    has_desc <- p == 1L && length(desc_raw) > 0L
    desc_off <- if (has_desc) offset else NA
    if (has_desc) offset <- offset + length(desc_raw)
    data_off <- offset
    offset <- offset + bytes_per_page
    if (offset %% 2 == 1) offset <- offset + 1
    ifd_off <- offset
    n_tags <- if (has_desc) n_tags_first else 10L
    offset <- offset + ifd_size(n_tags)
    pages[[p]] <- list(desc_off = desc_off, data_off = data_off,
                       ifd_off = ifd_off, n_tags = n_tags)
  }
  w32(pages[[1]]$ifd_off)
  pos <- 8
  for (p in seq_len(n_pages)) {
    pg <- pages[[p]]
    if (!is.na(pg$desc_off)) {
      writeBin(desc_raw, con)
      pos <- pos + length(desc_raw)
    }
    plane <- as.vector(t(x[, , p]))
    if (dtype == "uint32") {
      w32(plane)
    } else if (spec$fmt == 3L) {
      writeBin(as.double(plane), con, size = spec$size, endian = "little")
    } else {
      writeBin(as.integer(plane), con, size = spec$size, endian = "little")
    }
    pos <- pos + bytes_per_page
    if (pos %% 2 == 1) {
      writeBin(as.raw(0), con)
      pos <- pos + 1
    }
    next_ifd <- if (p < n_pages) pages[[p + 1L]]$ifd_off else 0
    tag <- function(id, type, count, value) {
      w16(id)
      w16(type)
      w32(count)
      if (type == 3L) {
        w16(value)
        w16(0L)
      } else {
        w32(value)
      }
    }
    w16(pg$n_tags)
    tag(256L, 4L, 1, w)
    tag(257L, 4L, 1, h)
    tag(258L, 3L, 1, spec$bits)
    tag(259L, 3L, 1, 1L)
    tag(262L, 3L, 1, 1L)
    if (!is.na(pg$desc_off)) tag(270L, 2L, length(desc_raw), pg$desc_off)
    tag(273L, 4L, 1, pg$data_off)
    tag(277L, 3L, 1, 1L)
    tag(278L, 4L, 1, h)
    tag(279L, 4L, 1, bytes_per_page)
    tag(339L, 3L, 1, spec$fmt)
    w32(next_ifd)
    pos <- pos + ifd_size(pg$n_tags)
  }
  invisible(path)
}

#' Parse TIFF IFDs (classic TIFF, either byte order)
#' @return List of pages with tag values.
#' @noRd
.sg_tiff_ifds <- function(path, max_pages = 4096L) {
  size <- file.info(path)$size
  con <- file(path, open = "rb")
  on.exit(close(con))
  hdr <- readBin(con, "raw", 4L)
  if (length(hdr) < 4L) {
    .sg_abort("File is not a TIFF (too short).",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  endian <- if (identical(hdr[1:2], charToRaw("II"))) {
    "little"
  } else if (identical(hdr[1:2], charToRaw("MM"))) {
    "big"
  } else {
    .sg_abort("File is not a TIFF (bad byte-order mark).",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  magic <- readBin(hdr[3:4], "integer", size = 2L, signed = FALSE,
                   endian = endian)
  if (magic != 42L) {
    .sg_abort("Only classic TIFF files are supported (BigTIFF found).",
              class = "sg_capability_error", code = "CAPABILITY_UNAVAILABLE")
  }
  r_u16 <- function(n = 1L) readBin(con, "integer", n = n, size = 2L,
                                    signed = FALSE, endian = endian)
  r_u32 <- function(n = 1L) {
    v <- readBin(con, "integer", n = n, size = 4L, endian = endian)
    ifelse(v < 0, v + 4294967296, v)
  }
  type_size <- c(`1` = 1, `2` = 1, `3` = 2, `4` = 4, `5` = 8, `6` = 1,
                 `7` = 1, `8` = 2, `9` = 4, `10` = 8, `11` = 4, `12` = 8)
  read_values <- function(type, count, value_field_pos) {
    tkey <- as.character(type)
    sz <- if (tkey %in% names(type_size)) type_size[[tkey]] else 1
    total <- sz * count
    here <- seek(con)
    if (total > 4) {
      seek(con, value_field_pos)
      off <- r_u32()
      if (off + total > size) return(NULL)
      seek(con, off)
    } else {
      seek(con, value_field_pos)
    }
    vals <- switch(
      as.character(type),
      `2` = {
        r <- readBin(con, "raw", count)
        rawToChar(r[r != as.raw(0)])
      },
      `3` = r_u16(count),
      `4` = r_u32(count),
      `5` = {
        v <- r_u32(2 * count)
        v[c(TRUE, FALSE)] / v[c(FALSE, TRUE)]
      },
      readBin(con, "raw", total)
    )
    seek(con, here)
    vals
  }
  seek(con, 4)
  next_off <- r_u32()
  if (length(next_off) != 1L) {
    .sg_abort("Corrupt TIFF: missing first image file directory offset.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  pages <- list()
  while (next_off > 0 && length(pages) < max_pages) {
    if (next_off + 2 > size) {
      .sg_abort("Corrupt TIFF: IFD offset beyond end of file.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    seek(con, next_off)
    n <- r_u16()
    if (length(n) != 1L || next_off + 2 + 12 * n + 4 > size) {
      .sg_abort("Corrupt TIFF: truncated image file directory.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    tags <- list()
    for (i in seq_len(n)) {
      entry_pos <- next_off + 2 + 12 * (i - 1)
      seek(con, entry_pos)
      id <- r_u16()
      type <- r_u16()
      count <- r_u32()
      tags[[as.character(id)]] <- tryCatch(
        read_values(type, count, entry_pos + 8),
        error = function(e) NULL
      )
    }
    seek(con, next_off + 2 + 12 * n)
    next_off <- r_u32()
    if (length(next_off) != 1L) {
      .sg_abort("Corrupt TIFF: truncated image file directory chain.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    pages[[length(pages) + 1L]] <- tags
  }
  list(endian = endian, pages = pages, size = size)
}

#' Read a TIFF into an array with dtype information
#' @return List: `data` (y-x matrix or y-x-page array), `dtype`,
#'   `description`, `compression`, `n_pages`, `samples_per_pixel`.
#' @noRd
.sg_read_tiff <- function(path) {
  info <- .sg_tiff_ifds(path)
  if (length(info$pages) == 0L) {
    .sg_abort("TIFF contains no image.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  p1 <- info$pages[[1]]
  width <- p1[["256"]]
  height <- p1[["257"]]
  bits <- p1[["258"]][1] %||% 1
  comp <- p1[["259"]] %||% 1
  spp <- p1[["277"]] %||% 1
  fmt <- p1[["339"]][1] %||% 1
  desc <- p1[["270"]]
  if (is.null(width) || is.null(height)) {
    .sg_abort("TIFF is missing its dimensions.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  dtype <- if (fmt == 3) {
    if (bits == 64) "float64" else "float32"
  } else if (fmt == 2) {
    paste0("int", bits)
  } else {
    paste0("uint", bits)
  }
  same_shape <- vapply(info$pages, function(p) {
    identical(p[["256"]], width) && identical(p[["257"]], height)
  }, logical(1))
  n_pages <- sum(same_shape)
  planes <- vector("list", n_pages)
  planar <- p1[["284"]] %||% 1
  if (comp == 1 && spp > 1 && planar == 1 && bits %in% c(8, 16, 32, 64)) {
    # Chunky (interleaved) samples of the first page: [y, x, sample]
    con <- file(path, open = "rb")
    on.exit(close(con))
    size_b <- bits / 8
    offs <- p1[["273"]]
    counts <- p1[["279"]]
    n_val <- width * height * spp
    if (is.null(offs) || is.null(counts) || sum(counts) < n_val * size_b ||
        any(offs + counts > info$size)) {
      .sg_abort("Corrupt TIFF: pixel data is truncated.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    buf <- unlist(lapply(seq_along(offs), function(i) {
      seek(con, offs[i])
      readBin(con, "raw", counts[i])
    }))[seq_len(n_val * size_b)]
    vals <- if (fmt == 3) {
      readBin(buf, "double", n = n_val, size = size_b, endian = info$endian)
    } else {
      v <- readBin(buf, "integer", n = n_val, size = size_b,
                   signed = fmt == 2 || size_b == 4, endian = info$endian)
      if (bits == 32 && fmt == 1) v <- ifelse(v < 0, v + 4294967296, v)
      v
    }
    data <- aperm(array(vals, dim = c(spp, width, height)), c(3L, 2L, 1L))
    return(list(data = data, dtype = dtype, description = desc,
                compression = comp, n_pages = 1L, samples_per_pixel = spp,
                endian = info$endian))
  }
  if (comp == 1 && spp == 1 && bits %in% c(8, 16, 32, 64)) {
    con <- file(path, open = "rb")
    on.exit(close(con))
    size_b <- bits / 8
    for (k in seq_len(n_pages)) {
      p <- info$pages[which(same_shape)[k]]
      p <- p[[1]]
      offs <- p[["273"]]
      counts <- p[["279"]]
      need <- width * height * size_b
      if (is.null(offs) || is.null(counts) || sum(counts) < need ||
          any(offs + counts > info$size)) {
        .sg_abort("Corrupt TIFF: pixel data is truncated.",
                  class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
      }
      buf <- unlist(lapply(seq_along(offs), function(i) {
        seek(con, offs[i])
        readBin(con, "raw", counts[i])
      }))[seq_len(need)]
      vals <- if (fmt == 3) {
        readBin(buf, "double", n = width * height, size = size_b,
                endian = info$endian)
      } else if (bits == 32 && fmt == 1) {
        v <- readBin(buf, "integer", n = width * height, size = 4L,
                     endian = info$endian)
        ifelse(v < 0, v + 4294967296, v)
      } else if (bits == 64) {
        .sg_abort("64-bit integer TIFF is not supported.",
                  code = "DTYPE_MISMATCH")
      } else {
        readBin(buf, "integer", n = width * height, size = size_b,
                signed = fmt == 2 || size_b == 4, endian = info$endian)
      }
      planes[[k]] <- matrix(vals, nrow = height, ncol = width, byrow = TRUE)
    }
  } else {
    if (!requireNamespace("tiff", quietly = TRUE)) {
      .sg_abort_unavailable(
        "Reading compressed or multi-sample TIFF",
        "Install the {.pkg tiff} package."
      )
    }
    if (fmt == 2) {
      .sg_abort("Signed compressed TIFF masks are not supported.",
                code = "DTYPE_MISMATCH")
    }
    pg <- tiff::readTIFF(path, as.is = TRUE, all = TRUE)
    pg <- pg[seq_len(min(length(pg), n_pages))]
    planes <- lapply(pg, function(a) {
      if (length(dim(a)) == 3L) a[, , 1] else a
    })
    if (spp > 1) {
      first <- pg[[1]]
      planes <- lapply(seq_len(dim(first)[3]), function(k) first[, , k])
    }
  }
  data <- if (length(planes) == 1L) {
    planes[[1]]
  } else {
    array(unlist(planes), dim = c(height, width, length(planes)))
  }
  list(data = data, dtype = dtype, description = desc,
       compression = comp, n_pages = length(planes),
       samples_per_pixel = spp, endian = info$endian)
}

#' Minimal OME-XML description for a y-x-channel plane stack
#' @noRd
.sg_ome_xml <- function(shape_yx, n_c, dtype, pixel_size = NULL,
                        channels = NULL, name = "segmantR") {
  esc <- function(s) {
    s <- gsub("&", "&amp;", s, fixed = TRUE)
    s <- gsub("<", "&lt;", s, fixed = TRUE)
    s <- gsub(">", "&gt;", s, fixed = TRUE)
    gsub("\"", "&quot;", s, fixed = TRUE)
  }
  ome_type <- switch(dtype, float32 = "float", float64 = "double", dtype)
  ps <- ""
  if (!is.null(pixel_size) && is.finite(pixel_size$x %||% NA) &&
      is.finite(pixel_size$y %||% NA)) {
    ps <- sprintf(paste0(" PhysicalSizeX=\"%s\" PhysicalSizeXUnit=\"\u00b5m\"",
                         " PhysicalSizeY=\"%s\" PhysicalSizeYUnit=\"\u00b5m\""),
                  .sg_json_number(pixel_size$x), .sg_json_number(pixel_size$y))
  }
  channels <- channels %||% paste0("ch", seq_len(n_c))
  ch <- paste(vapply(seq_len(n_c), function(k) {
    sprintf('<Channel ID="Channel:0:%d" Name="%s" SamplesPerPixel="1"/>',
            k - 1L, esc(channels[k]))
  }, character(1)), collapse = "")
  td <- paste(vapply(seq_len(n_c), function(k) {
    sprintf('<TiffData FirstC="%d" FirstT="0" FirstZ="0" IFD="%d" PlaneCount="1"/>',
            k - 1L, k - 1L)
  }, character(1)), collapse = "")
  paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<OME xmlns="http://www.openmicroscopy.org/Schemas/OME/2016-06" ',
    'Creator="segmantR">',
    sprintf('<Image ID="Image:0" Name="%s">', esc(name)),
    sprintf(paste0('<Pixels ID="Pixels:0" DimensionOrder="XYCZT" Type="%s" ',
                   'SizeX="%d" SizeY="%d" SizeC="%d" SizeZ="1" SizeT="1"%s>'),
            ome_type, as.integer(shape_yx[2]), as.integer(shape_yx[1]),
            as.integer(n_c), ps),
    ch, td, "</Pixels></Image></OME>"
  )
}
