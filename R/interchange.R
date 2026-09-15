# segmantR-interchange-v1: capabilities, descriptors, manifests and export

.sg_coordinate_convention <- function() {
  list(origin = "top_left", x_axis = "right", y_axis = "down", units = "px",
       pixel_centre = "half_integer", array_order = "y,x,channel",
       plane_index_base = 0L)
}

#' @noRd
.sg_producer <- function() {
  rev <- .sg_source_revision()
  list(name = "segmantR",
       version = as.character(utils::packageVersion("segmantR")),
       api_version = .sg_api_version,
       source_revision = if (is.na(rev$revision)) NULL else rev$revision,
       dirty = rev$dirty)
}

.sg_limits <- list(
  max_json_bytes = 16L * 1024L * 1024L,
  max_core_pixels = 4194304L,
  max_label = 4294967295,
  max_archive_entries = 10000L,
  max_archive_bytes = 2147483647,
  max_geojson_features = 1000000L
)

#' Interchange capability report
#'
#' Describes what this installation of segmantR can exchange: schema and
#' API versions, interoperability profiles with their status
#' (`"supported"`, `"planned"` or `"unavailable"`), file formats, protocols,
#' optional backends and limits. Optional Python backends are only probed
#' when `check_backends = TRUE`; QuPath is detected from installation files
#' without starting it.
#'
#' Profiles: `I0` neutral files (manifest, integer TIFF masks, GeoJSON,
#' measurements, integrity inventory); `I1` versioned protocols and run
#' envelopes; `models` model bundles with runtime and checksums;
#' `qupath_programs` Groovy templates and `run.json`; `stardist_qupath` the
#' StarDist extension adapter; `control` the local control service
#' (`segmantR-control-v1`); `partner_qupflowR` and `partner_annotatR` the
#' partner contracts, which stay `planned` until a real consumer and QuPath
#' evidence exist.
#'
#' @param check_backends Logical; probe optional Python backends
#'   (initialises Python through reticulate).
#'
#' @return An `sg_capabilities` list conforming to
#'   `capabilities.schema.json`, with a `digest` over its content.
#' @export
#' @examples
#' caps <- sg_interchange_capabilities()
#' caps$profiles$I0$status
#' caps$schema
sg_interchange_capabilities <- function(check_backends = FALSE) {
  fmt <- function(format, read, write, requires = character(0),
                  optional_pkg = NULL, reason = NULL) {
    status <- "supported"
    if (!is.null(optional_pkg) && !requireNamespace(optional_pkg,
                                                    quietly = TRUE)) {
      status <- "unavailable"
      reason <- paste0("Install the '", optional_pkg, "' package.")
    }
    list(format = format, read = read, write = write, status = status,
         requires = I(requires), reason = reason)
  }
  formats <- list(
    fmt("manifest-json", TRUE, TRUE),
    fmt("integrity-json", TRUE, TRUE),
    fmt("legend-json", TRUE, TRUE),
    fmt("mask-tiff-integer", TRUE, TRUE,
        reason = "Uncompressed baseline TIFF built in; compressed TIFF needs 'tiff'."),
    fmt("ome-tiff-image", TRUE, TRUE,
        reason = "Planes and pixel size only; no pyramids."),
    fmt("geojson-image-coordinates", TRUE, TRUE),
    fmt("qupath-geojson", TRUE, TRUE),
    fmt("measurements-csv", TRUE, TRUE),
    fmt("measurements-parquet", TRUE, TRUE, requires = "nanoparquet",
        optional_pkg = "nanoparquet"),
    fmt("rds", TRUE, TRUE,
        reason = "R-native optimisation only; import needs trust_rds = TRUE."),
    fmt("envi", TRUE, FALSE),
    fmt("model-bundle-segmantR", TRUE, TRUE, requires = "zip or utils::zip")
  )
  protos <- .sg_registry_protocols()
  proto_rows <- lapply(protos, function(p) {
    needs_py <- isTRUE(p$runtime_profile$requires_python)
    st <- if (needs_py && check_backends) {
      .sg_backend_status(p$method$backend)
    } else {
      list(available = !needs_py, reason = if (needs_py)
        "Optional backend not probed (check_backends = FALSE)." else NULL)
    }
    list(id = p$id, version = p$version,
         status = if (!needs_py) "supported" else if (st$available)
           "supported" else "unavailable",
         available = isTRUE(st$available), reason = st$reason)
  })
  backend <- function(name, available, version = NULL, reason = NULL,
                      hint = NULL, checked = TRUE) {
    list(name = name, available = isTRUE(available), checked = checked,
         version = version, reason = reason, install_hint = hint)
  }
  py_rows <- lapply(c(stardist = "python-stardist",
                      cellpose = "python-cellpose",
                      deepcell = "python-deepcell"), function(b) {
    if (!check_backends) {
      return(backend(b, FALSE, reason = "Not probed (check_backends = FALSE).",
                     checked = FALSE))
    }
    st <- .sg_backend_status(b)
    backend(b, st$available, reason = st$reason, hint = st$install_hint)
  })
  qp <- .sg_detect_qupath()
  backends <- c(
    list(
      backend("R-core", TRUE, as.character(utils::packageVersion("segmantR"))),
      backend("tiff", requireNamespace("tiff", quietly = TRUE),
              .sg_pkg_version("tiff"), hint = "install.packages('tiff')"),
      backend("sf", requireNamespace("sf", quietly = TRUE),
              .sg_pkg_version("sf"), hint = "install.packages('sf')"),
      backend("EBImage", requireNamespace("EBImage", quietly = TRUE),
              .sg_pkg_version("EBImage"),
              hint = "BiocManager::install('EBImage')"),
      backend("reticulate", requireNamespace("reticulate", quietly = TRUE),
              .sg_pkg_version("reticulate"),
              hint = "install.packages('reticulate')"),
      backend("nanoparquet", requireNamespace("nanoparquet", quietly = TRUE),
              .sg_pkg_version("nanoparquet"),
              hint = "install.packages('nanoparquet')"),
      backend("qupath", qp$found, qp$version,
              reason = if (qp$found) NULL else
                "No QuPath installation found (set SEGMANTR_QUPATH).",
              hint = "https://qupath.github.io"),
      backend("qupath-extension-stardist", !is.na(qp$stardist_version),
              if (is.na(qp$stardist_version)) NULL else qp$stardist_version,
              reason = if (is.na(qp$stardist_version))
                "StarDist extension jar not found." else NULL,
              hint = "Install it via QuPath Extensions > Manage extensions.")
    ),
    unname(py_rows)
  )
  profile <- function(status, implemented, reason = NULL, evidence = NULL) {
    list(status = status, implemented = implemented, reason = reason,
         evidence = evidence)
  }
  out <- list(
    schema = .sg_interchange_schema,
    schema_version = .sg_interchange_version,
    kind = "capabilities",
    producer = .sg_producer(),
    api_version = .sg_api_version,
    profiles = list(
      I0 = profile("supported", TRUE,
                   evidence = "tests: test-interchange-*.R with independent tifffile/QuPath fixtures"),
      I1 = profile("supported", TRUE,
                   evidence = "tests: test-protocols*.R (exact synthetic oracles, fresh R process)"),
      models = profile("supported", TRUE,
                       evidence = "tests: test-model-bundle.R"),
      datasets = profile("supported", TRUE,
                         evidence = "tests: test-dataset.R"),
      qupath_programs = profile(
        "planned", TRUE,
        reason = paste("Templates and run.json are generated and headless",
                       "execution was exercised in an opt-in lane; interactive",
                       "Script Editor runs and a qupflowR consumer are not",
                       "yet verified.")),
      stardist_qupath = profile(
        "planned", TRUE,
        reason = "Parameter map verified against StarDist extension 0.6.0 builder names; no partner consumer yet."),
      stardist_python = profile(
        if (check_backends && isTRUE(py_rows$stardist$available))
          "supported" else "unavailable", TRUE,
        reason = "Requires Python stardist + tensorflow at the point of use."),
      control = profile("planned", FALSE,
                        reason = "segmantR-control-v1 is specified but not implemented."),
      app = profile("planned", TRUE,
                    reason = "sg_app() builder has server tests; no browser/consumer contract tests yet."),
      partner_qupflowR = profile("planned", FALSE,
                                 reason = "No qupflowR consumer exists yet."),
      partner_annotatR = profile("planned", FALSE,
                                 reason = "annotatR interop is not implemented on the annotatR side yet.")
    ),
    formats = formats,
    protocols = unname(proto_rows),
    backends = backends,
    limits = .sg_limits
  )
  out$digest <- .sg_digest_json(out)
  out <- .sg_as_json_value(out)
  .sg_schema_assert(out, "capabilities.schema.json", what = "capability report")
  structure(out, class = c("sg_capabilities", "list"))
}

#' @export
print.sg_capabilities <- function(x, ...) {
  cli::cli_text("{.cls sg_capabilities} {x$schema} {x$schema_version} (API {x$api_version})")
  for (nm in names(x$profiles)) {
    cli::cli_text("{nm}: {x$profiles[[nm]]$status}")
  }
  invisible(x)
}

#' Locate a QuPath installation and StarDist extension without running it
#' @noRd
.sg_detect_qupath <- function() {
  none <- list(found = FALSE, version = NULL, stardist_version = NA_character_,
               app_dir = NULL)
  candidates <- c(Sys.getenv("SEGMANTR_QUPATH"), Sys.which("QuPath"),
                  "/opt/QuPath/bin/QuPath",
                  Sys.glob("/Applications/QuPath*.app/Contents/MacOS/QuPath"),
                  Sys.glob(file.path(Sys.getenv("LOCALAPPDATA"),
                                     "QuPath*", "QuPath*.exe")))
  candidates <- unique(candidates[nzchar(candidates)])
  version <- NULL
  app_dir <- NULL
  for (cand in candidates) {
    if (!file.exists(cand)) next
    real <- normalizePath(cand, mustWork = FALSE)
    base <- dirname(dirname(real))
    jars <- c(Sys.glob(file.path(base, "lib", "app", "qupath-core-*.jar")),
              Sys.glob(file.path(base, "app", "qupath-core-*.jar")),
              Sys.glob(file.path(base, "..", "app", "qupath-core-*.jar")))
    jars <- jars[!grepl("processing", jars)]
    if (length(jars)) {
      version <- sub("^qupath-core-(.*)\\.jar$", "\\1", basename(jars[1]))
      app_dir <- base
      break
    }
  }
  if (is.null(version)) return(none)
  sd <- .sg_detect_stardist_extension(version)
  list(found = TRUE, version = version, stardist_version = sd, app_dir = app_dir)
}

#' @noRd
.sg_detect_stardist_extension <- function(qupath_version) {
  mm <- sub("^([0-9]+\\.[0-9]+).*$", "\\1", qupath_version)
  home <- path.expand("~")
  roots <- c(Sys.getenv("SEGMANTR_QUPATH_USER_DIR"),
             file.path(home, "QuPath", paste0("v", mm)),
             file.path(home, "QuPath"))
  roots <- roots[nzchar(roots) & dir.exists(roots)]
  for (r in roots) {
    jars <- list.files(r, pattern = "^qupath-extension-stardist-.*\\.jar$",
                       recursive = TRUE)
    if (length(jars)) {
      v <- sub("^qupath-extension-stardist-(.*)\\.jar$", "\\1",
               basename(jars))
      return(v[order(numeric_version(v, strict = FALSE),
                     decreasing = TRUE)][1])
    }
  }
  NA_character_
}

# ---- descriptors ------------------------------------------------------------

#' @noRd
.sg_storage_dtype <- function(x) {
  if (is.integer(x) || is.logical(x)) "int32" else "float64"
}

#' Image descriptor for manifests
#' @noRd
.sg_image_descriptor <- function(image) {
  px <- image$pixels
  d <- dim(px)
  n_ch <- if (length(d) == 3L) d[3] else 1L
  channels <- image$channels
  if (length(channels) != n_ch) channels <- paste0("ch", seq_len(n_ch))
  bands <- image$bands
  band_rows <- if (is.null(bands)) NULL else lapply(seq_len(nrow(bands)),
                                                    function(i) {
    list(c = as.integer(bands$c[i]), name = bands$name[i],
         wavelength_nm = bands$wavelength_nm[i], fwhm_nm = bands$fwhm_nm[i])
  })
  finite <- px[is.finite(px)]
  src_name <- image$metadata$source_name
  if (!is.null(src_name) && (!is.character(src_name) ||
                             grepl("[/\\\\]", src_name))) {
    src_name <- basename(src_name)
  }
  ra <- image$metadata$read_accounting
  list(
    id = .sg_image_id(image),
    source_name = src_name,
    shape_yx = I(as.integer(d[1:2])),
    n_channels = as.integer(n_ch),
    array_order = "y,x,channel",
    dtype = .sg_storage_dtype(px),
    channels = I(as.character(channels)),
    bands = band_rows,
    plane = .sg_image_plane(image),
    origin = .sg_image_origin(image),
    pixel_size = .sg_pixel_size(image),
    value_semantics = image$value_semantics %||% "unknown",
    value_range = list(min = if (length(finite)) min(finite) else NULL,
                       max = if (length(finite)) max(finite) else NULL,
                       policy = "observed"),
    content_digest = .sg_array_digest(px),
    source_digest = image$source_digest,
    transform_digest = image$transform_digest,
    calibration_digest = image$metadata$calibration_digest,
    read_accounting = if (is.null(ra)) NULL else list(
      bytes_read = ra$bytes_read, bands_read = I(as.integer(ra$bands_read)),
      format = ra$format)
  )
}

#' @noRd
.sg_pixel_size <- function(image) {
  px <- image$resolution$x_um %||% NA_real_
  py <- image$resolution$y_um %||% NA_real_
  ok <- function(v) is.numeric(v) && length(v) == 1L && is.finite(v) && v > 0
  list(x = if (ok(px)) px else NULL, y = if (ok(py)) py else NULL,
       unit = "um")
}

#' Mask descriptor for manifests
#' @noRd
.sg_mask_descriptor <- function(mask) {
  legend <- sg_mask_legend(mask)
  review <- .sg_review(mask)
  revision <- sg_mask_revision(mask)
  ids <- sort(unique(mask$labels[mask$labels > 0L]))
  classes <- sort(unique(stats::na.omit(legend$class)))
  conn <- mask$provenance$connectivity %||% NULL
  list(
    id = mask$id %||% paste0("mask-", substr(sub("^sha256:", "", revision),
                                             1L, 16L)),
    image_id = mask$image_id,
    mask_type = mask$mask_type %||% "instance",
    dtype = .sg_label_dtype(mask$labels),
    background = 0L,
    shape_yx = I(as.integer(dim(mask$labels))),
    label_count = as.integer(length(ids)),
    max_label = as.integer(if (length(ids)) max(ids) else 0L),
    plane = .sg_check_plane(mask$plane),
    origin = .sg_check_origin(mask$origin),
    connectivity = conn,
    content_digest = .sg_array_digest(mask$labels),
    revision = revision,
    review = list(
      status = review$status,
      revision = if (is.na(review$revision)) NULL else review$revision,
      parent_revision = if (is.na(review$parent_revision)) NULL else
        review$parent_revision,
      reviewed_at = if (is.na(review$reviewed_at)) NULL else
        review$reviewed_at,
      reviewer = if (is.na(review$reviewer)) NULL else review$reviewer
    ),
    legend = .sg_legend_rows(legend),
    classes = lapply(classes, function(cl) list(name = cl, color = NULL)),
    model_digest = mask$provenance$model_digest %||% NULL,
    transform_digest = mask$provenance$transform_digest %||% NULL
  )
}

#' @noRd
.sg_legend_rows <- function(legend) {
  na_null <- function(v) if (is.na(v)) NULL else v
  lapply(seq_len(nrow(legend)), function(i) {
    list(label = legend$label[i], object_id = na_null(legend$object_id[i]),
         class = na_null(legend$class[i]), name = na_null(legend$name[i]))
  })
}

#' Normalise the object accepted by manifest/export functions
#' @noRd
.sg_interchange_parts <- function(x, image = NULL) {
  parts <- list(image = image, mask = NULL, run = NULL, measurements = NULL)
  if (inherits(x, "sg_run")) {
    parts$mask <- x$mask
    parts$run <- x
    parts$measurements <- x$measurements
  } else if (inherits(x, "sg_mask")) {
    parts$mask <- x
  } else if (inherits(x, "sg_image")) {
    parts$image <- x
  } else if (is.list(x) && !is.null(names(x)) &&
             all(names(x) %in% c("image", "mask", "run", "measurements"))) {
    for (nm in names(x)) parts[[nm]] <- x[[nm]]
    if (!is.null(parts$run)) {
      parts$mask <- parts$mask %||% parts$run$mask
      parts$measurements <- parts$measurements %||% parts$run$measurements
    }
  } else {
    .sg_abort("{.arg x} must be an sg_image, sg_mask, sg_run or a list of them.",
              code = "VALIDATION_FAILED")
  }
  if (!is.null(parts$image)) .sg_assert_image(parts$image)
  if (!is.null(parts$mask)) .sg_assert_mask(parts$mask)
  if (!is.null(parts$image) && !is.null(parts$mask)) {
    if (!identical(as.integer(dim(parts$image$pixels)[1:2]),
                   as.integer(dim(parts$mask$labels)))) {
      .sg_abort("Image and mask dimensions differ.", code = "DIMENSION_MISMATCH")
    }
    ip <- .sg_image_plane(parts$image)
    mp <- .sg_check_plane(parts$mask$plane)
    if (!identical(ip[c("level", "series", "z", "t")],
                   mp[c("level", "series", "z", "t")])) {
      .sg_abort("Image and mask planes differ.", code = "INVALID_PLANE")
    }
    img_id <- .sg_image_id(parts$image)
    if (is.null(parts$mask$image_id)) {
      # An unbound mask exported together with its image is bound to it.
      parts$mask$image_id <- img_id
    }
    if (!identical(parts$mask$image_id, img_id)) {
      .sg_abort(
        "Mask is bound to image {.val {parts$mask$image_id}}, not {.val {img_id}}.",
        code = "VALIDATION_FAILED"
      )
    }
  }
  parts
}

#' Build an interchange manifest
#'
#' Describes an image, mask or segmentation run with the shared coordinate
#' convention, plane, pixel size, legend, review state, protocol reference,
#' runtime and asset inventory. The result conforms to
#' `inst/schema/segmantR-interchange-v1/manifest.schema.json`.
#'
#' @param x An `sg_image`, `sg_mask`, `sg_run`, or a named list with
#'   `image`, `mask`, `run` and/or `measurements`.
#' @param ... Reserved; must be empty.
#' @param image Optional `sg_image` the mask belongs to.
#' @param assets Asset records (`role`, `path`, `media_type`, `size_bytes`,
#'   `sha256`), normally filled by [sg_export_interchange()].
#' @param conversions Conversion records (`from`, `to`, `fidelity`, `notes`).
#' @param kind Optional manifest kind override.
#'
#' @return An `sg_manifest` list.
#' @export
#' @examples
#' m <- sg_example_mask("fluorescence_nuclei")
#' man <- sg_interchange_manifest(m)
#' man$mask$label_count
#' man$coordinate_convention$y_axis
sg_interchange_manifest <- function(x, ..., image = NULL, assets = list(),
                                    conversions = list(), kind = NULL) {
  if (length(list(...))) {
    .sg_abort("Unused arguments in {.fn sg_interchange_manifest}.",
              code = "UNKNOWN_PARAMETER")
  }
  parts <- .sg_interchange_parts(x, image)
  kind <- kind %||% if (!is.null(parts$run)) "segmentation-run" else
    if (!is.null(parts$mask)) "mask" else "image"
  id <- if (!is.null(parts$run)) {
    parts$run$record$run_id
  } else if (!is.null(parts$mask)) {
    .sg_mask_descriptor(parts$mask)$id
  } else {
    .sg_image_id(parts$image)
  }
  meas <- parts$measurements
  man <- list(
    schema = .sg_interchange_schema,
    schema_version = .sg_interchange_version,
    kind = kind,
    id = id,
    created = .sg_utc_now(),
    producer = .sg_producer(),
    coordinate_convention = .sg_coordinate_convention(),
    image = if (is.null(parts$image)) NULL else
      .sg_image_descriptor(parts$image),
    mask = if (is.null(parts$mask)) NULL else .sg_mask_descriptor(parts$mask),
    protocol = if (is.null(parts$run)) NULL else parts$run$record$protocol,
    run = if (is.null(parts$run)) NULL else parts$run$record,
    measurements = if (is.null(meas)) NULL else list(
      n_rows = nrow(meas), namespace = "derived",
      columns = I(c("image_id", "object_id", "label", "name", "namespace",
                    "value", "value_state", "unit", "provider_id")),
      names = I(setdiff(names(meas), "label"))
    ),
    runtime = .sg_runtime(),
    assets = assets,
    conversions = conversions,
    integrity_file = "integrity.json",
    extensions = .sg_json_object()
  )
  man <- man[!vapply(man, is.null, logical(1))]
  if (kind == "segmentation-run" && is.null(man$protocol)) {
    man$protocol <- NULL
  }
  man <- .sg_as_json_value(man)
  .sg_schema_assert(man, "manifest.schema.json", what = "manifest")
  structure(man, class = c("sg_manifest", "list"))
}

#' @export
print.sg_manifest <- function(x, ...) {
  cli::cli_text("{.cls sg_manifest} {x$schema} {x$schema_version}: {x$kind} {.val {x$id}}")
  if (!is.null(x$mask)) {
    cli::cli_text("Mask: {x$mask$shape_yx[[1]]} x {x$mask$shape_yx[[2]]}, {x$mask$label_count} label{?s}, {x$mask$review$status}")
  }
  cli::cli_text("Assets: {length(x$assets)}")
  invisible(x)
}

# ---- export -----------------------------------------------------------------

.sg_media_types <- c(
  manifest = "application/json", legend = "application/json",
  run = "application/json", geojson = "application/geo+json",
  qupath_geojson = "application/geo+json", mask_tiff = "image/tiff",
  image_tiff = "image/tiff", measurements_csv = "text/csv",
  measurements_parquet = "application/vnd.apache.parquet",
  rds = "application/x-rds", groovy = "text/x-groovy"
)

#' Export to the neutral interchange format
#'
#' Writes a bundle directory containing a manifest, the requested
#' representations and an `integrity.json` inventory with SHA-256 hashes and
#' relative paths. All representations describe the same envelope: the
#' integer mask TIFF holds exact labels, the GeoJSON holds exact pixel-edge
#' polygons in image coordinates with the same object ids, and the
#' measurements table uses the canonical long format (`value_state`
#' distinguishes missing, NaN and infinite values). RDS is an optional
#' R-native optimisation and never the only representation.
#'
#' @param x An `sg_mask`, `sg_run`, `sg_image`, or a named list with
#'   `image`, `mask`, `run`, `measurements`.
#' @param destination Directory to create. It must not exist or be empty;
#'   with `overwrite = TRUE` an existing segmantR bundle is replaced.
#' @param formats Any of `"manifest"`, `"mask_tiff"`, `"geojson"`,
#'   `"measurements"`, `"measurements_parquet"`, `"legend"`, `"image_tiff"`,
#'   `"run"`, `"rds"`. The manifest and integrity inventory are always
#'   written.
#' @param ... Reserved; must be empty.
#' @param image Optional `sg_image` for image descriptors, intensity
#'   measurements and `"image_tiff"`.
#' @param object_type QuPath object type for GeoJSON features
#'   (`"detection"`, `"annotation"` or `"cell"`).
#' @param overwrite Logical; replace an existing segmantR bundle.
#'
#' @return An `sg_interchange_bundle` (invisibly) with `path`, `manifest`
#'   and `bundle_digest`.
#' @export
#' @examples
#' m <- sg_example_mask("fluorescence_nuclei")
#' img <- sg_example_image("fluorescence_nuclei")
#' out <- sg_export_interchange(m, tempfile("bundle"), image = img)
#' list.files(out$path)
#' out$bundle_digest
sg_export_interchange <- function(x, destination,
                                  formats = c("manifest", "mask_tiff",
                                              "geojson", "measurements"),
                                  ..., image = NULL,
                                  object_type = c("detection", "annotation",
                                                  "cell"),
                                  overwrite = FALSE) {
  if (length(list(...))) {
    .sg_abort("Unused arguments in {.fn sg_export_interchange}.",
              code = "UNKNOWN_PARAMETER")
  }
  object_type <- match.arg(object_type)
  allowed <- c("manifest", "mask_tiff", "geojson", "measurements",
               "measurements_parquet", "legend", "image_tiff", "run", "rds")
  bad <- setdiff(formats, allowed)
  if (length(bad)) {
    .sg_abort("Unknown export format{?s} {.val {bad}}.",
              code = "UNKNOWN_PARAMETER")
  }
  parts <- .sg_interchange_parts(x, image)
  if (!is.null(parts$mask)) {
    parts$mask <- sg_mask_legend(parts$mask, materialise = TRUE)
  }
  need_mask <- intersect(formats, c("mask_tiff", "geojson", "legend",
                                    "measurements", "measurements_parquet"))
  if (length(need_mask) && is.null(parts$mask)) {
    .sg_abort("Format{?s} {.val {need_mask}} need{?s/} a mask.",
              code = "VALIDATION_FAILED")
  }
  if ("image_tiff" %in% formats && is.null(parts$image)) {
    .sg_abort("Format {.val image_tiff} needs an image.",
              code = "VALIDATION_FAILED")
  }
  if ("run" %in% formats && is.null(parts$run)) {
    .sg_abort("Format {.val run} needs an sg_run.", code = "VALIDATION_FAILED")
  }
  staging <- .sg_prepare_destination(destination, overwrite)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  assets <- list()
  conversions <- list()
  add_asset <- function(role, rel) {
    full <- file.path(staging, rel)
    assets[[length(assets) + 1L]] <<- list(
      role = role, path = rel, media_type = unname(.sg_media_types[role]),
      size_bytes = .sg_json_int(file.info(full)$size),
      sha256 = .sg_sha256_file(full)
    )
  }
  mask <- parts$mask
  legend <- if (is.null(mask)) NULL else sg_mask_legend(mask)
  wide <- NULL
  if (!is.null(mask)) {
    wide <- parts$measurements %||% .sg_measure_labels(
      mask$labels,
      pixels = if (is.null(parts$image)) NULL else parts$image$pixels,
      channels = if (is.null(parts$image)) NULL else parts$image$channels,
      origin = .sg_check_origin(mask$origin),
      pixel_size = if (is.null(parts$image)) list(x = NA, y = NA) else
        list(x = parts$image$resolution$x_um %||% NA_real_,
             y = parts$image$resolution$y_um %||% NA_real_)
    )
  }
  if ("mask_tiff" %in% formats) {
    desc <- .sg_ome_xml(dim(mask$labels), 1L, .sg_label_dtype(mask$labels),
                        pixel_size = if (is.null(parts$image)) NULL else
                          .sg_pixel_size(parts$image),
                        channels = "labels", name = "segmantR labels")
    .sg_write_tiff(mask$labels, file.path(staging, "mask.tif"),
                   dtype = .sg_label_dtype(mask$labels), description = desc)
    add_asset("mask_tiff", "mask.tif")
  }
  if ("legend" %in% formats || "mask_tiff" %in% formats) {
    leg <- list(schema = .sg_interchange_schema,
                schema_version = .sg_interchange_version, kind = "legend",
                mask_type = mask$mask_type %||% "instance", background = 0L,
                image_id = mask$image_id, entries = .sg_legend_rows(legend),
                extensions = .sg_json_object())
    .sg_schema_assert(leg, "legend.schema.json", what = "legend")
    .sg_write_json(leg, file.path(staging, "mask.legend.json"))
    add_asset("legend", "mask.legend.json")
  }
  if ("geojson" %in% formats) {
    gj <- .sg_mask_geojson(mask, legend, wide, object_type)
    .sg_write_text(.sg_canonical_json(gj), file.path(staging,
                                                     "objects.geojson"))
    add_asset("geojson", "objects.geojson")
    conversions[[length(conversions) + 1L]] <- list(
      from = "mask", to = "geojson", fidelity = "exact",
      notes = "Pixel-edge polygons; pixel-centre rasterisation restores the labels.",
      count = length(gj$features)
    )
  }
  if (any(c("measurements", "measurements_parquet") %in% formats)) {
    long <- .sg_measurements_long(
      wide, image_id = mask$image_id %||% NA_character_,
      object_ids = legend$object_id[match(wide$label, legend$label)]
    )
    if ("measurements" %in% formats) {
      .sg_write_measurements_csv(long, file.path(staging, "measurements.csv"))
      add_asset("measurements_csv", "measurements.csv")
    }
    if ("measurements_parquet" %in% formats) {
      if (!requireNamespace("nanoparquet", quietly = TRUE)) {
        .sg_abort_unavailable("Parquet export",
                              "Install the {.pkg nanoparquet} package.")
      }
      nanoparquet::write_parquet(as.data.frame(long),
                                 file.path(staging, "measurements.parquet"))
      add_asset("measurements_parquet", "measurements.parquet")
    }
  }
  if ("image_tiff" %in% formats) {
    img <- parts$image
    px <- img$pixels
    n_c <- if (length(dim(px)) == 3L) dim(px)[3] else 1L
    desc <- .sg_ome_xml(dim(px)[1:2], n_c, "float64",
                        pixel_size = .sg_pixel_size(img),
                        channels = img$channels, name = .sg_image_id(img))
    .sg_write_tiff(px, file.path(staging, "image.ome.tif"), dtype = "float64",
                   description = desc)
    add_asset("image_tiff", "image.ome.tif")
    conversions[[length(conversions) + 1L]] <- list(
      from = "sg_image", to = "ome-tiff", fidelity = "exact",
      notes = "float64 planes, one IFD per channel.", count = n_c
    )
  }
  if ("run" %in% formats) {
    .sg_write_json(parts$run$record, file.path(staging, "run.json"))
    add_asset("run", "run.json")
  }
  if ("rds" %in% formats) {
    saveRDS(list(image = parts$image, mask = mask, run = parts$run,
                 measurements = wide),
            file.path(staging, "bundle.rds"), version = 3)
    add_asset("rds", "bundle.rds")
  }
  man <- sg_interchange_manifest(
    list(image = parts$image, mask = mask, run = parts$run,
         measurements = wide),
    assets = assets, conversions = conversions
  )
  .sg_write_json(unclass(man), file.path(staging, "manifest.json"))
  inv <- sg_hash_assets(staging, write = "integrity")
  .sg_commit_destination(staging, destination)
  on.exit(NULL)
  bundle <- structure(list(path = normalizePath(destination, winslash = "/"),
                           manifest = man,
                           bundle_digest = inv$bundle_digest),
                      class = "sg_interchange_bundle")
  invisible(bundle)
}

#' @export
print.sg_interchange_bundle <- function(x, ...) {
  cli::cli_text("{.cls sg_interchange_bundle} {x$manifest$kind}: {length(x$manifest$assets)} asset{?s}")
  cli::cli_text("Bundle digest: {x$bundle_digest}")
  invisible(x)
}

#' Prepare a staging directory next to the destination
#' @noRd
.sg_prepare_destination <- function(destination, overwrite) {
  if (!is.character(destination) || length(destination) != 1L ||
      !nzchar(destination)) {
    .sg_abort("{.arg destination} must be a directory path.",
              code = "VALIDATION_FAILED")
  }
  if (file.exists(destination)) {
    if (!dir.exists(destination)) {
      .sg_abort("{.arg destination} exists and is not a directory.",
                class = "sg_conflict_error", code = "DESTINATION_EXISTS")
    }
    existing <- list.files(destination, all.files = TRUE, no.. = TRUE)
    if (length(existing)) {
      own <- file.exists(file.path(destination, "manifest.json")) &&
        file.exists(file.path(destination, "integrity.json"))
      if (!overwrite || !own) {
        .sg_abort(
          c("Destination directory is not empty.",
            "i" = if (own) "Use {.code overwrite = TRUE} to replace the existing bundle." else
              "Only empty directories or existing segmantR bundles can be used."),
          class = "sg_conflict_error", code = "DESTINATION_EXISTS"
        )
      }
    }
  }
  parent <- dirname(destination)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  staging <- tempfile(".sg_staging_", tmpdir = parent)
  dir.create(staging)
  staging
}

#' Move a staged bundle into place
#' @noRd
.sg_commit_destination <- function(staging, destination) {
  if (dir.exists(destination)) unlink(destination, recursive = TRUE)
  if (!file.rename(staging, destination)) {
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    files <- .sg_list_rel_files(staging)
    for (f in files) {
      dir.create(dirname(file.path(destination, f)), recursive = TRUE,
                 showWarnings = FALSE)
      file.copy(file.path(staging, f), file.path(destination, f))
    }
    unlink(staging, recursive = TRUE)
  }
  invisible(destination)
}

#' GeoJSON FeatureCollection for a mask
#' @noRd
.sg_mask_geojson <- function(mask, legend, wide = NULL,
                             object_type = "detection") {
  origin <- .sg_check_origin(mask$origin)
  plane <- .sg_check_plane(mask$plane)
  polys <- .sg_label_polygons(mask$labels, origin = origin)
  meas_cols <- if (is.null(wide)) character(0) else setdiff(names(wide), "label")
  features <- lapply(names(polys), function(lab_chr) {
    lab <- as.integer(lab_chr)
    row <- legend[legend$label == lab, , drop = FALSE]
    geom <- .sg_geojson_geometry(polys[[lab_chr]])
    if (plane$z != 0L || plane$t != 0L) {
      geom$plane <- list(c = -1L, z = plane$z, t = plane$t)
    }
    props <- list(objectType = object_type, label = lab,
                  object_id = row$object_id[1],
                  geometry_fidelity = "exact",
                  isLocked = FALSE)
    if (!is.na(row$class[1])) {
      props$classification <- list(name = row$class[1])
    }
    if (!is.na(row$name[1])) props$name <- row$name[1]
    if (length(meas_cols)) {
      w <- wide[wide$label == lab, , drop = FALSE]
      m <- lapply(meas_cols, function(nm) {
        v <- as.numeric(w[[nm]][1])
        if (is.finite(v)) v else NULL
      })
      names(m) <- meas_cols
      props$measurements <- .sg_json_object(m[!vapply(m, is.null,
                                                        logical(1))])
    }
    list(type = "Feature", id = row$object_id[1], geometry = geom,
         properties = props)
  })
  list(type = "FeatureCollection", features = features)
}

#' Write the canonical long measurement table as CSV with exact numbers
#' @noRd
.sg_write_measurements_csv <- function(long, path) {
  q <- function(v) {
    ifelse(is.na(v), "", paste0("\"", gsub("\"", "\"\"", v, fixed = TRUE),
                                "\""))
  }
  num <- vapply(long$value, function(v) {
    if (is.na(v) || !is.finite(v)) "" else .sg_json_number(v)
  }, character(1))
  cols <- c("image_id", "object_id", "label", "name", "namespace", "value",
            "value_state", "unit", "provider_id")
  body <- paste(q(long$image_id), q(long$object_id),
                ifelse(is.na(long$label), "", as.character(long$label)),
                q(long$name), q(long$namespace), num, q(long$value_state),
                q(long$unit), q(long$provider_id), sep = ",")
  .sg_write_text(paste0(paste(c(paste(cols, collapse = ","), body),
                              collapse = "\n"), "\n"), path)
}
