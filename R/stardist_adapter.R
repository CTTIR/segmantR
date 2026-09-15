# StarDist adapter: capabilities, model manifests and parameter maps

# Builder options of the QuPath StarDist extension used by the templates.
# "verified" = method name present in qupath-extension-stardist 0.6.0 (jar
# inspection, 2026-09-14); "documented_min" = extension version from which
# the QuPath documentation describes the option. Older versions are reported
# as "unknown", never as supported.
.sg_stardist_qupath_options <- tibble::tibble(
  option = c("threshold", "channels", "normalizePercentiles",
             "preprocessGlobal", "pixelSize", "tileSize",
             "includeProbability", "cellExpansion", "cellConstrainScale",
             "createAnnotations", "classify", "measureShape",
             "measureIntensity", "nThreads"),
  protocol_parameter = c("prob_thresh", "channel/channel_name",
                         "normalize_low/normalize_high (tile)",
                         "normalize_low/normalize_high (global)",
                         "pixel_size_um", "tile_size", "include_probability",
                         "cell_expansion_um", "<fixed>",
                         "create_annotations", "classification",
                         "output_contract.measurements",
                         "output_contract.measurements", "<fixed>"),
  verified_in = "0.6.0",
  documented_min = "0.5.0"
)

#' StarDist adapter capabilities
#'
#' Reports which StarDist options can be mapped for Python (reticulate) and
#' for the QuPath StarDist extension, for a detected or declared QuPath and
#' extension version. Detection reads installation files only (QuPath is
#' not started). Options are `supported` for extension versions at or above
#' the documented minimum, `unknown` for older versions and `unavailable`
#' when the extension is missing.
#'
#' @param qupath_version Optional QuPath version to evaluate (default:
#'   detected installation).
#' @param extension_version Optional StarDist extension version (default:
#'   detected jar in the QuPath user directory).
#' @param check_python Logical; probe the Python `stardist` module
#'   (initialises Python).
#'
#' @return An `sg_stardist_capabilities` list with `qupath`, `extension`,
#'   `python`, `options` (tibble) and `parameters` (tibble from
#'   [sg_stardist_parameter_map()] for both targets).
#' @export
#' @examples
#' caps <- sg_stardist_capabilities(qupath_version = "0.7.0",
#'                                  extension_version = "0.6.0")
#' caps$options[, c("option", "status")]
sg_stardist_capabilities <- function(qupath_version = NULL,
                                     extension_version = NULL,
                                     check_python = FALSE) {
  detected <- if (is.null(qupath_version) || is.null(extension_version)) {
    .sg_detect_qupath()
  } else {
    list(found = FALSE, version = NULL, stardist_version = NA_character_)
  }
  qv <- qupath_version %||% detected$version
  ev <- extension_version %||%
    (if (is.na(detected$stardist_version)) NULL else detected$stardist_version)
  status_for <- function(min) {
    if (is.null(ev)) return("unavailable")
    ok <- tryCatch(numeric_version(ev) >= numeric_version(min),
                   error = function(e) NA)
    if (isTRUE(ok)) "supported" else "unknown"
  }
  opts <- .sg_stardist_qupath_options
  opts$status <- vapply(opts$documented_min, status_for, character(1))
  qp_ok <- !is.null(qv) && isTRUE(tryCatch(
    numeric_version(qv) >= numeric_version("0.5.0"), error = function(e) FALSE))
  py <- if (check_python) {
    st <- .sg_backend_status("python-stardist")
    list(checked = TRUE, available = st$available, reason = st$reason)
  } else {
    list(checked = FALSE, available = NA, reason = "Not probed.")
  }
  structure(list(
    qupath = list(version = qv, source = if (!is.null(qupath_version))
      "declared" else if (isTRUE(detected$found)) "detected" else "none",
      supported = qp_ok),
    extension = list(name = "qupath-extension-stardist", version = ev,
                     source = if (!is.null(extension_version)) "declared"
                     else if (!is.null(ev)) "detected" else "none"),
    python = py,
    options = opts,
    parameters = rbind(
      sg_stardist_parameter_map("stardist.2d.v1", "python"),
      sg_stardist_parameter_map("stardist.2d.v1", "qupath")
    )
  ), class = "sg_stardist_capabilities")
}

#' @export
print.sg_stardist_capabilities <- function(x, ...) {
  cli::cli_text("{.cls sg_stardist_capabilities}")
  cli::cli_text("QuPath: {x$qupath$version %||% 'not found'} ({x$qupath$source}); extension: {x$extension$version %||% 'not found'} ({x$extension$source})")
  cli::cli_text("Python stardist: {if (isTRUE(x$python$checked)) x$python$available else 'not probed'}")
  tab <- table(x$options$status)
  cli::cli_text("QuPath options: {paste(names(tab), tab, sep = '=', collapse = ', ')}")
  invisible(x)
}

#' Map StarDist protocol parameters to Python or QuPath
#'
#' Every declared parameter of the protocol appears in the result with the
#' target option, the target value and a status: `mapped`, `approximated`,
#' `unsupported`, `not_applicable` or `runner` (handled by segmantR before
#' delegation). Unknown parameters are errors; nothing is dropped silently.
#'
#' @param protocol Protocol id or `sg_protocol` (StarDist family).
#' @param target `"python"` (reticulate, [sg_segment_stardist()]) or
#'   `"qupath"` (StarDist extension builder).
#' @param ... Parameter overrides.
#' @param image Optional `sg_image` used to resolve channel indices and
#'   wavelengths to channel names for QuPath.
#'
#' @return A tibble with `parameter`, `value`, `target`, `target_option`,
#'   `target_value`, `status` and `note`; attribute `parameters` holds the
#'   resolved parameters.
#' @export
#' @examples
#' sg_stardist_parameter_map("stardist.2d.v1", "qupath", prob_thresh = 0.6)
sg_stardist_parameter_map <- function(protocol = "stardist.2d.v1",
                                      target = c("python", "qupath"), ...,
                                      image = NULL) {
  target <- match.arg(target)
  p <- .sg_as_protocol(protocol)
  if (!identical(p$method$delegate, "sg_segment_stardist")) {
    .sg_abort("{.val {p$id}} is not a StarDist protocol.",
              code = "VALIDATION_FAILED")
  }
  params <- .sg_resolve_parameters(p, list(...))
  defaults <- lapply(p$parameters, function(s) s[["default"]])
  is_default <- function(nm) identical(params[[nm]], defaults[[nm]])
  rows <- list()
  add <- function(parameter, option, tval, status, note) {
    rows[[length(rows) + 1L]] <<- tibble::tibble(
      parameter = parameter, value = list(params[[parameter]]),
      target = target, target_option = option, target_value = list(tval),
      status = status, note = note
    )
  }
  chan_names <- if (is.null(image)) NULL else image$channels
  if (target == "python") {
    add("channel", "<runner: sg_select_channel>", params$channel, "runner",
        "1-based channel selected before inference.")
    add("channel_name", "<runner: sg_select_channel>", params$channel_name,
        "runner", "Name resolved to a channel before inference.")
    add("wavelength_nm", "<runner: sg_select_channel>", params$wavelength_nm,
        "runner", "Nearest band within wavelength_tolerance_nm.")
    add("wavelength_tolerance_nm", "<runner>", params$wavelength_tolerance_nm,
        "runner", "Tolerance for wavelength selection.")
    add("model", "StarDist2D.from_pretrained", params$model, "mapped",
        "A model input (sg_trained_model) overrides the pretrained name.")
    add("prob_thresh", "predict_instances(prob_thresh)", params$prob_thresh,
        "mapped", "")
    add("nms_thresh", "predict_instances(nms_thresh)", params$nms_thresh,
        "mapped", "")
    add("normalize_low", "<runner: percentile>", params$normalize_low,
        "runner", "Global percentile normalisation applied in R.")
    add("normalize_high", "<runner: percentile>", params$normalize_high,
        "runner", "Global percentile normalisation applied in R.")
    add("normalize_scope", "<runner>", params$normalize_scope,
        if (identical(params$normalize_scope, "global")) "runner" else
          "unsupported",
        "Only global normalisation is available in the Python path.")
    add("pixel_size_um", "predict_instances(scale)", params$pixel_size_um,
        "mapped", "scale = image pixel size / pixel_size_um.")
    add("tile_size", "predict_instances(n_tiles)", params$tile_size,
        if (is.null(params$tile_size)) "mapped" else "approximated",
        "n_tiles = ceiling(dimension / tile_size); tile edges are chosen by StarDist.")
    add("include_probability", "details$prob", params$include_probability,
        "approximated", "Probabilities stay in model_info details.")
    add("cell_expansion_um", NA_character_, params$cell_expansion_um,
        if (is.null(params$cell_expansion_um)) "not_applicable" else
          "unsupported", "Cell expansion exists only in QuPath.")
    add("create_annotations", NA_character_, params$create_annotations,
        if (isTRUE(params$create_annotations)) "unsupported" else
          "not_applicable", "QuPath object types do not exist in R.")
    add("classification", "legend class", params$classification, "mapped",
        "Stored as the legend class of every object.")
  } else {
    ch_value <- if (!is.null(params$channel_name)) {
      params$channel_name
    } else if (!is.null(params$wavelength_nm)) {
      if (is.null(image)) NA else sg_select_channel(
        image, wavelength_nm = params$wavelength_nm,
        wavelength_tolerance_nm = params$wavelength_tolerance_nm)$channels
    } else if (!is.null(chan_names) &&
               length(chan_names) >= params$channel) {
      chan_names[params$channel]
    } else {
      params$channel - 1L
    }
    add("channel", "channels", if (is.null(params$channel_name) &&
                                   is.null(params$wavelength_nm)) ch_value
        else NA,
        if (is.null(params$channel_name) && is.null(params$wavelength_nm))
          "mapped" else "not_applicable",
        "QuPath channels() takes names or 0-based indices.")
    add("channel_name", "channels", params$channel_name,
        if (is.null(params$channel_name)) "not_applicable" else "mapped", "")
    add("wavelength_nm", "channels", if (!is.null(params$wavelength_nm))
      ch_value else NA,
      if (is.null(params$wavelength_nm)) "not_applicable" else if
      (is.null(image)) "unsupported" else "mapped",
      "QuPath has no wavelength selector; resolved to a channel name with the image.")
    add("wavelength_tolerance_nm", "<export>", params$wavelength_tolerance_nm,
        "runner", "Used when resolving wavelength_nm at export.")
    add("model", "StarDist2D.builder(modelPath)", params$model,
        "not_applicable",
        "QuPath needs a model file (.pb, SavedModel or bioimage.io); pretrained names are not resolved.")
    add("prob_thresh", "threshold", params$prob_thresh, "mapped", "")
    add("nms_thresh", NA_character_, params$nms_thresh,
        if (is_default("nms_thresh")) "approximated" else "unsupported",
        "The extension has no NMS threshold option; it resolves overlaps itself.")
    scope <- params$normalize_scope
    add("normalize_low", if (scope == "tile") "normalizePercentiles" else
      "preprocessGlobal(percentiles)", params$normalize_low,
      if (scope == "tile") "mapped" else "approximated",
      if (scope == "tile") "Per-tile percentiles." else
        "Global percentiles are computed on an image downsampled to maxDimension 4096.")
    add("normalize_high", if (scope == "tile") "normalizePercentiles" else
      "preprocessGlobal(percentiles)", params$normalize_high,
      if (scope == "tile") "mapped" else "approximated", "")
    add("normalize_scope", "<builder choice>", scope, "mapped",
        "tile -> normalizePercentiles, global -> preprocessGlobal.")
    add("pixel_size_um", "pixelSize", params$pixel_size_um, "mapped", "")
    add("tile_size", "tileSize", params$tile_size, "mapped",
        "null keeps the extension default.")
    add("include_probability", "includeProbability",
        params$include_probability, "mapped", "")
    add("cell_expansion_um", "cellExpansion", params$cell_expansion_um,
        "mapped", "")
    add("create_annotations", "createAnnotations",
        params$create_annotations, "mapped", "")
    add("classification", "classify", params$classification, "mapped", "")
  }
  out <- do.call(rbind, rows)
  missing <- setdiff(names(p$parameters), out$parameter)
  if (length(missing)) {
    .sg_abort("Parameter map misses {.val {missing}}.",
              class = "sg_protocol_error", code = "SCHEMA_MISMATCH")
  }
  attr(out, "parameters") <- params
  out
}

#' Describe a StarDist model for exchange
#'
#' Hashes the model files and records representation, channels, pixel size,
#' normalisation, license and the runtimes that can load the representation
#' (`.pb` for QuPath/OpenCV, SavedModel for QuPath/TensorFlow, bioimage.io
#' for the extension's bioimage.io support, a Python model directory for
#' `stardist`).
#'
#' @param model Path to a `.pb` file, a SavedModel or Python model directory,
#'   a bioimage.io folder, or an `sg_trained_model` with backend
#'   `"stardist"`.
#' @param ... Reserved; must be empty.
#' @param name Model name (default: file/directory name).
#' @param channels Optional channel names the model expects.
#' @param n_channels_in Optional number of input channels.
#' @param pixel_size_um Optional pixel size the model was trained for.
#' @param normalization Optional list (e.g. `list(method = "percentile",
#'   low = 1, high = 99.8)`).
#' @param license_id Optional SPDX identifier.
#' @param source Optional short provenance text (no URLs are fetched).
#'
#' @return An `sg_stardist_manifest` list conforming to
#'   `stardist-model.schema.json`; `digest` follows the integrity inventory
#'   rule and is what `run.json` and the Groovy template verify.
#' @export
#' @examples
#' f <- tempfile(fileext = ".pb")
#' writeBin(as.raw(1:10), f)
#' sg_stardist_manifest(f, n_channels_in = 1L)$representation
sg_stardist_manifest <- function(model, ..., name = NULL, channels = NULL,
                                 n_channels_in = NULL, pixel_size_um = NULL,
                                 normalization = NULL, license_id = NULL,
                                 source = NULL) {
  if (length(list(...))) {
    .sg_abort("Unused arguments in {.fn sg_stardist_manifest}.",
              code = "UNKNOWN_PARAMETER")
  }
  if (inherits(model, "sg_trained_model")) {
    if (!identical(model$backend, "stardist")) {
      .sg_abort("The model backend must be stardist.", code = "VALIDATION_FAILED")
    }
    mc <- model$model_card %||% list()
    channels <- channels %||% unlist(mc$channels)
    pixel_size_um <- pixel_size_um %||% mc$target_pixel_size_um
    normalization <- normalization %||% mc$normalization
    license_id <- license_id %||% model$license$id
    model <- model$model_path
  }
  if (!is.character(model) || length(model) != 1L || !file.exists(model)) {
    .sg_abort("StarDist model path does not exist.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  inv <- .sg_model_inventory(model)
  rel <- vapply(inv$files, function(f) f$path, character(1))
  representation <- if (!isTRUE(file.info(model)$isdir)) {
    if (grepl("\\.pb$", model)) "pb" else "file"
  } else if (any(rel == "saved_model.pb")) {
    "savedmodel"
  } else if (any(grepl("^rdf\\.ya?ml$", rel))) {
    "bioimageio"
  } else if (any(rel == "config.json") && any(grepl("\\.h5$", rel))) {
    "keras"
  } else {
    "directory"
  }
  lic_file <- rel[grepl("^LICEN[CS]E", rel, ignore.case = TRUE)][1]
  man <- list(
    schema = .sg_interchange_schema,
    schema_version = .sg_interchange_version,
    kind = "stardist-model",
    name = name %||% basename(model),
    representation = representation,
    files = inv$files,
    digest = inv$digest,
    channels = if (is.null(channels)) NULL else I(as.character(channels)),
    n_channels_in = if (is.null(n_channels_in)) {
      if (is.null(channels)) NULL else length(channels)
    } else {
      as.integer(n_channels_in)
    },
    pixel_size_um = pixel_size_um,
    normalization = normalization,
    license = list(id = license_id, file = if (is.na(lic_file)) NULL else
      lic_file),
    source = source,
    compatibility = list(
      python_stardist = representation %in% c("keras", "directory"),
      qupath_opencv = representation == "pb",
      qupath_tensorflow = representation == "savedmodel",
      qupath_bioimageio = representation == "bioimageio"
    ),
    extensions = .sg_json_object()
  )
  man <- .sg_as_json_value(man)
  .sg_schema_assert(man, "stardist-model.schema.json",
                    what = "StarDist model manifest")
  structure(man, class = c("sg_stardist_manifest", "list"))
}

#' Inventory digest of model files (hidden files excluded)
#' @noRd
.sg_model_inventory <- function(path) {
  if (isTRUE(file.info(path)$isdir)) {
    rel <- .sg_list_rel_files(path)
    rel <- rel[!startsWith(basename(rel), ".")]
    full <- file.path(path, rel)
  } else {
    rel <- basename(path)
    full <- path
  }
  if (length(rel) == 0L) {
    .sg_abort("Model directory is empty.", class = "sg_integrity_error",
              code = "INTEGRITY_MISMATCH")
  }
  sizes <- file.info(full)$size
  hashes <- .sg_sha256_file(full)
  files <- lapply(seq_along(rel), function(i) {
    list(path = rel[i], size_bytes = .sg_json_int(sizes[i]),
         sha256 = hashes[i])
  })
  list(files = files,
       digest = .sg_digest_json(list(format_version = "1.0", files = files)))
}
