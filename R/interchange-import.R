# segmantR-interchange-v1: import and validation

#' Import interchange data
#'
#' Reads a segmantR interchange bundle or a single GeoJSON, integer TIFF,
#' measurement CSV or RDS file, verifies it and returns a report with the
#' imported objects. Imported masks are always **staged**; they never replace
#' reviewed data (see [sg_replace_mask()]).
#'
#' Bundle checks: inventory (missing, extra, duplicate, resized or modified
#' files, unsafe paths, symbolic links), optional `expected_digest`, schema
#' family and major version, JSON Schema, asset hashes, TIFF dtype, shape and
#' orientation, background code, label legend completeness, plane
#' consistency, content digest and revision, GeoJSON object ids and exact
#' geometry agreement with the TIFF, and measurement object ids.
#'
#' @param path A bundle directory, its `manifest.json`, or a `.geojson`,
#'   `.json`, `.tif`/`.tiff`, `.csv` or `.rds` file.
#' @param format `"auto"`, `"bundle"`, `"geojson"`, `"mask_tiff"`,
#'   `"measurements"` or `"rds"`.
#' @param expected_digest Optional bundle digest (`"sha256:<hex>"`) the
#'   inventory must match.
#' @param ... Reserved; must be empty.
#' @param shape_yx Image shape needed to rasterise a standalone GeoJSON.
#' @param image Optional `sg_image` providing shape, origin, plane and id
#'   for standalone files.
#' @param origin Optional origin list for standalone GeoJSON.
#' @param trust_rds Logical; RDS files are only deserialised when `TRUE`
#'   (after integrity checks for bundles).
#' @param error Logical; if `FALSE`, failed checks are reported instead of
#'   signalled.
#'
#' @return An `sg_import_report` list with `ok`, `format`, `checks`
#'   (tibble), `mask` (staged `sg_mask` or `NULL`), `image`, `measurements`,
#'   `features` (parsed GeoJSON features), `manifest`, `bundle_digest`,
#'   `conversions` and `error`.
#' @export
#' @examples
#' m <- sg_example_mask("fluorescence_nuclei")
#' b <- sg_export_interchange(m, tempfile("bundle"))
#' rep <- sg_import_interchange(b$path, expected_digest = b$bundle_digest)
#' rep$ok
#' sg_mask_status(rep$mask)$status
sg_import_interchange <- function(path, format = "auto",
                                  expected_digest = NULL, ...,
                                  shape_yx = NULL, image = NULL,
                                  origin = NULL, trust_rds = FALSE,
                                  error = TRUE) {
  if (length(list(...))) {
    .sg_abort("Unused arguments in {.fn sg_import_interchange}.",
              code = "UNKNOWN_PARAMETER")
  }
  format <- match.arg(format, c("auto", "bundle", "geojson", "mask_tiff",
                                "measurements", "rds"))
  checks <- .sg_checklist()
  out <- list(ok = FALSE, format = format, mask = NULL, image = NULL,
              measurements = NULL, features = NULL, manifest = NULL,
              bundle_digest = NULL, conversions = list(), error = NULL)
  result <- tryCatch({
    if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
      .sg_abort("Import path does not exist.", class = "sg_integrity_error",
                code = "INTEGRITY_MISMATCH")
    }
    if (format == "auto") format <- .sg_detect_format(path)
    out$format <- format
    checks$add("format", "ok", format)
    out <- switch(
      format,
      bundle = .sg_import_bundle(path, expected_digest, trust_rds, checks,
                                 out),
      geojson = .sg_import_geojson_file(path, shape_yx, image, origin,
                                        checks, out),
      mask_tiff = .sg_import_tiff_file(path, image, checks, out),
      measurements = .sg_import_measurements_file(path, checks, out),
      rds = .sg_import_rds_file(path, trust_rds, checks, out)
    )
    out$ok <- TRUE
    out
  }, sg_error = function(e) {
    if (error) stop(e)
    checks$add("import", "failed", conditionMessage(e))
    out$error <- e
    out
  })
  result$checks <- checks$table()
  structure(result, class = "sg_import_report")
}

#' Validate interchange data
#'
#' Validates a bundle or file on disk (all checks of
#' [sg_import_interchange()]) or an in-memory object: `sg_manifest` or list
#' (JSON Schema and version), `sg_mask` (label contract, legend
#' completeness, review consistency), `sg_run` (run schema) or
#' `sg_protocol`.
#'
#' @param path_or_object A path, `sg_manifest`, manifest list, `sg_mask`,
#'   `sg_run` or `sg_protocol`.
#' @param ... Passed to [sg_import_interchange()] for paths.
#'
#' @return An `sg_validation_report` with `ok`, `checks` (tibble) and
#'   `error`.
#' @export
#' @examples
#' m <- sg_example_mask("fluorescence_nuclei")
#' sg_validate_interchange(m)$ok
#' bad <- m
#' bad$labels[1, 1] <- -3L
#' sg_validate_interchange(bad)$ok
sg_validate_interchange <- function(path_or_object, ...) {
  x <- path_or_object
  if (is.character(x) && length(x) == 1L) {
    rep <- sg_import_interchange(x, ..., error = FALSE)
    return(structure(list(ok = rep$ok, checks = rep$checks, error = rep$error,
                          report = rep),
                     class = "sg_validation_report"))
  }
  checks <- .sg_checklist()
  err <- NULL
  ok <- tryCatch({
    if (inherits(x, "sg_mask")) {
      chk <- .sg_check_labels(x$labels, x$mask_type %||% "instance")
      checks$add("labels", if (chk$ok) "ok" else "failed",
                 paste(c(sprintf("%d label(s)", chk$n_labels), chk$problems),
                       collapse = "; "))
      if (!chk$ok) {
        .sg_abort("Mask labels violate the mask contract.",
                  code = "VALIDATION_FAILED", details = list(problems = chk$problems))
      }
      leg <- sg_mask_legend(x)
      ids <- sort(unique(x$labels[x$labels > 0L]))
      missing <- setdiff(ids, leg$label)
      checks$add("legend", if (length(missing)) "failed" else "ok",
                 if (length(missing)) paste("missing labels:",
                                            paste(utils::head(missing), collapse = ", ")) else
                   paste(nrow(leg), "entries"))
      if (length(missing)) {
        .sg_abort("Legend is incomplete.", code = "LEGEND_INCOMPLETE")
      }
      st <- sg_mask_status(x)
      checks$add("review", if (st$consistent) "ok" else "failed", st$status)
      if (!st$consistent) {
        .sg_abort("Reviewed mask was modified after review.",
                  class = "sg_conflict_error", code = "REVISION_CONFLICT")
      }
      man <- sg_interchange_manifest(x)
      checks$add("manifest", "ok", man$mask$revision)
    } else if (inherits(x, "sg_run")) {
      .sg_schema_assert(x$record, "run.schema.json", what = "run record")
      checks$add("run", "ok", x$record$status)
    } else if (inherits(x, "sg_protocol")) {
      .sg_protocol_from_list(unclass(x))
      checks$add("protocol", "ok", x$id)
    } else if (is.list(x)) {
      .sg_check_manifest_doc(x)
      checks$add("manifest", "ok", x$kind %||% NA_character_)
    } else {
      .sg_abort("Unsupported object for validation.", code = "VALIDATION_FAILED")
    }
    TRUE
  }, sg_error = function(e) {
    err <<- e
    checks$add("validation", "failed", conditionMessage(e))
    FALSE
  })
  structure(list(ok = ok, checks = checks$table(), error = err),
            class = "sg_validation_report")
}

#' @export
print.sg_import_report <- function(x, ...) {
  cli::cli_text("{.cls sg_import_report} ({x$format}): {if (x$ok) 'ok' else 'failed'}")
  if (!is.null(x$mask)) {
    cli::cli_text("Mask: {nrow(x$mask$labels)} x {ncol(x$mask$labels)}, {x$mask$n_cells} max label, {sg_mask_status(x$mask)$status}")
  }
  bad <- x$checks[x$checks$status != "ok", , drop = FALSE]
  for (i in seq_len(nrow(bad))) {
    cli::cli_text("{bad$check[i]}: {bad$status[i]} ({bad$detail[i]})")
  }
  invisible(x)
}

#' @export
print.sg_validation_report <- function(x, ...) {
  cli::cli_text("{.cls sg_validation_report}: {if (x$ok) 'ok' else 'failed'}")
  for (i in seq_len(nrow(x$checks))) {
    cli::cli_text("{x$checks$check[i]}: {x$checks$status[i]}")
  }
  invisible(x)
}

#' Small accumulator for check rows
#' @noRd
.sg_checklist <- function() {
  env <- new.env(parent = emptyenv())
  env$rows <- list()
  list(
    add = function(check, status, detail = NA_character_) {
      env$rows[[length(env$rows) + 1L]] <- tibble::tibble(
        check = check, status = status,
        detail = if (is.null(detail)) NA_character_ else
          paste(as.character(detail), collapse = " ")
      )
    },
    table = function() {
      if (length(env$rows) == 0L) {
        return(tibble::tibble(check = character(0), status = character(0),
                              detail = character(0)))
      }
      do.call(rbind, env$rows)
    }
  )
}

#' @noRd
.sg_detect_format <- function(path) {
  if (dir.exists(path)) return("bundle")
  base <- tolower(basename(path))
  if (base == "manifest.json") return("bundle")
  ext <- tolower(tools::file_ext(path))
  switch(
    ext,
    geojson = "geojson",
    json = "geojson",
    tif = "mask_tiff",
    tiff = "mask_tiff",
    csv = "measurements",
    tsv = "measurements",
    rds = "rds",
    .sg_abort("Cannot detect the format of {.file {basename(path)}}.",
              code = "VALIDATION_FAILED")
  )
}

#' Check schema family, major version and JSON Schema of a manifest
#' @noRd
.sg_check_manifest_doc <- function(doc) {
  doc <- .sg_as_json_value(unclass(doc))
  fam <- doc$schema %||% ""
  if (!is.character(fam) || !startsWith(fam, "segmantR-interchange-v")) {
    .sg_abort("Unknown manifest schema {.val {fam}}.",
              class = "sg_protocol_error", code = "SCHEMA_MISMATCH")
  }
  major <- .sg_family_major(fam)
  sv <- .sg_semver(doc$schema_version %||% "")
  if (is.na(major) || major != 1L || is.null(sv) || sv$major != 1L) {
    .sg_abort(
      c("Unsupported interchange major version ({fam} {doc$schema_version %||% '?'}).",
        "i" = "This segmantR reads segmantR-interchange-v1 1.x."),
      class = "sg_protocol_error", code = "PROTOCOL_MISMATCH"
    )
  }
  .sg_schema_assert(doc, "manifest.schema.json", what = "manifest")
  doc
}

#' @noRd
.sg_import_bundle <- function(path, expected_digest, trust_rds, checks, out) {
  root <- if (dir.exists(path)) path else dirname(path)
  inv <- .sg_verify_inventory(root)
  if (!file.exists(file.path(root, "integrity.json"))) {
    .sg_abort("Bundle has no integrity.json.", class = "sg_integrity_error",
              code = "INTEGRITY_MISMATCH")
  }
  if (!inv$ok) {
    checks$add("integrity", "failed", paste(inv$problems, collapse = "; "))
    shown <- utils::head(inv$problems, 8L)
    .sg_abort(c("Bundle integrity check failed.",
                stats::setNames(.sg_cli_escape(shown),
                                rep("x", length(shown)))),
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
              details = list(problems = inv$problems))
  }
  checks$add("integrity", "ok", paste(nrow(inv$expected), "file(s)"))
  out$bundle_digest <- inv$digest
  if (!is.null(expected_digest)) {
    exp <- if (startsWith(expected_digest, "sha256:")) expected_digest else
      paste0("sha256:", expected_digest)
    if (!identical(exp, inv$digest)) {
      checks$add("expected_digest", "failed", inv$digest)
      .sg_abort("Bundle digest {.val {inv$digest}} does not match the expected digest.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
                details = list(expected = exp, actual = inv$digest))
    }
    checks$add("expected_digest", "ok", exp)
  }
  man_path <- file.path(root, "manifest.json")
  if (!file.exists(man_path)) {
    .sg_abort("Bundle has no manifest.json.", class = "sg_integrity_error",
              code = "INTEGRITY_MISMATCH")
  }
  if (file.info(man_path)$size > .sg_limits$max_json_bytes) {
    .sg_abort("manifest.json exceeds the JSON size limit.",
              code = "PAYLOAD_TOO_LARGE")
  }
  man <- .sg_check_manifest_doc(.sg_read_json(man_path))
  checks$add("manifest", "ok", paste(man$schema, man$schema_version, man$kind))
  out$manifest <- man
  for (a in man$assets) {
    row <- inv$expected[inv$expected$path == a$path, , drop = FALSE]
    if (nrow(row) != 1L || row$sha256 != a$sha256 ||
        row$size_bytes != a$size_bytes) {
      .sg_abort("Manifest asset {.file {a$path}} disagrees with the inventory.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
                details = list(path = a$path))
    }
  }
  checks$add("assets", "ok", paste(length(man$assets), "asset(s)"))
  roles <- vapply(man$assets, function(a) a$role, character(1))
  asset_path <- function(role) {
    hit <- which(roles == role)
    if (length(hit)) man$assets[[hit[1]]]$path else NULL
  }
  md <- man$mask
  origin <- if (!is.null(md)) .sg_origin_from_json(md$origin) else NULL
  if (!is.null(man$image) && !is.null(md)) {
    ip <- man$image$plane
    mp <- md$plane
    same <- all(vapply(c("level", "series", "z", "t"), function(k) {
      identical(as.integer(ip[[k]]), as.integer(mp[[k]]))
    }, logical(1)))
    if (!same) {
      .sg_abort("Image and mask planes differ in the manifest.",
                code = "INVALID_PLANE")
    }
    if (!identical(unlist(man$image$shape_yx), unlist(md$shape_yx))) {
      .sg_abort("Image and mask shapes differ in the manifest.",
                code = "DIMENSION_MISMATCH")
    }
    if (!identical(md$image_id, man$image$id)) {
      .sg_abort("Mask image_id does not match the image id.",
                code = "VALIDATION_FAILED")
    }
    checks$add("plane", "ok", "image and mask agree")
  }
  legend <- NULL
  if (!is.null(md)) {
    legend <- .sg_legend_from_json(md$legend)
    lp <- asset_path("legend")
    if (!is.null(lp)) {
      ldoc <- .sg_read_json(file.path(root, lp))
      .sg_schema_assert(ldoc, "legend.schema.json", what = "legend")
      if (!identical(.sg_canonical_json(ldoc$entries),
                     .sg_canonical_json(md$legend))) {
        .sg_abort("Legend sidecar and manifest legend differ.",
                  code = "LEGEND_INCOMPLETE")
      }
      checks$add("legend_sidecar", "ok", lp)
    }
  }
  labels <- NULL
  tp <- asset_path("mask_tiff")
  if (!is.null(tp)) {
    tif <- .sg_read_tiff(file.path(root, tp))
    labels <- .sg_labels_from_tiff(tif, unlist(md$shape_yx), checks)
    if (!identical(tif$dtype, md$dtype)) {
      .sg_abort("TIFF dtype {.val {tif$dtype}} differs from the manifest dtype {.val {md$dtype}}.",
                code = "DTYPE_MISMATCH")
    }
    digest <- .sg_array_digest(labels)
    if (!identical(digest, md$content_digest)) {
      .sg_abort("Mask content digest does not match the manifest.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
                details = list(expected = md$content_digest, actual = digest))
    }
    checks$add("mask_content_digest", "ok", digest)
  }
  gp <- asset_path("geojson")
  if (!is.null(gp)) {
    gj <- .sg_read_geojson(file.path(root, gp))
    out$features <- gj$features
    ras <- .sg_rasterise_features(gj$features, unlist(md$shape_yx), origin,
                                  legend, checks, reference = labels)
    out$conversions <- c(out$conversions, ras$conversions)
    if (!is.null(labels)) {
      diff <- sum(ras$labels != labels)
      # Exact (axis-aligned integer) features must match the TIFF pixel for
      # pixel, independently of any approximated features in the file.
      if (ras$exact_mismatch > 0L) {
        .sg_abort(
          "{ras$exact_mismatch_features} exact GeoJSON feature{?s} disagree{?s/} with the mask TIFF ({ras$exact_mismatch} pixel{?s}).",
          code = "VALIDATION_FAILED",
          details = list(pixels = ras$exact_mismatch,
                         features = ras$exact_mismatch_features)
        )
      }
      if (ras$exact && diff > 0L) {
        .sg_abort("GeoJSON geometry disagrees with the mask TIFF in {diff} pixel{?s}.",
                  code = "VALIDATION_FAILED", details = list(pixels = diff))
      }
      checks$add("geojson_vs_tiff", if (diff == 0L) "ok" else "approximated",
                 paste(diff, "differing pixel(s)"))
    } else {
      labels <- ras$labels
      checks$add("geojson_rasterised", "ok",
                 if (ras$exact) "exact" else "approximated")
    }
  }
  if (!is.null(md)) {
    if (is.null(labels)) {
      .sg_abort("Bundle declares a mask but contains no mask representation.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    mask <- .sg_mask_from_parts(labels, md, legend, checks)
    rev <- sg_mask_revision(mask)
    if (is.null(md$revision)) {
      checks$add("mask_revision", "computed", rev)
    } else if (!identical(rev, md$revision)) {
      .sg_abort("Mask revision does not match the manifest.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
                details = list(expected = md$revision, actual = rev))
    } else {
      checks$add("mask_revision", "ok", rev)
    }
    mask$provenance$import <- list(bundle_digest = inv$digest,
                                   manifest_id = man$id,
                                   source_review = md$review$status)
    out$mask <- sg_stage_mask(mask, source = paste("import", man$kind))
  }
  mp <- asset_path("measurements_csv")
  if (!is.null(mp)) {
    long <- .sg_read_measurements_csv(file.path(root, mp))
    .sg_check_measurements(long, legend, checks)
    out$measurements <- long
  }
  ip <- asset_path("image_tiff")
  if (!is.null(ip) && !is.null(man$image)) {
    tif <- .sg_read_tiff(file.path(root, ip))
    px <- tif$data
    if (!identical(as.integer(dim(px)[1:2]), as.integer(unlist(man$image$shape_yx)))) {
      .sg_abort("Image TIFF shape differs from the manifest.",
                code = "DIMENSION_MISMATCH")
    }
    if (!is.null(man$image$content_digest) &&
        !identical(.sg_array_digest(px), man$image$content_digest)) {
      .sg_abort("Image content digest does not match the manifest.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    out$image <- .sg_image_from_descriptor(px, man$image)
    checks$add("image_content_digest", "ok", man$image$content_digest)
  }
  rp <- asset_path("rds")
  if (!is.null(rp)) {
    if (!trust_rds) {
      checks$add("rds", "skipped", "trust_rds = FALSE")
    } else {
      obj <- readRDS(file.path(root, rp))
      if (!is.null(md) && (!inherits(obj$mask, "sg_mask") ||
                           !identical(sg_mask_revision(obj$mask),
                                      md$revision))) {
        .sg_abort("RDS mask does not match the neutral representation.",
                  class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
      }
      checks$add("rds", "ok", "matches manifest revision")
    }
  }
  out
}

#' @noRd
.sg_origin_from_json <- function(o) {
  list(x = if (is.null(o$x)) NA_real_ else as.numeric(o$x),
       y = if (is.null(o$y)) NA_real_ else as.numeric(o$y),
       downsample = as.numeric(o$downsample %||% 1))
}

#' @noRd
.sg_plane_from_json <- function(p) {
  if (is.null(p)) return(NULL)
  list(level = as.integer(p$level %||% 0L), series = as.integer(p$series %||% 0L),
       c = if (is.null(p$c)) NA_integer_ else as.integer(p$c),
       z = as.integer(p$z %||% 0L), t = as.integer(p$t %||% 0L))
}

#' @noRd
.sg_legend_from_json <- function(entries) {
  if (length(entries) == 0L) {
    return(tibble::tibble(label = integer(0), object_id = character(0),
                          class = character(0), name = character(0)))
  }
  chr <- function(v) if (is.null(v)) NA_character_ else as.character(v)
  .sg_check_legend(tibble::tibble(
    label = vapply(entries, function(e) as.integer(e$label), integer(1)),
    object_id = vapply(entries, function(e) chr(e$object_id), character(1)),
    class = vapply(entries, function(e) chr(e$class), character(1)),
    name = vapply(entries, function(e) chr(e$name), character(1))
  ))
}

#' Validate TIFF pixel data as an integer label matrix
#' @noRd
.sg_labels_from_tiff <- function(tif, shape_yx = NULL, checks) {
  if (!grepl("^u?int", tif$dtype)) {
    .sg_abort(
      c("Mask TIFF has dtype {.val {tif$dtype}}; integer labels are required.",
        "i" = "Export label masks as uint8/uint16/uint32."),
      code = "DTYPE_MISMATCH", details = list(dtype = tif$dtype)
    )
  }
  if (tif$n_pages != 1L || tif$samples_per_pixel != 1L) {
    .sg_abort("Mask TIFF must contain exactly one single-sample plane.",
              code = "DIMENSION_MISMATCH")
  }
  data <- tif$data
  if (!is.null(shape_yx)) {
    d <- dim(data)
    if (!identical(as.integer(d), as.integer(shape_yx))) {
      reason <- if (identical(as.integer(rev(d)), as.integer(shape_yx))) {
        "orientation (array appears transposed: width and height swapped)"
      } else {
        "shape"
      }
      .sg_abort("Mask TIFF is {d[1]} x {d[2]} but {shape_yx[1]} x {shape_yx[2]} is declared ({reason}).",
                code = "DIMENSION_MISMATCH", details = list(reason = reason))
    }
  }
  if (any(data < 0) || any(data != trunc(data))) {
    .sg_abort("Mask TIFF contains negative or non-integer values.",
              code = "DTYPE_MISMATCH")
  }
  if (max(data) > .Machine$integer.max) {
    .sg_abort("Mask labels exceed the R integer range.",
              code = "DTYPE_MISMATCH")
  }
  checks$add("mask_tiff", "ok", paste(tif$dtype, paste(dim(data),
                                                       collapse = "x")))
  matrix(as.integer(data), nrow(data), ncol(data))
}

#' Construct an sg_mask from bundle parts
#' @noRd
.sg_mask_from_parts <- function(labels, md, legend, checks) {
  ids <- sort(unique(labels[labels > 0L]))
  if (!is.null(legend)) {
    missing <- setdiff(ids, legend$label)
    if (length(missing)) {
      checks$add("legend", "failed", paste("unlabelled ids:",
                                           paste(utils::head(missing), collapse = ", ")))
      .sg_abort("Legend is missing {length(missing)} label{?s} present in the mask.",
                code = "LEGEND_INCOMPLETE")
    }
    empty <- setdiff(legend$label, ids)
    checks$add("legend", if (length(empty)) "warning" else "ok",
               if (length(empty)) paste(length(empty), "legend entries without pixels") else
                 paste(nrow(legend), "entries"))
  }
  mtype <- md$mask_type %||% "instance"
  chk <- .sg_check_labels(labels, mtype, connectivity = md$connectivity %||% 8L)
  if (mtype == "binary" && !chk$ok) {
    .sg_abort("Binary mask contains values other than 0 and 1.",
              code = "VALIDATION_FAILED")
  }
  checks$add("mask_contract", if (chk$ok) "ok" else "warning",
             paste(c(mtype, chk$problems), collapse = "; "))
  mask <- new_sg_mask(labels, image_id = md$image_id, mask_type = mtype,
                      legend = legend, plane = .sg_plane_from_json(md$plane),
                      origin = .sg_origin_from_json(md$origin), id = md$id)
  mask$provenance <- list(model_digest = md$model_digest)
  mask
}

#' @noRd
.sg_image_from_descriptor <- function(px, d) {
  bands <- if (is.null(d$bands)) NULL else tibble::tibble(
    name = vapply(d$bands, function(b) b$name %||% NA_character_, character(1)),
    wavelength_nm = vapply(d$bands, function(b) as.numeric(b$wavelength_nm %||% NA),
                           numeric(1)),
    fwhm_nm = vapply(d$bands, function(b) as.numeric(b$fwhm_nm %||% NA),
                     numeric(1))
  )
  new_sg_image(
    px, channels = unlist(d$channels),
    resolution = list(x_um = d$pixel_size$x %||% NA_real_,
                      y_um = d$pixel_size$y %||% NA_real_),
    id = d$id, plane = .sg_plane_from_json(d$plane),
    origin = .sg_origin_from_json(d$origin), bands = bands,
    value_semantics = d$value_semantics, source_digest = d$source_digest,
    transform_digest = d$transform_digest
  )
}

#' Parse a GeoJSON file into a feature list
#' @noRd
.sg_read_geojson <- function(path) {
  if (file.info(path)$size > 512 * 1024 * 1024) {
    .sg_abort("GeoJSON file is too large.", code = "PAYLOAD_TOO_LARGE")
  }
  doc <- .sg_read_json(path)
  features <- if (is.list(doc) && is.null(names(doc))) {
    doc
  } else if (identical(doc$type, "FeatureCollection")) {
    doc$features
  } else if (identical(doc$type, "Feature")) {
    list(doc)
  } else {
    .sg_abort("GeoJSON must be a FeatureCollection, Feature or feature array.",
              code = "VALIDATION_FAILED")
  }
  if (!is.null(doc$crs)) {
    .sg_abort("GeoJSON declares a CRS; only image-pixel coordinates are supported.",
              code = "VALIDATION_FAILED")
  }
  if (length(features) > .sg_limits$max_geojson_features) {
    .sg_abort("Too many GeoJSON features.", code = "PAYLOAD_TOO_LARGE")
  }
  fc <- list(type = "FeatureCollection", features = features)
  errs <- .sg_schema_errors(fc, "geojson.schema.json", normalise = FALSE)
  if (length(errs)) {
    shown <- utils::head(errs, 8L)
    .sg_abort(c("GeoJSON does not conform to the image-coordinate profile.",
                stats::setNames(.sg_cli_escape(shown), rep("x", length(shown)))),
              code = "VALIDATION_FAILED", details = list(errors = errs))
  }
  fc
}

#' Rasterise GeoJSON features into labels using/creating a legend
#' @noRd
.sg_rasterise_features <- function(features, shape_yx, origin, legend,
                                   checks, reference = NULL) {
  n <- length(features)
  labels <- matrix(0L, shape_yx[1], shape_yx[2])
  counts <- matrix(0L, shape_yx[1], shape_yx[2])
  ref_areas <- if (is.null(reference)) NULL else .sg_label_areas(reference)
  exact_mismatch <- 0L
  exact_mismatch_features <- 0L
  ids <- character(n)
  exact <- TRUE
  unsupported <- 0L
  approximated <- 0L
  planes <- list()
  assigned <- integer(n)
  new_rows <- list()
  used_labels <- if (is.null(legend)) integer(0) else legend$label
  next_label <- max(c(0L, used_labels)) + 1L
  for (i in seq_len(n)) {
    f <- features[[i]]
    props <- f$properties %||% list()
    fid <- f$id %||% props$object_id %||% NULL
    ids[i] <- if (is.null(fid)) NA_character_ else as.character(fid)
    g <- .sg_geometry_rings(f$geometry)
    if (!is.null(f$geometry$plane)) planes[[length(planes) + 1L]] <- f$geometry$plane
    if (!g$supported) {
      unsupported <- unsupported + 1L
      next
    }
    if (!g$exact) {
      exact <- FALSE
      approximated <- approximated + 1L
    }
    lab <- NA_integer_
    if (!is.null(legend) && !is.na(ids[i])) {
      hit <- which(legend$object_id == ids[i])
      if (length(hit) == 1L) lab <- legend$label[hit]
    }
    if (is.na(lab) && !is.null(props$label) && is.null(legend)) {
      lab <- as.integer(props$label)
    }
    if (is.na(lab)) {
      if (!is.null(legend)) {
        .sg_abort("GeoJSON feature {i} (id {.val {ids[i]}}) is not in the legend.",
                  code = "LEGEND_INCOMPLETE", details = list(feature = i))
      }
      lab <- next_label
      next_label <- next_label + 1L
    }
    assigned[i] <- lab
    if (is.null(legend)) {
      cls <- props$classification$name %||% NULL
      new_rows[[length(new_rows) + 1L]] <- tibble::tibble(
        label = lab, object_id = ids[i],
        class = if (is.null(cls)) NA_character_ else as.character(cls),
        name = if (is.null(props$name)) NA_character_ else
          as.character(props$name)
      )
    }
    m <- .sg_rasterise_polygons(g$polygons, shape_yx, origin)
    counts <- counts + m
    labels[m & labels == 0L] <- lab
    if (!is.null(reference) && g$exact) {
      inside <- sum(m)
      hit <- sum(reference[m] == lab)
      ref_n <- ref_areas[as.character(lab)]
      ref_n <- if (is.na(ref_n)) 0L else as.integer(ref_n)
      miss <- (inside - hit) + (ref_n - hit)
      if (miss > 0L) {
        exact_mismatch <- exact_mismatch + as.integer(miss)
        exact_mismatch_features <- exact_mismatch_features + 1L
      }
    }
  }
  if (!is.null(reference)) {
    uncovered <- setdiff(as.integer(names(ref_areas)), assigned)
    if (length(uncovered)) {
      .sg_abort(
        "{length(uncovered)} mask label{?s} ha{?s/ve} no GeoJSON feature (e.g. {utils::head(uncovered, 3)}).",
        code = "VALIDATION_FAILED", details = list(labels = uncovered)
      )
    }
  }
  dup_ids <- unique(stats::na.omit(ids[duplicated(ids)]))
  if (length(dup_ids)) {
    .sg_abort("GeoJSON contains duplicate object ids ({.val {utils::head(dup_ids, 3)}}).",
              code = "VALIDATION_FAILED")
  }
  if (anyDuplicated(assigned[assigned > 0L])) {
    .sg_abort("Several GeoJSON features map to the same label.",
              code = "VALIDATION_FAILED")
  }
  overlap <- sum(counts > 1L)
  checks$add("geojson_features", "ok",
             sprintf("%d feature(s), %d unsupported, %d approximated, %d overlap px",
                     n, unsupported, approximated, overlap))
  conversions <- list(list(
    from = "geojson", to = "mask",
    fidelity = if (unsupported > 0L) "unsupported" else if (exact) "exact"
    else "approximated",
    notes = sprintf(paste("Pixel-centre even-odd rasterisation; %d",
                          "unsupported geometries skipped; %d overlapping",
                          "pixels kept by first feature."),
                    unsupported, overlap),
    count = n
  ))
  new_legend <- if (length(new_rows)) do.call(rbind, new_rows) else NULL
  list(labels = labels, exact = exact && unsupported == 0L,
       conversions = conversions, legend = new_legend, planes = planes,
       overlap = overlap, exact_mismatch = exact_mismatch,
       exact_mismatch_features = exact_mismatch_features)
}

#' @noRd
.sg_import_geojson_file <- function(path, shape_yx, image, origin, checks,
                                    out) {
  if (!is.null(image)) {
    .sg_assert_image(image)
    shape_yx <- shape_yx %||% dim(image$pixels)[1:2]
    origin <- origin %||% .sg_image_origin(image)
  }
  if (is.null(shape_yx)) {
    .sg_abort(
      c("A standalone GeoJSON import needs the image shape.",
        "i" = "Pass {.arg shape_yx} or {.arg image}."),
      code = "VALIDATION_FAILED"
    )
  }
  origin <- .sg_check_origin(origin)
  gj <- .sg_read_geojson(path)
  out$features <- gj$features
  ras <- .sg_rasterise_features(gj$features, shape_yx, origin, NULL, checks)
  out$conversions <- ras$conversions
  legend <- ras$legend
  if (!is.null(legend) && anyNA(legend$object_id)) {
    miss <- is.na(legend$object_id)
    legend$object_id[miss] <- vapply(legend$label[miss], function(l) {
      .sg_uuid_from_key(c("geojson-import", .sg_sha256_file(path), l))
    }, character(1))
  }
  plane <- .sg_plane_from_geojson(ras$planes, image)
  mask <- new_sg_mask(ras$labels,
                      image_id = if (is.null(image)) NULL else .sg_image_id(image),
                      legend = legend, plane = plane, origin = origin)
  mask$provenance$import <- list(source_name = basename(path),
                                 source_digest = paste0("sha256:",
                                                        .sg_sha256_file(path)))
  checks$add("plane", "ok", sprintf("z=%d t=%d", plane$z, plane$t))
  out$mask <- sg_stage_mask(mask, source = "import geojson")
  out
}

#' Plane from QuPath GeoJSON geometry planes (must agree)
#' @noRd
.sg_plane_from_geojson <- function(planes, image = NULL) {
  base <- if (is.null(image)) .sg_check_plane(NULL) else .sg_image_plane(image)
  base$c <- NA_integer_
  if (length(planes) == 0L) return(base)
  zs <- unique(vapply(planes, function(p) as.integer(p$z %||% 0L), integer(1)))
  ts <- unique(vapply(planes, function(p) as.integer(p$t %||% 0L), integer(1)))
  if (length(zs) != 1L || length(ts) != 1L) {
    .sg_abort("GeoJSON features lie on different z/t planes; import one plane at a time.",
              code = "INVALID_PLANE")
  }
  if (!is.null(image) && (zs != base$z || ts != base$t)) {
    .sg_abort("GeoJSON plane (z={zs}, t={ts}) differs from the image plane (z={base$z}, t={base$t}).",
              code = "INVALID_PLANE")
  }
  base$z <- zs
  base$t <- ts
  base
}

#' @noRd
.sg_import_tiff_file <- function(path, image, checks, out) {
  tif <- .sg_read_tiff(path)
  shape <- if (is.null(image)) NULL else dim(image$pixels)[1:2]
  labels <- .sg_labels_from_tiff(tif, shape, checks)
  sidecars <- c(sub("\\.tiff?$", ".legend.json", path, ignore.case = TRUE),
                file.path(dirname(path), "mask.legend.json"))
  sidecar <- sidecars[file.exists(sidecars)][1]
  legend <- NULL
  mtype <- "instance"
  if (!is.na(sidecar)) {
    ldoc <- .sg_read_json(sidecar)
    .sg_schema_assert(ldoc, "legend.schema.json", what = "legend")
    legend <- .sg_legend_from_json(ldoc$entries)
    mtype <- ldoc$mask_type
    checks$add("legend_sidecar", "ok", basename(sidecar))
  } else {
    checks$add("legend_sidecar", "absent", "legend generated deterministically")
  }
  md <- list(mask_type = mtype, image_id = if (is.null(image)) NULL else
    .sg_image_id(image), plane = NULL, origin = list(x = 0, y = 0, downsample = 1),
    id = NULL, connectivity = 8L, model_digest = NULL)
  if (!is.null(image)) {
    md$plane <- .sg_image_plane(image)
    md$plane$c <- NULL
    md$origin <- .sg_image_origin(image)
  }
  mask <- .sg_mask_from_parts(labels, md, legend, checks)
  mask$provenance$import <- list(source_name = basename(path),
                                 source_digest = paste0("sha256:",
                                                        .sg_sha256_file(path)),
                                 dtype = tif$dtype)
  out$mask <- sg_stage_mask(mask, source = "import mask tiff")
  out
}

#' Read the canonical long measurement table (CSV/TSV)
#' @noRd
.sg_read_measurements_csv <- function(path) {
  sep <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) "\t" else ","
  df <- utils::read.table(path, header = TRUE, sep = sep, quote = "\"",
                          colClasses = "character", na.strings = "",
                          comment.char = "", check.names = FALSE)
  need <- c("image_id", "object_id", "label", "name", "namespace", "value",
            "value_state", "unit", "provider_id")
  miss <- setdiff(need, names(df))
  if (length(miss)) {
    .sg_abort("Measurement table lacks column{?s} {.val {miss}}.",
              code = "VALIDATION_FAILED")
  }
  states <- c("finite", "missing", "nan", "pos_inf", "neg_inf")
  if (any(!df$value_state %in% states)) {
    .sg_abort("Measurement table has unknown value_state values.",
              code = "VALIDATION_FAILED")
  }
  if (any(df$namespace %in% c(NA, "") |
          !df$namespace %in% c("stored", "dynamic", "derived"))) {
    .sg_abort("Measurement namespace must be stored, dynamic or derived.",
              code = "VALIDATION_FAILED")
  }
  fin <- df$value_state == "finite"
  num <- suppressWarnings(as.numeric(df$value))
  if (any(fin & !is.finite(num)) || any(!fin & !is.na(df$value))) {
    .sg_abort("Measurement values disagree with value_state.",
              code = "VALIDATION_FAILED")
  }
  tibble::tibble(
    image_id = df$image_id, object_id = df$object_id,
    label = suppressWarnings(as.integer(df$label)), name = df$name,
    namespace = df$namespace,
    value = .sg_value_from_state(df$value, df$value_state),
    value_state = df$value_state, unit = df$unit %|NA|% "unknown",
    provider_id = df$provider_id
  )
}

#' Replace NA by a default
#' @noRd
`%|NA|%` <- function(x, y) ifelse(is.na(x), y, x)

#' @noRd
.sg_check_measurements <- function(long, legend, checks) {
  if (!is.null(legend) && nrow(long)) {
    unknown <- setdiff(stats::na.omit(long$object_id), legend$object_id)
    if (length(unknown)) {
      .sg_abort("Measurements reference {length(unknown)} unknown object id{?s}.",
                code = "LEGEND_INCOMPLETE")
    }
  }
  checks$add("measurements", "ok", paste(nrow(long), "row(s)"))
}

#' @noRd
.sg_import_measurements_file <- function(path, checks, out) {
  long <- .sg_read_measurements_csv(path)
  .sg_check_measurements(long, NULL, checks)
  out$measurements <- long
  out
}

#' @noRd
.sg_import_rds_file <- function(path, trust_rds, checks, out) {
  if (!isTRUE(trust_rds)) {
    .sg_abort(
      c("RDS files are only read with {.code trust_rds = TRUE}.",
        "i" = "Deserialising R objects from untrusted sources is unsafe; prefer the neutral bundle."),
      class = "sg_security_error", code = "UNTRUSTED_RDS"
    )
  }
  obj <- readRDS(path)
  if (!is.list(obj) || !inherits(obj$mask, "sg_mask")) {
    .sg_abort("RDS does not contain a segmantR interchange object.",
              code = "VALIDATION_FAILED")
  }
  chk <- .sg_check_labels(obj$mask$labels, obj$mask$mask_type %||% "instance")
  if (anyNA(obj$mask$labels) || any(obj$mask$labels < 0L)) {
    .sg_abort("RDS mask violates the mask contract.", code = "VALIDATION_FAILED")
  }
  checks$add("rds", "ok", paste(c("trusted", chk$problems), collapse = "; "))
  mask <- obj$mask
  mask$provenance$import <- list(source_review = .sg_review(mask)$status,
                                 source_name = basename(path))
  mask$review <- NULL
  out$mask <- sg_stage_mask(mask, source = "import rds")
  out$image <- obj$image
  out$measurements <- obj$measurements
  out
}
