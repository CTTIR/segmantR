# Trained model class, packaging, loading, and model card

#' Create a new sg_trained_model object
#'
#' Constructor for the `sg_trained_model` S3 class, representing a trained
#' segmentation model with associated metadata.
#'
#' @param model_path Character. Path to the trained model weights.
#' @param backend Character. Segmentation backend: `"cellpose"` or
#'   `"stardist"`.
#' @param base_model Character. Name of the base model that was fine-tuned.
#' @param training_metrics Named list of training metrics (e.g., loss curve,
#'   number of epochs).
#' @param model_card Named list of model card metadata (description, author,
#'   intended use, etc.). The versioned card written by [sg_package_model()]
#'   reads `purpose`, `data_domain`, `channels`, `target_pixel_size_um`,
#'   `input_value_semantics`, `normalization`, `limitations` (character),
#'   `evaluation` (named list of metrics) and `license` from here.
#' @param runtime Optional runtime description (list) recorded at training
#'   time; never a copy of a Python environment.
#' @param dataset_manifest Optional `sg_dataset_manifest` the model was
#'   trained on.
#' @param license Optional list with `id` (e.g. an SPDX identifier), `name`,
#'   `source` and `text`.
#' @param representation Weight representation: `"pb"`, `"savedmodel"`,
#'   `"bioimageio"`, `"pytorch"`, `"keras"`, `"directory"`, `"file"` or
#'   `"unknown"`.
#'
#' @return An object of class `sg_trained_model`.
#' @export
#' @examples
#' mdl <- new_sg_trained_model(
#'   model_path = tempdir(),
#'   backend = "cellpose",
#'   base_model = "cyto3",
#'   training_metrics = list(n_epochs = 100L, final_loss = 0.05)
#' )
#' print(mdl)
new_sg_trained_model <- function(model_path, backend = c("cellpose", "stardist"),
                                 base_model, training_metrics,
                                 model_card = list(), runtime = NULL,
                                 dataset_manifest = NULL, license = NULL,
                                 representation = "unknown") {
  backend <- match.arg(backend)
  stopifnot(is.character(model_path), length(model_path) == 1L)
  stopifnot(is.character(base_model), length(base_model) == 1L)
  stopifnot(is.list(training_metrics))
  stopifnot(is.list(model_card))
  representation <- match.arg(representation, .sg_weight_representations)
  if (!is.null(license)) stopifnot(is.list(license))

  structure(
    list(
      model_path = model_path,
      backend = backend,
      base_model = base_model,
      training_metrics = training_metrics,
      model_card = model_card,
      created = Sys.time(),
      runtime = runtime,
      dataset_manifest = dataset_manifest,
      license = license,
      representation = representation,
      bundle_digest = NULL,
      integrity = "not_packaged"
    ),
    class = "sg_trained_model"
  )
}

.sg_weight_representations <- c("unknown", "pb", "savedmodel", "bioimageio",
                                 "pytorch", "keras", "directory", "file")

#' @export
print.sg_trained_model <- function(x, ...) {
  cli::cli_text("{.cls sg_trained_model}")
  cli::cli_text("Backend: {x$backend}")
  cli::cli_text("Base model: {x$base_model}")
  cli::cli_text("Model path: {.path {x$model_path}}")
  if (!is.null(x$training_metrics$n_epochs)) {
    cli::cli_text("Epochs: {x$training_metrics$n_epochs}")
  }
  if (!is.null(x$training_metrics$final_loss)) {
    cli::cli_text("Final loss: {round(x$training_metrics$final_loss, 4)}")
  }
  cli::cli_text("Created: {format(x$created, '%Y-%m-%d %H:%M:%S')}")
  invisible(x)
}

#' @export
summary.sg_trained_model <- function(object, ...) {
  cli::cli_text("{.cls sg_trained_model} Summary")
  cli::cli_rule()
  cli::cli_text("Backend: {object$backend}")
  cli::cli_text("Base model: {object$base_model}")
  cli::cli_text("Model path: {.path {object$model_path}}")
  cli::cli_rule(left = "Training Metrics")
  for (nm in names(object$training_metrics)) {
    val <- object$training_metrics[[nm]]
    if (inherits(val, "POSIXct")) {
      val <- format(val, "%Y-%m-%d %H:%M:%S")
    }
    cli::cli_text("{nm}: {val}")
  }
  if (length(object$model_card) > 0L) {
    cli::cli_rule(left = "Model Card")
    for (nm in names(object$model_card)) {
      cli::cli_text("{nm}: {object$model_card[[nm]]}")
    }
  }
  invisible(object)
}

#' @export
#' @importFrom ggplot2 ggplot aes geom_line labs theme_minimal
plot.sg_trained_model <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(c(
      "Plotting requires the {.pkg ggplot2} package.",
      "i" = "Install with: {.code install.packages('ggplot2')}"
    ))
  }

  loss <- x$training_metrics$loss
  if (is.null(loss)) {
    cli::cli_inform("No loss curve data available in training metrics.")
    return(invisible(NULL))
  }

  df <- tibble::tibble(
    epoch = seq_along(loss),
    loss = as.numeric(loss)
  )

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$epoch, y = .data$loss)) +
    ggplot2::geom_line(linewidth = 0.8, colour = "#2563EB") +
    ggplot2::labs(
      title = paste("Training Loss:", x$backend, "-", x$base_model),
      x = "Epoch",
      y = "Loss"
    ) +
    ggplot2::theme_minimal()
  p
}

#' Package a trained model for sharing
#'
#' Creates a `.segmantR` archive (ZIP format) containing model weights,
#' a `model_card.json`, and optionally training data.
#'
#' The archive keeps relative paths and contains a versioned
#' `model_card.json` (schema `segmantR-model-card-v1`, still carrying the
#' fields written by segmantR 0.1.0), `runtime.json`, `dataset_manifest.json`
#' when the model has one, `license.json` when a license is given, the
#' weights under `weights/` (or a hashed relative reference when
#' `embed_weights = FALSE`) and `checksums.sha256` covering every file.
#' Python environments are never copied into a bundle.
#'
#' @param trained_model An `sg_trained_model` object.
#' @param output_path Character. Path for the output archive file.
#' @param name Character or `NULL`. Human-readable model name.
#' @param description Character or `NULL`. Short description of the model.
#' @param include_training_data Logical. Include training data in the archive?
#'   Default `FALSE`. When `TRUE`, the dataset manifest (not the pixels) is
#'   included; tiles stay in their own integrity-checked dataset directory.
#' @param format Character. Archive format: `"segmantR"` (default),
#'   `"cellpose"`, or `"both"`.
#' @param embed_weights Logical; copy weights into the archive (default) or
#'   record them as a hashed reference relative to the archive directory.
#' @param license Optional license list (`id`, `name`, `source`, `text`);
#'   defaults to `trained_model$license`.
#' @param overwrite Logical; replace an existing archive.
#'
#' @return The output file path, returned invisibly.
#' @export
#' @examples
#' \donttest{
#' mdl <- new_sg_trained_model(
#'   model_path = tempdir(),
#'   backend = "cellpose",
#'   base_model = "cyto3",
#'   training_metrics = list(n_epochs = 50L)
#' )
#' out <- sg_package_model(mdl, tempfile(fileext = ".segmantR"))
#' }
sg_package_model <- function(trained_model, output_path, name = NULL,
                             description = NULL,
                             include_training_data = FALSE,
                             format = c("segmantR", "cellpose", "both"),
                             embed_weights = TRUE, license = NULL,
                             overwrite = TRUE) {
  if (!inherits(trained_model, "sg_trained_model")) {
    cli::cli_abort("{.arg trained_model} must be an {.cls sg_trained_model} object.")
  }
  format <- match.arg(format)
  if (file.exists(output_path) && !overwrite) {
    .sg_abort("Archive {.file {basename(output_path)}} already exists.",
              class = "sg_conflict_error", code = "DESTINATION_EXISTS")
  }

  staging_dir <- tempfile("segmantR_pkg_")
  dir.create(staging_dir, recursive = TRUE)
  on.exit(unlink(staging_dir, recursive = TRUE), add = TRUE)

  # Copy or reference model weights (relative structure preserved)
  model_src <- trained_model$model_path
  weight_files <- list()
  representation <- trained_model$representation %||% "unknown"
  relative_to <- "bundle"
  if (file.exists(model_src)) {
    is_dir <- isTRUE(file.info(model_src)$isdir)
    src_root <- if (is_dir) model_src else dirname(model_src)
    rel <- if (is_dir) {
      .sg_list_rel_files(model_src)
    } else {
      basename(model_src)
    }
    rel <- rel[!grepl("(^|/)\\.", rel)]
    if (representation == "unknown") {
      representation <- .sg_guess_representation(model_src, rel)
    }
    full <- file.path(src_root, rel)
    if (embed_weights) {
      dest <- file.path(staging_dir, "weights", rel)
      for (d in unique(dirname(dest))) dir.create(d, recursive = TRUE,
                                                  showWarnings = FALSE)
      file.copy(full, dest, overwrite = TRUE)
      paths <- file.path("weights", rel)
    } else {
      relative_to <- "bundle_parent"
      prefix <- if (is_dir) basename(model_src) else NULL
      paths <- if (is.null(prefix)) rel else file.path(prefix, rel)
    }
    hashes <- .sg_sha256_file(full)
    sizes <- file.info(full)$size
    weight_files <- lapply(seq_along(paths), function(i) {
      list(path = paths[i], size_bytes = .sg_json_int(sizes[i]),
           sha256 = hashes[i])
    })
  }
  weights_digest <- if (length(weight_files)) {
    .sg_digest_json(weight_files)
  } else {
    NULL
  }

  mc <- trained_model$model_card %||% list()
  lic <- license %||% trained_model$license
  lic_file <- NULL
  if (!is.null(lic)) {
    lic_doc <- list(
      schema = "segmantR-license-v1",
      id = lic$id %||% NULL, name = lic$name %||% NULL,
      source = lic$source %||% NULL, text = lic$text %||% NULL
    )
    .sg_write_json(lic_doc, file.path(staging_dir, "license.json"))
    lic_file <- "license.json"
  }
  runtime <- trained_model$runtime %||% .sg_runtime()
  runtime <- utils::modifyList(.sg_runtime(), as.list(runtime))
  runtime$schema <- .sg_interchange_schema
  runtime$kind <- "runtime"
  .sg_schema_assert(runtime, "runtime.schema.json", what = "runtime")
  .sg_write_json(runtime, file.path(staging_dir, "runtime.json"))
  ds_file <- NULL
  ds <- trained_model$dataset_manifest
  if (!is.null(ds)) {
    .sg_write_json(unclass(ds), file.path(staging_dir, "dataset_manifest.json"))
    ds_file <- "dataset_manifest.json"
  }
  eval_metrics <- mc$evaluation %||% list()

  # Build model card (legacy fields kept for 0.1.0 readers)
  card <- list(
    schema = "segmantR-model-card-v1",
    schema_version = "1.0.0",
    name = name %||% paste0(trained_model$backend, "_", trained_model$base_model),
    description = description %||% "Trained segmentation model",
    backend = trained_model$backend,
    base_model = trained_model$base_model,
    purpose = mc$purpose %||% NULL,
    data_domain = mc$data_domain %||% NULL,
    channels = I(as.character(unlist(mc$channels %||%
                                       (if (!is.null(ds)) ds$channels) %||%
                                       character(0)))),
    target_pixel_size_um = mc$target_pixel_size_um %||% NULL,
    input_value_semantics = mc$input_value_semantics %||%
      (if (!is.null(ds)) ds$value_semantics) %||% "unknown",
    normalization = mc$normalization %||%
      (if (!is.null(ds)) ds$normalization) %||% NULL,
    limitations = I(as.character(unlist(mc$limitations %||% character(0)))),
    license = list(id = lic$id %||% NULL, file = lic_file,
                   source = lic$source %||% NULL),
    evaluation = list(metrics = .sg_json_object(eval_metrics),
                      dataset_digest = if (!is.null(ds)) ds$dataset_digest
                      else NULL,
                      split = mc$evaluation_split %||% NULL),
    weights = list(embedded = isTRUE(embed_weights),
                   representation = representation,
                   relative_to = relative_to,
                   digest = weights_digest,
                   files = weight_files),
    dataset_manifest = ds_file,
    runtime = "runtime.json",
    training_metrics = .sg_json_object(trained_model$training_metrics),
    model_card = .sg_json_object(mc),
    created = format(trained_model$created, "%Y-%m-%dT%H:%M:%S"),
    packaged = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    segmantR_version = as.character(utils::packageVersion("segmantR")),
    format = format,
    extensions = .sg_json_object()
  )
  .sg_schema_assert(card, "model-card.schema.json", what = "model card")
  .sg_write_json(card, file.path(staging_dir, "model_card.json"))
  if (isTRUE(include_training_data) && is.null(ds)) {
    cli::cli_inform(c("!" = "No dataset manifest attached; nothing to include."))
  }
  sg_hash_assets(staging_dir, write = "sha256sum")

  # Create ZIP with relative paths
  if (file.exists(output_path)) unlink(output_path)
  .sg_zip_dir(staging_dir, output_path)

  cli::cli_inform(c("v" = "Model packaged to {.path {output_path}}."))
  invisible(output_path)
}

#' Guess the weight representation from files
#' @noRd
.sg_guess_representation <- function(src, rel) {
  if (any(rel == "saved_model.pb" | grepl("/saved_model\\.pb$", rel))) {
    return("savedmodel")
  }
  if (any(grepl("rdf\\.ya?ml$", rel))) return("bioimageio")
  if (any(grepl("\\.pb$", rel))) return("pb")
  if (any(grepl("\\.(pt|pth)$", rel))) return("pytorch")
  if (any(grepl("\\.(h5|keras)$", rel))) return("keras")
  if (isTRUE(file.info(src)$isdir)) "directory" else "file"
}

#' Zip a directory keeping relative paths
#' @noRd
.sg_zip_dir <- function(dir, zipfile) {
  rel <- .sg_list_rel_files(dir)
  zipfile <- normalizePath(zipfile, winslash = "/", mustWork = FALSE)
  if (requireNamespace("zip", quietly = TRUE)) {
    zip::zip(zipfile, files = rel, root = dir, mode = "mirror")
  } else {
    owd <- setwd(dir)
    on.exit(setwd(owd), add = TRUE)
    utils::zip(zipfile, files = rel, flags = "-9Xq")
  }
  invisible(zipfile)
}

#' Load a packaged segmantR model
#'
#' Reads a `.segmantR` archive created by [sg_package_model()] and
#' returns an `sg_trained_model` object.
#'
#' Before extracting, entry names are checked (no absolute paths, parent
#' segments, backslashes or drive letters; entry count and total size
#' limits). After extraction, symbolic links are rejected, `checksums.sha256`
#' is verified (missing, extra or modified files are errors), the model card
#' schema and major version and the backend are checked. Archives written by
#' segmantR 0.1.0 have no checksums; they load with `integrity =
#' "unverified"` unless `allow_legacy = FALSE`.
#'
#' @param path Character. Path to the `.segmantR` archive file.
#' @param expected_digest Optional `"sha256:<hex>"` digest of the archive's
#'   `checksums.sha256` content (reported as `bundle_digest`).
#' @param allow_legacy Logical; accept archives without checksums.
#'
#' @return An `sg_trained_model` object.
#' @export
#' @examples
#' \donttest{
#' # model <- sg_load_model("my_model.segmantR")
#' }
sg_load_model <- function(path, expected_digest = NULL, allow_legacy = TRUE) {
  if (!file.exists(path)) {
    cli::cli_abort("Model file not found: {.path {path}}")
  }

  listing <- tryCatch(utils::unzip(path, list = TRUE), error = function(e) {
    .sg_abort("Model archive is not a readable ZIP file.",
              class = "sg_integrity_error", code = "ARCHIVE_UNSAFE")
  }, warning = function(w) {
    .sg_abort("Model archive is not a readable ZIP file.",
              class = "sg_integrity_error", code = "ARCHIVE_UNSAFE")
  })
  .sg_check_archive_listing(listing)
  extract_dir <- tempfile("segmantR_load_")
  dir.create(extract_dir, recursive = TRUE)
  ok <- tryCatch({
    utils::unzip(path, exdir = extract_dir)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok) {
    .sg_abort("Model archive could not be extracted (corrupt archive).",
              class = "sg_integrity_error", code = "ARCHIVE_UNSAFE")
  }
  links <- list.files(extract_dir, recursive = TRUE, full.names = TRUE,
                      all.files = TRUE)
  if (any(nzchar(Sys.readlink(links)))) {
    .sg_abort("Model archive contains symbolic links.",
              class = "sg_security_error", code = "ARCHIVE_UNSAFE")
  }

  # Find model_card.json
  card_path <- list.files(extract_dir, pattern = "model_card\\.json$",
                          recursive = TRUE, full.names = TRUE)
  if (length(card_path) == 0L) {
    cli::cli_abort("No {.file model_card.json} found in archive {.path {path}}.")
  }
  card <- .sg_read_json(card_path[1])

  integrity <- "unverified"
  bundle_digest <- NULL
  if (file.exists(file.path(extract_dir, "checksums.sha256"))) {
    inv <- .sg_verify_inventory(extract_dir)
    if (!inv$ok) {
      shown <- utils::head(inv$problems, 8L)
      .sg_abort(c("Model archive checksums do not match its content.",
                  stats::setNames(.sg_cli_escape(shown),
                                  rep("x", length(shown)))),
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
                details = list(problems = inv$problems))
    }
    integrity <- "verified"
    bundle_digest <- inv$digest
  } else if (!allow_legacy) {
    .sg_abort("Model archive has no checksums.sha256.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  } else {
    cli::cli_inform(c("!" = "Legacy model archive without checksums; integrity is not verified."))
  }
  if (!is.null(expected_digest) && !identical(expected_digest, bundle_digest)) {
    .sg_abort("Model archive digest does not match {.arg expected_digest}.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
              details = list(expected = expected_digest,
                             actual = bundle_digest))
  }
  if (!is.null(card$schema)) {
    if (!identical(card$schema, "segmantR-model-card-v1") ||
        is.null(.sg_semver(card$schema_version %||% "")) ||
        .sg_semver(card$schema_version)$major != 1L) {
      .sg_abort("Unsupported model card schema {.val {card$schema}} {card$schema_version %||% ''}.",
                class = "sg_protocol_error", code = "PROTOCOL_MISMATCH")
    }
    .sg_schema_assert(card, "model-card.schema.json", what = "model card")
  }
  backend <- card$backend %||% "cellpose"
  if (!backend %in% c("cellpose", "stardist")) {
    .sg_abort("Unsupported model backend {.val {backend}}.",
              class = "sg_capability_error", code = "UNSUPPORTED_BACKEND")
  }

  # Find weights
  model_path <- if (dir.exists(file.path(extract_dir, "weights"))) {
    file.path(extract_dir, "weights")
  } else {
    weights_dir <- list.dirs(extract_dir, recursive = TRUE, full.names = TRUE)
    weights_match <- weights_dir[grepl("weights", weights_dir)]
    if (length(weights_match) > 0L) weights_match[1] else extract_dir
  }
  w <- card$weights
  if (!is.null(w)) {
    files_ok <- is.list(w) && is.list(w$files %||% list()) &&
      all(vapply(w$files %||% list(), function(f) {
        is.list(f) && is.character(f$path) && length(f$path) == 1L &&
          is.character(f$sha256) && grepl("^[0-9a-f]{64}$", f$sha256)
      }, logical(1)))
    if (!files_ok || (!isTRUE(w$embedded) && length(w$files) == 0L)) {
      .sg_abort("Model card weights section is malformed.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
  }
  if (!is.null(w) && !isTRUE(w$embedded)) {
    base <- dirname(normalizePath(path, winslash = "/"))
    for (f in w$files) {
      full <- .sg_resolve_in_root(base, f$path, must_exist = TRUE)
      if (.sg_sha256_file(full) != f$sha256) {
        .sg_abort("Referenced weight file {.file {f$path}} does not match its hash.",
                  class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
      }
    }
    first <- strsplit(w$files[[1]]$path, "/", fixed = TRUE)[[1]][1]
    model_path <- file.path(base, first)
  }

  read_opt <- function(name) {
    p <- file.path(extract_dir, name)
    if (file.exists(p)) .sg_read_json(p) else NULL
  }
  lic <- read_opt("license.json")
  result <- new_sg_trained_model(
    model_path = model_path,
    backend = backend,
    base_model = card$base_model %||% "unknown",
    training_metrics = card$training_metrics %||% list(),
    model_card = card$model_card %||% list(),
    runtime = read_opt("runtime.json"),
    dataset_manifest = read_opt("dataset_manifest.json"),
    license = if (is.null(lic)) NULL else lic[c("id", "name", "source", "text")],
    representation = w$representation %||% "unknown"
  )
  result$bundle_digest <- bundle_digest
  result$weights_digest <- w$digest %||% NULL
  result$integrity <- integrity
  result$card <- card

  cli::cli_inform(c(
    "v" = "Loaded model from {.path {path}}.",
    "i" = "Backend: {result$backend}, base: {result$base_model}."
  ))
  result
}

#' Reject unsafe archive entry names and zip bombs
#' @noRd
.sg_check_archive_listing <- function(listing) {
  names <- listing$Name
  if (length(names) > .sg_limits$max_archive_entries) {
    .sg_abort("Model archive has too many entries.",
              class = "sg_integrity_error", code = "ARCHIVE_UNSAFE")
  }
  if (sum(as.numeric(listing$Length)) > .sg_limits$max_archive_bytes) {
    .sg_abort("Model archive expands beyond the size limit.",
              class = "sg_integrity_error", code = "ARCHIVE_UNSAFE")
  }
  # Directory entries ("dir/") are validated without their trailing slash.
  files <- sub("/$", "", names)
  bad <- vapply(files, function(n) {
    tryCatch({
      .sg_check_relpath(n)
      FALSE
    }, sg_error = function(e) TRUE)
  }, logical(1))
  if (any(bad)) {
    .sg_abort("Model archive contains unsafe entry names ({.val {utils::head(files[bad], 3)}}).",
              class = "sg_security_error", code = "ARCHIVE_UNSAFE")
  }
  invisible(TRUE)
}

#' Display a formatted model card
#'
#' Prints a human-readable model card for a trained segmentation model and
#' returns the card contents as a tibble.
#'
#' @param trained_model An `sg_trained_model` object.
#'
#' @return A tibble with columns `field` and `value` representing the model
#'   card contents, returned invisibly.
#' @export
#' @examples
#' mdl <- new_sg_trained_model(
#'   model_path = tempdir(),
#'   backend = "cellpose",
#'   base_model = "cyto3",
#'   training_metrics = list(n_epochs = 100L),
#'   model_card = list(author = "Test User", tissue = "lung")
#' )
#' sg_model_card(mdl)
sg_model_card <- function(trained_model) {
  if (!inherits(trained_model, "sg_trained_model")) {
    cli::cli_abort("{.arg trained_model} must be an {.cls sg_trained_model} object.")
  }

  fields <- character(0)
  values <- character(0)

  # Core fields
  core <- list(
    "Backend" = trained_model$backend,
    "Base Model" = trained_model$base_model,
    "Model Path" = trained_model$model_path,
    "Created" = format(trained_model$created, "%Y-%m-%d %H:%M:%S")
  )
  fields <- c(fields, names(core))
  values <- c(values, vapply(core, as.character, character(1)))

  # Training metrics
  tm <- trained_model$training_metrics
  for (nm in names(tm)) {
    val <- tm[[nm]]
    if (inherits(val, "POSIXct")) {
      val <- format(val, "%Y-%m-%d %H:%M:%S")
    } else if (is.numeric(val) && length(val) == 1L) {
      val <- as.character(val)
    } else {
      val <- paste(val, collapse = ", ")
    }
    fields <- c(fields, paste0("Metric: ", nm))
    values <- c(values, val)
  }

  # Model card extras
  mc <- trained_model$model_card
  for (nm in names(mc)) {
    fields <- c(fields, nm)
    values <- c(values, as.character(mc[[nm]]))
  }

  # Print
  cli::cli_rule(left = "Model Card")
  for (i in seq_along(fields)) {
    cli::cli_text("{.strong {fields[i]}}: {values[i]}")
  }
  cli::cli_rule()

  result <- tibble::tibble(field = fields, value = values)
  invisible(result)
}
