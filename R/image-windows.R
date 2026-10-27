# Windowed reading of single channels from large multi-page microscopy TIFFs
# ((Q)PTIFF, OME-TIFF, plain multi-page TIFF) through GDAL ('sf'), without
# loading whole planes, plus display-range helpers for fluorescence images.
#
# Pixel convention: x0 and y0 are 0-based column and row offsets of the
# top-left pixel (the convention of most imaging code); returned matrices are
# [row, column] = [y, x]. Pixels outside the image are filled with `fill`.

.sg_window_cache <- new.env(parent = emptyenv())

#' List the channels of a multi-page microscopy TIFF
#'
#' Reads the directory structure of a (Q)PTIFF, OME-TIFF or plain multi-page
#' TIFF through GDAL and returns one row per full-resolution channel plane.
#' Channel names come from the per-plane image description (`<Biomarker>`,
#' then `<Name>`, as written by PhenoCycler/Vectra QPTIFF files), from the
#' `Channel Name` attributes of OME-XML on the first plane, or default to
#' `ch1`, `ch2`, .... Reduced-resolution pages (overviews, thumbnails, label
#' and macro images) are left out: a plane belongs to the channel set when it
#' has one band and the size of the first plane.
#'
#' @param path Path to the image file.
#' @return A data frame with columns `channel` (1-based channel number),
#'   `name`, `directory` (1-based TIFF directory), `width`, `height`,
#'   `block_width`, `block_height`, `datatype` and `dsn` (the GDAL dataset
#'   name of the plane).
#' @seealso [sg_read_window()], [sg_read_field()]
#' @export
#' @examples
#' \donttest{
#' f <- tempfile(fileext = ".tif")
#' segmantR:::.sg_write_tiff(array(1:24, c(3, 4, 2)), f, dtype = "uint8")
#' sg_image_channels(f)
#' }
sg_image_channels <- function(path) {
  path <- .sg_window_path(path)
  info <- file.info(path)
  key <- paste(path, info$size, as.numeric(info$mtime), sep = "|")
  if (!is.null(.sg_window_cache[[key]])) return(.sg_window_cache[[key]])
  subs <- tryCatch(unlist(sf::gdal_subdatasets(path)), error = function(e) character(0))
  dsn <- if (length(subs)) unname(subs) else path
  meta <- lapply(dsn, .sg_gdal_meta)
  first <- meta[[1]]
  keep <- vapply(meta, function(m) {
    m$bands == 1L && m$width == first$width && m$height == first$height
  }, logical(1))
  dirs <- if (length(subs)) {
    as.integer(sub("^GTIFF_DIR:([0-9]+):.*$", "\\1", dsn))
  } else {
    1L
  }
  meta <- meta[keep]
  names <- vapply(meta, function(m) .sg_plane_name(m$description), character(1))
  if (anyNA(names)) {
    ome <- .sg_ome_channel_names(first$description)
    names <- if (length(ome) == length(meta)) ome else paste0("ch", seq_along(meta))
  }
  out <- data.frame(
    channel = seq_along(meta),
    name = names,
    directory = dirs[keep],
    width = vapply(meta, `[[`, numeric(1), "width"),
    height = vapply(meta, `[[`, numeric(1), "height"),
    block_width = vapply(meta, `[[`, numeric(1), "block_width"),
    block_height = vapply(meta, `[[`, numeric(1), "block_height"),
    datatype = vapply(meta, `[[`, character(1), "datatype"),
    dsn = dsn[keep],
    stringsAsFactors = FALSE
  )
  assign(key, out, envir = .sg_window_cache)
  out
}

#' Read a rectangular pixel window of one channel
#'
#' Reads `height` rows and `width` columns of one channel plane starting at
#' the 0-based pixel offset (`x0`, `y0`). Only the image blocks that cover the
#' window are decoded, so windows of very large whole-slide files are cheap.
#' Parts of the window outside the image are filled with `fill`, which makes
#' fields at the slide edge keep their nominal size.
#'
#' @param path Path to the image file.
#' @param channel Channel number (as in [sg_image_channels()]) or channel
#'   name.
#' @param x0,y0 0-based column and row of the top-left pixel; may be negative.
#' @param width,height Window size in pixels.
#' @param fill Value used outside the image.
#' @return A numeric matrix with `height` rows and `width` columns
#'   (`[y, x]`), with attributes `x0`, `y0` and `channel` (the name).
#' @seealso [sg_read_field()], [sg_image_channels()]
#' @export
#' @examples
#' \donttest{
#' f <- tempfile(fileext = ".tif")
#' plane <- matrix(0:11, nrow = 3, byrow = TRUE)
#' segmantR:::.sg_write_tiff(plane, f, dtype = "uint8")
#' sg_read_window(f, 1, x0 = 1, y0 = 0, width = 2, height = 2)
#' }
sg_read_window <- function(path, channel, x0, y0, width, height = width, fill = 0) {
  ch <- .sg_window_channel(path, channel)
  for (v in list(x0, y0, width, height)) {
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v != round(v)) {
      .sg_abort("Window offsets and sizes must be single whole numbers.",
                code = "PARAMETER_OUT_OF_RANGE")
    }
  }
  if (width < 1 || height < 1) {
    .sg_abort("Window width and height must be positive.", code = "PARAMETER_OUT_OF_RANGE")
  }
  out <- matrix(as.numeric(fill), nrow = height, ncol = width)
  xs <- max(x0, 0)
  ys <- max(y0, 0)
  xe <- min(x0 + width, ch$width)
  ye <- min(y0 + height, ch$height)
  if (xe > xs && ye > ys) {
    r <- sf::gdal_read(ch$dsn, options = character(), driver = character(), read_data = TRUE,
                       NA_value = NA_real_,
                       RasterIO_parameters = list(nXOff = xs + 1, nYOff = ys + 1,
                                                  nXSize = xe - xs, nYSize = ye - ys))
    v <- attr(r, "data")
    v <- matrix(as.numeric(v), nrow = xe - xs, ncol = ye - ys)
    out[(ys - y0) + seq_len(ye - ys), (xs - x0) + seq_len(xe - xs)] <- t(v)
  }
  attr(out, "x0") <- x0
  attr(out, "y0") <- y0
  attr(out, "channel") <- ch$name
  out
}

#' Read a square multichannel field around a point
#'
#' Converts a centre in physical units (for example micrometres) to pixels
#' and reads a square window of `round(size / pixel_size)` pixels in each
#' requested channel. The top-left pixel is
#' `round(centre / pixel_size) - n %/% 2`, so a field is reproducible from
#' its centre, size and pixel size alone.
#'
#' @param path Path to the image file.
#' @param channels Channel names or numbers.
#' @param centre Numeric `c(x, y)` in physical units, or a data frame whose
#'   first row has columns `x` and `y`.
#' @param size Field width in physical units.
#' @param pixel_size Physical size of one pixel.
#' @param fill Value used outside the image.
#' @return A list of class `sg_field` with `channels` (named list of
#'   `n` x `n` matrices), `x0`, `y0`, `n`, `pixel_size`, `centre`, `size` and
#'   `extent` (`c(xmin, xmax, ymin, ymax)` of the pixel edges in physical
#'   units).
#' @seealso [sg_read_fields()], [sg_read_window()]
#' @export
#' @examples
#' \donttest{
#' f <- tempfile(fileext = ".tif")
#' segmantR:::.sg_write_tiff(array(1:200, c(10, 10, 2)), f, dtype = "uint8")
#' fld <- sg_read_field(f, c("ch1", "ch2"), centre = c(2.5, 2.5), size = 2, pixel_size = 0.5)
#' fld$channels$ch2
#' }
sg_read_field <- function(path, channels, centre, size, pixel_size = 1, fill = 0) {
  if (is.data.frame(centre)) centre <- c(centre$x[1], centre$y[1])
  if (is.list(centre)) centre <- unlist(centre)
  if (!is.numeric(centre) || length(centre) != 2L || anyNA(centre)) {
    .sg_abort("centre must be c(x, y).", code = "PARAMETER_OUT_OF_RANGE")
  }
  if (!is.numeric(size) || length(size) != 1L || size <= 0 ||
      !is.numeric(pixel_size) || length(pixel_size) != 1L || pixel_size <= 0) {
    .sg_abort("size and pixel_size must be positive numbers.", code = "PARAMETER_OUT_OF_RANGE")
  }
  n <- round(size / pixel_size)
  x0 <- round(centre[[1]] / pixel_size) - n %/% 2
  y0 <- round(centre[[2]] / pixel_size) - n %/% 2
  planes <- lapply(channels, function(ch) {
    m <- sg_read_window(path, ch, x0, y0, n, n, fill = fill)
    attributes(m) <- list(dim = dim(m))
    m
  })
  names(planes) <- vapply(channels, function(ch) .sg_window_channel(path, ch)$name, character(1))
  structure(list(channels = planes, x0 = x0, y0 = y0, n = n, pixel_size = pixel_size,
                 centre = as.numeric(centre), size = size,
                 extent = c(x0, x0 + n, y0, y0 + n) * pixel_size),
            class = "sg_field")
}

#' Read many square fields, for example cell galleries
#'
#' Reads one [sg_read_field()] per row of a table of centres. Each row names
#' its image through `source`, looked up in `paths`.
#'
#' @param centres Data frame with centre coordinates and the image key.
#' @param paths Named character vector or list: image key to file path, or
#'   a single path used for all rows when `source` is `NULL`.
#' @param channels Channel names or numbers read for every field.
#' @param size,pixel_size,fill As in [sg_read_field()].
#' @param x,y,source Column names of the centre coordinates and image key.
#' @param id Optional column used to name the fields.
#' @param channel_columns Optional columns of `centres` naming further
#'   channels to read for each row (for example a row-specific marker).
#' @param key_prefix Prefix added to the `source` values before looking them
#'   up in `paths`.
#' @return A named list of `sg_field` objects in row order; each carries the
#'   table row (as a one-row data frame) in `row`.
#' @seealso [sg_read_field()]
#' @export
sg_read_fields <- function(centres, paths, channels = character(0), size, pixel_size = 1, fill = 0,
                           x = "x", y = "y", source = NULL, id = NULL, channel_columns = NULL,
                           key_prefix = "") {
  if (!is.data.frame(centres)) .sg_abort("centres must be a data frame.")
  missing <- setdiff(c(x, y, source, id, channel_columns), names(centres))
  if (length(missing)) {
    .sg_abort("centres lacks column{?s} {.val {missing}}.", code = "VALIDATION_FAILED")
  }
  paths <- unlist(paths)
  if (is.null(source)) {
    if (length(paths) != 1L) {
      .sg_abort("Give source when several paths are supplied.", code = "VALIDATION_FAILED")
    }
    keys <- rep("1", nrow(centres))
    paths <- c(`1` = unname(paths))
  } else {
    keys <- paste0(key_prefix, as.character(centres[[source]]))
  }
  unknown <- setdiff(unique(keys), names(paths))
  if (length(unknown)) {
    .sg_abort("No image path for {.val {unknown}}.", code = "VALIDATION_FAILED")
  }
  out <- lapply(seq_len(nrow(centres)), function(i) {
    extra <- vapply(channel_columns, function(cl) as.character(centres[[cl]][i]), character(1))
    chs <- unique(c(unlist(channels), unname(extra)))
    f <- sg_read_field(paths[[keys[i]]], chs,
                       centre = c(centres[[x]][i], centres[[y]][i]),
                       size = size, pixel_size = pixel_size, fill = fill)
    f$row <- centres[i, , drop = FALSE]
    f
  })
  names(out) <- if (is.null(id)) as.character(seq_len(nrow(centres))) else as.character(centres[[id]])
  out
}

#' Display range of fluorescence values
#'
#' Percentile-based display (black and white) levels for a set of pixel
#' values, as used to scale fluorescence channels for viewing: `lo` is the
#' lower percentile (or a given value), `hi` the larger of the upper
#' percentile, an optional floor and `lo + min_span`. Percentiles use linear
#' interpolation between order statistics (`stats::quantile(type = 7)`).
#'
#' @param x Numeric pixel values (any shape).
#' @param probs Lower and upper probabilities; either may be `NA` when `lo`
#'   or `hi_floor` replace it.
#' @param lo Optional fixed lower level (replaces the lower percentile).
#' @param hi_floor Optional value the upper level must at least reach.
#' @param min_span Minimum distance between the two levels.
#' @return Named numeric `c(lo = , hi = )`.
#' @seealso [sg_slide_display_ranges()], [sg_display_levels()]
#' @export
#' @examples
#' sg_display_range(c(0, 1, 2, 3, 100))
#' sg_display_range(1:10, probs = c(NA, 0.995), lo = 2, hi_floor = 20)
sg_display_range <- function(x, probs = c(0.01, 0.997), lo = NULL, hi_floor = NULL, min_span = 1) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) .sg_abort("No finite values for a display range.", code = "VALIDATION_FAILED")
  if (length(probs) != 2L) .sg_abort("probs must have two entries.", code = "PARAMETER_OUT_OF_RANGE")
  if (is.null(lo)) {
    if (is.na(probs[1])) .sg_abort("Give lo or a lower probability.", code = "PARAMETER_OUT_OF_RANGE")
    lo <- stats::quantile(x, probs[1], names = FALSE, type = 7)
  }
  hi <- c(if (!is.na(probs[2])) stats::quantile(x, probs[2], names = FALSE, type = 7), hi_floor,
          lo + min_span)
  c(lo = lo, hi = max(hi))
}

#' Slide-wide display ranges from sampled image blocks
#'
#' Estimates fixed per-channel display ranges for a whole slide from a sample
#' of the image blocks (tiles) that contain cells: `n_cells` cell positions
#' are drawn, their storage blocks collected, `n_tiles` of these blocks drawn,
#' every `step`-th pixel in both directions taken, and [sg_display_range()]
#' applied per channel. Tiles follow the block grid of the file, so the
#' estimate reads few blocks even for very large scans.
#'
#' @param path Path to the image file.
#' @param channels Channel names or numbers.
#' @param cells Data frame of cell positions in physical units.
#' @param x,y Column names of the positions.
#' @param pixel_size Physical size of one pixel.
#' @param n_cells,n_tiles Numbers of cells and tiles drawn.
#' @param step Pixel subsampling step inside each tile.
#' @param probs,min_span Passed to [sg_display_range()].
#' @param seed Random seed for the draws (the global RNG state is restored).
#' @param source Optional label stored in a `source` column (for example the
#'   image name), so that ranges of several images can be stacked.
#' @return A data frame with columns `channel`, `lo`, `hi`, `tiles`,
#'   `pixels` and, with `source`, `source`.
#' @seealso [sg_display_levels()]
#' @export
sg_slide_display_ranges <- function(path, channels, cells, x = "x", y = "y", pixel_size = 1,
                                    n_cells = 4000, n_tiles = 60, step = 3,
                                    probs = c(0.01, 0.997), min_span = 1, seed = 0, source = NULL) {
  if (!is.data.frame(cells) || !all(c(x, y) %in% names(cells))) {
    .sg_abort("cells must be a data frame with the position columns.", code = "VALIDATION_FAILED")
  }
  x <- as.numeric(cells[[x]])
  y <- as.numeric(cells[[y]])
  if (length(x) != length(y) || !length(x)) {
    .sg_abort("x and y must be non-empty and of equal length.", code = "DIMENSION_MISMATCH")
  }
  ch1 <- .sg_window_channel(path, channels[[1]])
  tw <- ch1$block_width
  th <- ch1$block_height
  tiles <- .sg_with_seed(seed, {
    pick <- sample.int(length(x), min(n_cells, length(x)))
    key <- unique(data.frame(ty = floor(y[pick] / pixel_size / th),
                             tx = floor(x[pick] / pixel_size / tw)))
    key[sample.int(nrow(key), min(n_tiles, nrow(key))), , drop = FALSE]
  })
  rows <- lapply(channels, function(ch) {
    v <- unlist(lapply(seq_len(nrow(tiles)), function(i) {
      w <- sg_read_window(path, ch, tiles$tx[i] * tw, tiles$ty[i] * th, tw, th)
      h <- min(th, ch1$height - tiles$ty[i] * th)
      wd <- min(tw, ch1$width - tiles$tx[i] * tw)
      w <- w[seq_len(h), seq_len(wd), drop = FALSE]
      w[seq(1, h, by = step), seq(1, wd, by = step)]
    }), use.names = FALSE)
    r <- sg_display_range(v, probs = probs, min_span = min_span)
    data.frame(channel = .sg_window_channel(path, ch)$name, lo = r[["lo"]], hi = r[["hi"]],
               tiles = nrow(tiles), pixels = length(v), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (!is.null(source)) out$source <- as.character(source)
  out
}

#' Display levels from positive and negative reference cells
#'
#' Sets the black and full-colour levels of each channel from the signal
#' around reference cells, so that called-negative cells stay dark and
#' called-positive cells reach full colour: for every channel up to `n`
#' negative and `n` positive cells are drawn, a statistic of the
#' `(2 * half + 1)`-pixel square patch around each cell is taken (`"mean"` or
#' a percentile given as a probability), and the levels are the `black`
#' quantile of the negative and the `white` quantile of the positive cell
#' values.
#'
#' Arguments that vary by channel (`half`, `statistic`, `black`, `white`)
#' accept a single value or a named list/vector by channel name, with an
#' optional `.default` entry.
#'
#' @param path Path to the image file.
#' @param channels Channel names.
#' @param cells Data frame of cells with positions and labels.
#' @param positive,negative Named lists: channel name to the labels of the
#'   positive and negative reference cells.
#' @param x,y,label Column names in `cells` (positions in physical units).
#' @param pixel_size Physical size of one pixel.
#' @param half Patch half-width in pixels.
#' @param statistic `"mean"` or a probability for a patch percentile.
#' @param black,white Quantiles across negative and positive cells.
#' @param n Maximum number of reference cells per set.
#' @param seed Random seed for the draws (the global RNG state is restored).
#' @return A data frame with columns `channel`, `lo`, `hi`, `n_negative` and
#'   `n_positive`.
#' @seealso [sg_slide_display_ranges()], [sg_display_range()]
#' @export
sg_display_levels <- function(path, channels, cells, positive, negative, x = "x", y = "y",
                              label = "label", pixel_size = 1, half = 7, statistic = 0.9,
                              black = 0.5, white = 0.5, n = 300, seed = 0) {
  if (!is.data.frame(cells)) .sg_abort("cells must be a data frame.")
  missing <- setdiff(c(x, y, label), names(cells))
  if (length(missing)) .sg_abort("cells lacks column{?s} {.val {missing}}.")
  pick <- function(arg, ch) {
    if (!is.list(arg) && is.null(names(arg))) return(arg[[1]])
    arg <- as.list(arg)
    if (!is.null(arg[[ch]])) return(arg[[ch]])
    if (!is.null(arg[[".default"]])) return(arg[[".default"]])
    .sg_abort("No value for channel {.val {ch}}.", code = "VALIDATION_FAILED")
  }
  lab <- as.character(cells[[label]])
  rows <- lapply(seq_along(channels), function(k) {
    ch <- channels[[k]]
    h <- as.integer(pick(half, ch))
    stat <- pick(statistic, ch)
    value <- function(labels, salt) {
      idx <- which(lab %in% unlist(labels))
      if (!length(idx)) .sg_abort("No reference cells for {.val {ch}}.", code = "VALIDATION_FAILED")
      idx <- .sg_with_seed(seed + salt, idx[sample.int(length(idx), min(n, length(idx)))])
      vapply(idx, function(i) {
        cx <- round(cells[[x]][i] / pixel_size)
        cy <- round(cells[[y]][i] / pixel_size)
        p <- sg_read_window(path, ch, cx - h, cy - h, 2L * h + 1L)
        if (identical(stat, "mean")) mean(p) else stats::quantile(p, as.numeric(stat), names = FALSE, type = 7)
      }, numeric(1))
    }
    neg <- value(pick(negative, ch), 2L * k - 1L)
    pos <- value(pick(positive, ch), 2L * k)
    data.frame(channel = ch,
               lo = stats::quantile(neg, as.numeric(pick(black, ch)), names = FALSE, type = 7),
               hi = stats::quantile(pos, as.numeric(pick(white, ch)), names = FALSE, type = 7),
               n_negative = length(neg), n_positive = length(pos), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# ---- internals ----------------------------------------------------------------

.sg_window_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
    .sg_abort("Image file not found.", code = "VALIDATION_FAILED")
  }
  normalizePath(path)
}

.sg_gdal_meta <- function(dsn) {
  m <- sf::gdal_read(dsn, options = character(), driver = character(), read_data = FALSE,
                     NA_value = NA_real_, RasterIO_parameters = list())
  desc <- grep("^TIFFTAG_IMAGEDESCRIPTION=", m$meta, value = TRUE)
  list(width = m$cols[2], height = m$rows[2], bands = length(m$bands),
       block_width = as.numeric(m$blocksizes[1, 1]), block_height = as.numeric(m$blocksizes[1, 2]),
       datatype = as.character(m$datatype[1]),
       description = if (length(desc)) sub("^TIFFTAG_IMAGEDESCRIPTION=", "", desc[1]) else "")
}

.sg_plane_name <- function(desc) {
  for (tag in c("Biomarker", "Name")) {
    m <- regmatches(desc, regexec(paste0("<", tag, ">([^<]*)</", tag, ">"), desc))[[1]]
    if (length(m) == 2L && nzchar(trimws(m[2]))) return(trimws(m[2]))
  }
  NA_character_
}

.sg_ome_channel_names <- function(desc) {
  if (!grepl("<Channel", desc, fixed = TRUE)) return(character(0))
  ch <- regmatches(desc, gregexpr("<Channel[^>]*>", desc))[[1]]
  nm <- regmatches(ch, regexec("Name=\"([^\"]*)\"", ch))
  vapply(nm, function(m) if (length(m) == 2L) m[2] else NA_character_, character(1))
}

.sg_window_channel <- function(path, channel) {
  tab <- sg_image_channels(path)
  i <- if (is.numeric(channel)) {
    match(as.integer(channel), tab$channel)
  } else {
    match(as.character(channel), tab$name)
  }
  if (length(i) != 1L || is.na(i)) {
    .sg_abort(c("Unknown channel {.val {channel}}.", "i" = "Available: {.val {tab$name}}."),
              code = "VALIDATION_FAILED")
  }
  as.list(tab[i, ])
}

.sg_with_seed <- function(seed, expr) {
  old <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  }
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      }
    } else {
      assign(".Random.seed", old, envir = globalenv())
    }
  }, add = TRUE)
  set.seed(seed)
  expr
}
