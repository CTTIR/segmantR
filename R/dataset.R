# Training dataset manifests, grouped splits, tile preparation and checks

.sg_splits <- c("train", "validation", "test")

#' Describe a training dataset
#'
#' Builds a tile-level dataset manifest from image/mask pairs without
#' writing pixels. Tiles are laid out on a regular grid (`tile_size`,
#' `overlap`), splits are assigned per **group** (`subject_id`, `sample_id`
#' or `slide_id`) with a fixed seed so tiles of one origin never land in
#' different splits, and every tile records its bounds, plane, object list
#' (label, object id, class) and exclusion reason.
#'
#' Masks must satisfy the requested `mask_type`: integer, background 0, and
#' for `"instance"` one connected part per label. A foreground/background
#' mask with several objects under one label is rejected
#' (`NOT_INSTANCE_MASK`) instead of being accepted silently.
#'
#' @param pairs A list of training pairs. Each element is a list with
#'   `image` (`sg_image`), `mask` (`sg_mask`) and the grouping ids
#'   `subject_id`, `sample_id` and/or `slide_id`.
#' @param tile_size Tile edge length in pixels.
#' @param overlap Overlap between neighbouring tiles in pixels.
#' @param group_by Grouping key used for the split.
#' @param split Named proportions for `train`, `validation` and `test`
#'   (normalised to sum 1).
#' @param seed Integer seed of the group permutation (the global RNG state is
#'   restored afterwards).
#' @param mask_type Required mask type.
#' @param min_objects Tiles with fewer objects are excluded (`"empty"` for
#'   zero objects, `"too_few_objects"` otherwise).
#' @param partial_tiles `"exclude"` border tiles smaller than `tile_size`,
#'   or `"keep"` them.
#' @param require_reviewed Logical; exclude tiles from masks that are not
#'   reviewed (`"not_reviewed"`).
#' @param normalization List with `method` (`"none"`, `"minmax"`,
#'   `"percentile"`), `low`, `high` describing the normalisation the trainer
#'   applies (recorded, not applied here).
#' @param backend Optional target backend name recorded in the manifest.
#'
#' @return An `sg_dataset_manifest` list conforming to
#'   `dataset-manifest.schema.json`.
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' # The synthetic example mask contains overlapping ellipses; split them
#' # into separate instances first.
#' msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
#'                          disconnected = "split")
#' pairs <- list(
#'   list(image = img, mask = msk, subject_id = "A"),
#'   list(image = img, mask = msk, subject_id = "B")
#' )
#' man <- sg_dataset_manifest(pairs, tile_size = 32L, min_objects = 0L,
#'                            split = c(train = 0.5, validation = 0.5,
#'                                      test = 0))
#' table(vapply(man$tiles, function(t) t$split, ""))
sg_dataset_manifest <- function(pairs, tile_size = 256L, overlap = 0L,
                                group_by = c("subject_id", "sample_id",
                                             "slide_id"),
                                split = c(train = 0.7, validation = 0.15,
                                          test = 0.15),
                                seed = 1L,
                                mask_type = c("instance", "labelled",
                                              "binary"),
                                min_objects = 1L,
                                partial_tiles = c("exclude", "keep"),
                                require_reviewed = FALSE,
                                normalization = list(method = "none"),
                                backend = NULL) {
  group_by <- match.arg(group_by)
  mask_type <- match.arg(mask_type)
  partial_tiles <- match.arg(partial_tiles)
  tile_size <- as.integer(tile_size)
  overlap <- as.integer(overlap)
  seed <- as.integer(seed)
  if (length(tile_size) != 1L || is.na(tile_size) || tile_size < 8L) {
    .sg_abort("{.arg tile_size} must be an integer >= 8.",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  if (length(overlap) != 1L || is.na(overlap) || overlap < 0L ||
      overlap >= tile_size) {
    .sg_abort("{.arg overlap} must be in [0, tile_size).",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  props <- .sg_split_props(split)
  if (!is.list(pairs) || length(pairs) == 0L) {
    .sg_abort("{.arg pairs} must be a non-empty list of training pairs.",
              code = "VALIDATION_FAILED")
  }
  sources <- list()
  channels_ref <- NULL
  semantics_ref <- NULL
  px_ref <- NULL
  bands_ref <- NULL
  raw_min <- Inf
  raw_max <- -Inf
  classes <- character(0)
  for (i in seq_along(pairs)) {
    pr <- pairs[[i]]
    if (!is.list(pr) || !inherits(pr$image, "sg_image") ||
        !inherits(pr$mask, "sg_mask")) {
      .sg_abort("Pair {i} must be a list with {.field image} (sg_image) and {.field mask} (sg_mask).",
                code = "VALIDATION_FAILED", details = list(pair = i))
    }
    img <- pr$image
    msk <- pr$mask
    if (!identical(as.integer(dim(img$pixels)[1:2]),
                   as.integer(dim(msk$labels)))) {
      .sg_abort("Pair {i}: image and mask dimensions differ.",
                code = "DIMENSION_MISMATCH", details = list(pair = i))
    }
    grp <- pr[[group_by]]
    if (is.null(grp) || length(grp) != 1L || is.na(grp) || !nzchar(grp)) {
      .sg_abort(
        c("Pair {i} has no {.field {group_by}}.",
          "i" = "Grouped splits need an origin id for every pair to prevent leakage."),
        code = "VALIDATION_FAILED", details = list(pair = i)
      )
    }
    .sg_assert_training_mask(msk, mask_type, i)
    n_ch <- if (length(dim(img$pixels)) == 3L) dim(img$pixels)[3] else 1L
    chans <- img$channels
    if (length(chans) != n_ch) chans <- paste0("ch", seq_len(n_ch))
    sem <- img$value_semantics %||% "unknown"
    ps <- .sg_pixel_size(img)
    if (is.null(channels_ref)) {
      channels_ref <- chans
      semantics_ref <- sem
      px_ref <- ps
      bands_ref <- .sg_image_descriptor(img)$bands
    } else {
      if (!identical(chans, channels_ref)) {
        .sg_abort("Pair {i}: channels differ from the first pair.",
                  code = "VALIDATION_FAILED", details = list(pair = i))
      }
      if (!identical(sem, semantics_ref)) {
        .sg_abort(
          "Pair {i}: value semantics {.val {sem}} differ from {.val {semantics_ref}}; do not mix value scales in one dataset.",
          code = "VALIDATION_FAILED", details = list(pair = i)
        )
      }
      same_px <- identical(is.null(ps$x), is.null(px_ref$x)) &&
        (is.null(ps$x) || (abs(ps$x - px_ref$x) < 1e-9 &&
                             abs(ps$y - px_ref$y) < 1e-9))
      if (!same_px) {
        .sg_abort("Pair {i}: pixel size differs from the first pair.",
                  code = "VALIDATION_FAILED", details = list(pair = i))
      }
    }
    fin <- img$pixels[is.finite(img$pixels)]
    if (length(fin)) {
      raw_min <- min(raw_min, fin)
      raw_max <- max(raw_max, fin)
    }
    leg <- sg_mask_legend(msk)
    classes <- union(classes, stats::na.omit(leg$class))
    chr_or_null <- function(v) if (is.null(v) || is.na(v)) NULL else
      as.character(v)
    sources[[i]] <- list(
      source_index = i,
      image_id = .sg_image_id(img),
      image_digest = .sg_array_digest(img$pixels),
      source_digest = img$source_digest,
      mask_revision = sg_mask_revision(msk),
      review_status = .sg_review(msk)$status,
      annotation_revision = chr_or_null(pr$annotation_revision),
      subject_id = chr_or_null(pr$subject_id),
      sample_id = chr_or_null(pr$sample_id),
      slide_id = chr_or_null(pr$slide_id),
      group = as.character(grp),
      split = NA_character_,
      shape_yx = I(as.integer(dim(msk$labels))),
      plane = .sg_image_plane(img),
      origin = .sg_image_origin(img),
      transform_digest = img$transform_digest,
      calibration_digest = img$metadata$calibration_digest
    )
  }
  groups <- sort(unique(vapply(sources, function(s) s$group, "")),
                 method = "radix")
  assignment <- .sg_assign_groups(groups, props, seed)
  for (i in seq_along(sources)) {
    sources[[i]]$split <- assignment[[sources[[i]]$group]]
  }
  tiles <- list()
  for (i in seq_along(pairs)) {
    msk <- pairs[[i]]$mask
    leg <- sg_mask_legend(msk)
    src <- sources[[i]]
    reviewed <- identical(src$review_status, "reviewed")
    grid <- .sg_tile_grid(dim(msk$labels), tile_size, overlap, partial_tiles)
    origin <- src$origin
    for (k in seq_len(nrow(grid))) {
      r0 <- grid$row[k]
      c0 <- grid$col[k]
      h <- grid$height[k]
      w <- grid$width[k]
      crop <- msk$labels[r0:(r0 + h - 1L), c0:(c0 + w - 1L), drop = FALSE]
      ids <- sort(unique(crop[crop > 0L]))
      parts <- 0L
      if (mask_type == "instance" && length(ids)) {
        comp <- .sg_components_by_value(crop, 4L)
        pos <- crop > 0L
        parts <- nrow(unique(cbind(crop[pos], comp[pos]))) - length(ids)
      }
      reason <- if (grid$partial[k] && partial_tiles == "exclude") {
        "partial_tile"
      } else if (require_reviewed && !reviewed) {
        "not_reviewed"
      } else if (length(ids) == 0L && min_objects > 0L) {
        "empty"
      } else if (length(ids) < min_objects) {
        "too_few_objects"
      } else {
        NULL
      }
      objs <- lapply(ids, function(id) {
        row <- leg[leg$label == id, , drop = FALSE]
        list(label = as.integer(id),
             object_id = if (nrow(row) && !is.na(row$object_id[1]))
               row$object_id[1] else NULL,
             class = if (nrow(row) && !is.na(row$class[1])) row$class[1]
             else NULL)
      })
      tiles[[length(tiles) + 1L]] <- list(
        tile_id = sprintf("s%03d_y%05d_x%05d", i, r0 - 1L, c0 - 1L),
        source_index = i,
        split = src$split,
        x = origin$x + (c0 - 1) * origin$downsample,
        y = origin$y + (r0 - 1) * origin$downsample,
        width = as.integer(w), height = as.integer(h),
        n_objects = length(ids),
        n_split_parts = as.integer(parts),
        excluded = !is.null(reason),
        exclusion_reason = reason,
        image_path = NULL, mask_path = NULL,
        image_digest = NULL, mask_digest = NULL,
        objects = objs
      )
    }
  }
  reasons <- vapply(tiles, function(t) t$exclusion_reason %||% "", "")
  excl <- table(reasons[nzchar(reasons)])
  counts <- lapply(stats::setNames(.sg_splits, .sg_splits), function(s) {
    sum(vapply(tiles, function(t) identical(t$split, s) && !t$excluded,
               logical(1)))
  })
  norm <- list(method = normalization$method %||% "none",
               low = normalization$low, high = normalization$high,
               raw_range = list(min = if (is.finite(raw_min)) raw_min else NULL,
                                max = if (is.finite(raw_max)) raw_max else NULL),
               applied = FALSE)
  man <- list(
    schema = .sg_interchange_schema,
    schema_version = .sg_interchange_version,
    kind = "training-dataset",
    dataset_id = "pending",
    created = .sg_utc_now(),
    producer = .sg_producer(),
    coordinate_convention = .sg_coordinate_convention(),
    mask_type = mask_type,
    background = 0L,
    classes = I(sort(as.character(classes))),
    tile_size = tile_size,
    overlap = overlap,
    level = as.integer(sources[[1]]$plane$level),
    partial_tiles = partial_tiles,
    pixel_size = px_ref,
    channels = I(channels_ref),
    bands = bands_ref,
    value_semantics = semantics_ref,
    normalization = norm,
    split = list(
      group_by = group_by, seed = seed,
      proportions = as.list(props),
      groups = lapply(stats::setNames(.sg_splits, .sg_splits), function(s) {
        I(names(assignment)[unlist(assignment) == s])
      }),
      tile_counts = counts
    ),
    sources = sources,
    tiles = tiles,
    exclusions = .sg_json_object(as.list(stats::setNames(as.integer(excl),
                                                         names(excl)))),
    target = list(backend = backend, runtime = .sg_runtime()),
    dataset_digest = paste0("sha256:", strrep("0", 64)),
    extensions = .sg_json_object()
  )
  man <- .sg_finalise_dataset_manifest(man)
  structure(man, class = c("sg_dataset_manifest", "list"))
}

#' Compute dataset id/digest over content (excluding volatile fields)
#' @noRd
.sg_finalise_dataset_manifest <- function(man) {
  man <- .sg_as_json_value(unclass(man))
  stable <- man
  stable$created <- NULL
  stable$producer <- NULL
  stable$target$runtime <- NULL
  stable$dataset_id <- NULL
  stable$dataset_digest <- NULL
  digest <- .sg_digest_json(stable)
  man$dataset_digest <- digest
  man$dataset_id <- paste0("dataset-", substr(sub("^sha256:", "", digest),
                                              1L, 16L))
  .sg_schema_assert(man, "dataset-manifest.schema.json",
                    what = "dataset manifest")
  man
}

#' @noRd
.sg_split_props <- function(split) {
  if (!is.numeric(split) || is.null(names(split)) ||
      !setequal(names(split), .sg_splits) || any(split < 0) ||
      sum(split) <= 0) {
    .sg_abort("{.arg split} must be non-negative proportions named train, validation, test.",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  p <- split[.sg_splits] / sum(split)
  stats::setNames(as.numeric(p), .sg_splits)
}

#' Deterministic group-to-split assignment
#' @noRd
.sg_assign_groups <- function(groups, props, seed) {
  n <- length(groups)
  perm <- .sg_with_seed(seed, sample.int(n))
  active <- .sg_splits[props > 0]
  if (n < length(active)) {
    .sg_abort(
      "{n} group{?s} cannot fill {length(active)} non-empty split{?s} without leakage.",
      code = "SPLIT_LEAKAGE"
    )
  }
  counts <- floor(props * n)
  counts[props > 0 & counts == 0] <- 1
  while (sum(counts) > n) {
    i <- which.max(counts - props * n)
    counts[i] <- counts[i] - 1
  }
  while (sum(counts) < n) {
    i <- which.max(props * n - counts)
    counts[i] <- counts[i] + 1
  }
  labels <- rep(.sg_splits, times = counts)
  out <- stats::setNames(as.list(labels[order(perm)]), groups)
  out
}

#' Tile grid for a shape
#' @noRd
.sg_tile_grid <- function(shape, tile_size, overlap, partial_tiles) {
  step <- tile_size - overlap
  starts <- function(n) {
    s <- seq(1L, max(1L, n - tile_size + 1L), by = step)
    last <- s[length(s)] + tile_size - 1L
    # Border tiles are always listed; partial_tiles = "exclude" marks them
    # excluded instead of silently leaving the border untiled.
    if (last < n) s <- c(s, s[length(s)] + step)
    if (n < tile_size) s <- 1L
    s
  }
  rs <- starts(shape[1])
  cs <- starts(shape[2])
  g <- expand.grid(row = rs, col = cs)
  g <- g[order(g$row, g$col), , drop = FALSE]
  g$height <- pmin(tile_size, shape[1] - g$row + 1L)
  g$width <- pmin(tile_size, shape[2] - g$col + 1L)
  g$partial <- g$height < tile_size | g$width < tile_size
  g
}

#' Validate a training mask against a mask type
#' @noRd
.sg_assert_training_mask <- function(mask, mask_type, i = NA) {
  labels <- mask$labels
  chk <- .sg_check_labels(labels, mask_type, connectivity = 4L)
  if (!is.integer(labels)) {
    .sg_abort("Pair {i}: mask labels must be integer.", code = "DTYPE_MISMATCH")
  }
  if (mask_type == "instance" && !chk$ok) {
    ids <- unique(labels[labels > 0L])
    binary_like <- length(ids) == 1L
    .sg_abort(
      c(if (binary_like) {
        "Pair {i}: the mask looks like a foreground/background mask, not an instance mask."
      } else {
        "Pair {i}: the mask is not a valid instance mask."
      },
      stats::setNames(.sg_cli_escape(chk$problems), rep("x", length(chk$problems))),
      "i" = "Instance training needs a unique positive id per object and background 0 (split objects with sg_cleanup_labels(disconnected = 'split') after checking them)."),
      code = "NOT_INSTANCE_MASK", details = list(pair = i, problems = chk$problems)
    )
  }
  if (!chk$ok) {
    .sg_abort(c("Pair {i}: mask violates the {mask_type} contract.",
                stats::setNames(.sg_cli_escape(chk$problems),
                                rep("x", length(chk$problems)))),
              code = "VALIDATION_FAILED", details = list(pair = i))
  }
  invisible(TRUE)
}

#' Prepare training data tiles
#'
#' Builds the dataset manifest with [sg_dataset_manifest()] and materialises
#' the included tiles: image tiles as float64 TIFF (exact values, `[y, x,
#' channel]` pages) and mask tiles as unsigned integer TIFF with labels
#' renumbered 1..N per tile in raster order. Tile object lists map tile
#' labels to source object ids. With a `destination`, a directory with
#' `dataset_manifest.json`, `tiles/<split>/images|masks/*.tif` and
#' `integrity.json` is written; otherwise tiles are returned in memory.
#'
#' @inheritParams sg_dataset_manifest
#' @param destination Optional output directory (must not exist or be
#'   empty).
#' @param ... Further arguments for [sg_dataset_manifest()].
#' @param overwrite Logical; replace an existing prepared dataset.
#'
#' @return An `sg_training_set` with `manifest`, `path` (or `NULL`) and
#'   `tiles` (in-memory list when `destination` is `NULL`).
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' # The synthetic example mask contains overlapping ellipses; split them
#' # into separate instances first.
#' msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
#'                          disconnected = "split")
#' ts <- sg_prepare_training_data(
#'   list(list(image = img, mask = msk, subject_id = "A")),
#'   tile_size = 32L, min_objects = 0L,
#'   split = c(train = 1, validation = 0, test = 0)
#' )
#' length(ts$tiles)
sg_prepare_training_data <- function(pairs, destination = NULL, ...,
                                     overwrite = FALSE) {
  man <- sg_dataset_manifest(pairs, ...)
  tiles_mem <- list()
  staging <- NULL
  if (!is.null(destination)) {
    staging <- .sg_prepare_destination(destination, overwrite)
    on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  }
  for (k in seq_along(man$tiles)) {
    t <- man$tiles[[k]]
    if (isTRUE(t$excluded)) next
    pr <- pairs[[t$source_index]]
    origin <- .sg_image_origin(pr$image)
    r0 <- as.integer((t$y - origin$y) / origin$downsample) + 1L
    c0 <- as.integer((t$x - origin$x) / origin$downsample) + 1L
    rr <- r0:(r0 + t$height - 1L)
    cc <- c0:(c0 + t$width - 1L)
    px <- pr$image$pixels
    tile_px <- if (length(dim(px)) == 3L) px[rr, cc, , drop = FALSE] else
      px[rr, cc, drop = FALSE]
    crop <- pr$mask$labels[rr, cc, drop = FALSE]
    if (man$mask_type == "instance") {
      comp <- .sg_components_by_value(crop, 4L)
      tile_lab <- .sg_relabel(ifelse(crop > 0L, comp, 0L), "raster")
      src_of <- tapply(crop[crop > 0L], tile_lab[crop > 0L], function(v) v[1])
    } else {
      tile_lab <- crop
      src_of <- NULL
    }
    tile_lab <- matrix(as.integer(tile_lab), nrow(crop), ncol(crop))
    leg <- sg_mask_legend(pr$mask)
    objs <- if (!is.null(src_of)) {
      lapply(names(src_of), function(nm) {
        src <- as.integer(src_of[[nm]])
        row <- leg[leg$label == src, , drop = FALSE]
        list(label = as.integer(nm),
             object_id = if (nrow(row) && !is.na(row$object_id[1]))
               row$object_id[1] else NULL,
             class = if (nrow(row) && !is.na(row$class[1])) row$class[1]
             else NULL)
      })
    } else {
      t$objects
    }
    man$tiles[[k]]$objects <- objs
    man$tiles[[k]]$image_digest <- .sg_array_digest(tile_px)
    man$tiles[[k]]$mask_digest <- .sg_array_digest(tile_lab)
    if (!is.null(staging)) {
      img_rel <- file.path("tiles", t$split, "images", paste0(t$tile_id, ".tif"))
      msk_rel <- file.path("tiles", t$split, "masks", paste0(t$tile_id, ".tif"))
      dir.create(dirname(file.path(staging, img_rel)), recursive = TRUE,
                 showWarnings = FALSE)
      dir.create(dirname(file.path(staging, msk_rel)), recursive = TRUE,
                 showWarnings = FALSE)
      .sg_write_tiff(tile_px, file.path(staging, img_rel), dtype = "float64")
      .sg_write_tiff(tile_lab, file.path(staging, msk_rel),
                     dtype = .sg_label_dtype(tile_lab))
      man$tiles[[k]]$image_path <- img_rel
      man$tiles[[k]]$mask_path <- msk_rel
    } else {
      tiles_mem[[t$tile_id]] <- list(image = tile_px, labels = tile_lab,
                                     split = t$split)
    }
  }
  man <- structure(.sg_finalise_dataset_manifest(man),
                   class = c("sg_dataset_manifest", "list"))
  path <- NULL
  if (!is.null(staging)) {
    .sg_write_json(unclass(man), file.path(staging, "dataset_manifest.json"))
    sg_hash_assets(staging, write = "integrity")
    .sg_commit_destination(staging, destination)
    on.exit(NULL)
    path <- normalizePath(destination, winslash = "/")
  }
  structure(list(manifest = man, path = path,
                 tiles = if (is.null(path)) tiles_mem else NULL),
            class = "sg_training_set")
}

#' @export
print.sg_training_set <- function(x, ...) {
  m <- x$manifest
  n_incl <- sum(!vapply(m$tiles, function(t) isTRUE(t$excluded), logical(1)))
  cli::cli_text("{.cls sg_training_set} {m$dataset_id}: {n_incl} tile{?s} ({m$mask_type})")
  cli::cli_text("Splits: {paste(names(m$split$tile_counts), unlist(m$split$tile_counts), sep = '=', collapse = ', ')}")
  invisible(x)
}

#' @export
print.sg_dataset_manifest <- function(x, ...) {
  cli::cli_text("{.cls sg_dataset_manifest} {x$dataset_id}: {length(x$sources)} source{?s}, {length(x$tiles)} tile{?s}")
  invisible(x)
}

#' Validate a training dataset manifest
#'
#' Checks schema conformance, split leakage (a group or source in more than
#' one split), tile bounds, exclusion bookkeeping, instance/label contract
#' of materialised mask tiles (integer dtype, background 0, unique
#' connected instance ids, complete object lists), recorded tile digests,
#' the dataset digest and, for directories, the integrity inventory.
#'
#' @param x An `sg_dataset_manifest`, `sg_training_set`, a prepared dataset
#'   directory or a `dataset_manifest.json` path.
#' @param mask_type Optional mask type the consumer requires (e.g.
#'   `"instance"` for StarDist).
#' @param check_files Logical; read and check tile files of a directory.
#' @param error Logical; signal the first failure instead of reporting it.
#'
#' @return An `sg_validation_report` with `ok`, `checks` and `error`.
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' # The synthetic example mask contains overlapping ellipses; split them
#' # into separate instances first.
#' msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
#'                          disconnected = "split")
#' man <- sg_dataset_manifest(list(list(image = img, mask = msk,
#'                                      subject_id = "A")),
#'                            tile_size = 32L, min_objects = 0L,
#'                            split = c(train = 1, validation = 0, test = 0))
#' sg_validate_training_manifest(man)$ok
sg_validate_training_manifest <- function(x, mask_type = NULL,
                                          check_files = TRUE, error = TRUE) {
  checks <- .sg_checklist()
  root <- NULL
  err <- NULL
  ok <- tryCatch({
    man <- if (inherits(x, "sg_training_set")) {
      root <- x$path
      x$manifest
    } else if (inherits(x, "sg_dataset_manifest") || is.list(x)) {
      x
    } else if (is.character(x) && length(x) == 1L) {
      if (dir.exists(x)) {
        root <- x
        .sg_read_json(file.path(x, "dataset_manifest.json"))
      } else {
        root <- dirname(x)
        .sg_read_json(x)
      }
    } else {
      .sg_abort("Unsupported dataset manifest input.", code = "VALIDATION_FAILED")
    }
    man <- .sg_as_json_value(unclass(man))
    fam <- man$schema %||% ""
    if (!identical(fam, .sg_interchange_schema) ||
        is.null(.sg_semver(man$schema_version %||% "")) ||
        .sg_semver(man$schema_version)$major != 1L) {
      .sg_abort("Unsupported dataset manifest schema/version.",
                class = "sg_protocol_error", code = "PROTOCOL_MISMATCH")
    }
    .sg_schema_assert(man, "dataset-manifest.schema.json",
                      what = "dataset manifest")
    checks$add("schema", "ok", man$dataset_id)
    if (!is.null(mask_type) && !identical(man$mask_type, mask_type)) {
      .sg_abort("Dataset mask type {.val {man$mask_type}} but {.val {mask_type}} is required.",
                code = "NOT_INSTANCE_MASK")
    }
    src_split <- vapply(man$sources, function(s) s$split, "")
    src_group <- vapply(man$sources, function(s) s$group, "")
    per_group <- tapply(src_split, src_group, function(v) length(unique(v)))
    leaking <- names(per_group)[per_group > 1L]
    tile_split <- vapply(man$tiles, function(t) t$split, "")
    tile_src <- vapply(man$tiles, function(t) as.integer(t$source_index), 1L)
    tile_mismatch <- which(tile_split != src_split[tile_src])
    listed <- unlist(man$split$groups)
    dup_groups <- unique(listed[duplicated(listed)])
    if (length(leaking) || length(tile_mismatch) || length(dup_groups)) {
      checks$add("split_leakage", "failed",
                 paste(c(leaking, dup_groups), collapse = ", "))
      .sg_abort("Split leakage: tiles of one origin occur in several splits.",
                code = "SPLIT_LEAKAGE",
                details = list(groups = unique(c(leaking, dup_groups)),
                               tiles = length(tile_mismatch)))
    }
    checks$add("split_leakage", "ok", paste(length(unique(src_group)),
                                            "group(s)"))
    for (t in man$tiles) {
      s <- man$sources[[t$source_index]]
      o <- s$origin
      shape <- unlist(s$shape_yx)
      r0 <- (t$y - o$y) / o$downsample
      c0 <- (t$x - o$x) / o$downsample
      if (r0 < 0 || c0 < 0 || r0 + t$height > shape[1] ||
          c0 + t$width > shape[2]) {
        .sg_abort("Tile {.val {t$tile_id}} lies outside its source image.",
                  code = "DIMENSION_MISMATCH")
      }
      if (isTRUE(t$excluded) != !is.null(t$exclusion_reason)) {
        .sg_abort("Tile {.val {t$tile_id}} has inconsistent exclusion fields.",
                  code = "VALIDATION_FAILED")
      }
    }
    checks$add("tile_bounds", "ok", paste(length(man$tiles), "tile(s)"))
    recomputed <- .sg_finalise_dataset_manifest(man)$dataset_digest
    if (!identical(recomputed, man$dataset_digest)) {
      .sg_abort("Dataset digest does not match the manifest content.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    checks$add("dataset_digest", "ok", man$dataset_digest)
    if (!is.null(root) && check_files) {
      if (file.exists(file.path(root, "integrity.json"))) {
        inv <- .sg_verify_inventory(root)
        if (!inv$ok) {
          .sg_abort(c("Dataset integrity check failed.",
                      stats::setNames(.sg_cli_escape(utils::head(inv$problems, 8L)),
                                      rep("x", min(8L, length(inv$problems))))),
                    class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
        }
        checks$add("integrity", "ok", inv$digest)
      }
      n_checked <- 0L
      for (t in man$tiles) {
        if (is.null(t$mask_path)) next
        tif <- .sg_read_tiff(.sg_resolve_in_root(root, t$mask_path))
        labels <- .sg_labels_from_tiff(tif, c(t$height, t$width),
                                       .sg_checklist())
        chk <- .sg_check_labels(labels, man$mask_type, 4L)
        if (!chk$ok) {
          .sg_abort(c("Tile {.val {t$tile_id}} violates the {man$mask_type} contract.",
                      stats::setNames(.sg_cli_escape(chk$problems),
                                      rep("x", length(chk$problems)))),
                    code = if (man$mask_type == "instance") "NOT_INSTANCE_MASK"
                    else "VALIDATION_FAILED")
        }
        ids <- sort(unique(labels[labels > 0L]))
        listed_ids <- sort(vapply(t$objects, function(o) as.integer(o$label), 1L))
        if (!identical(as.integer(ids), as.integer(listed_ids))) {
          .sg_abort("Tile {.val {t$tile_id}} object list does not match its mask labels.",
                    code = "LEGEND_INCOMPLETE")
        }
        if (!is.null(t$mask_digest) &&
            !identical(.sg_array_digest(labels), t$mask_digest)) {
          .sg_abort("Tile {.val {t$tile_id}} mask digest mismatch.",
                    class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
        }
        n_checked <- n_checked + 1L
      }
      checks$add("tile_masks", "ok", paste(n_checked, "mask tile(s)"))
    }
    TRUE
  }, sg_error = function(e) {
    if (error) stop(e)
    err <<- e
    checks$add("validation", "failed", conditionMessage(e))
    FALSE
  })
  structure(list(ok = ok, checks = checks$table(), error = err),
            class = "sg_validation_report")
}
