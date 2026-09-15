# QuPath adapter over the neutral interchange envelope

.sg_qupath_template_version <- "1.0.0"
.sg_qupath_templates <- c(stardist = "segmantR_stardist.groovy",
                          import = "segmantR_import.groovy",
                          export = "segmantR_export.groovy")

#' Export segmantR objects or a StarDist protocol for QuPath
#'
#' Writes a QuPath program directory: a declarative `run.json` (schema
#' `segmantR-qupath-run-v1`), the readable Groovy templates, the resources
#' they bind (a neutral interchange bundle or a hashed model copy), a
#' `run_export.json` for the way back, `checksums.sha256` and a `README.md`
#' with the interactive and command-line invocations. segmantR never starts
#' QuPath, Java or Groovy itself.
#'
#' * For an `sg_mask`, `sg_run` or list with a mask, the task is `import`:
#'   the mask is exported with [sg_export_interchange()] into `bundle/`
#'   (integer TIFF, exact GeoJSON with object ids, legend, measurements) and
#'   `segmantR_import.groovy` adds the objects to the open image after
#'   checking size, calibration, plane, SHA-256 and id collisions.
#' * For a StarDist protocol (`"stardist.2d.v1"` or an `sg_protocol`), the
#'   task is `stardist`: parameters are mapped with
#'   [sg_stardist_parameter_map()] (unsupported non-default options are
#'   errors unless `allow_unsupported = TRUE`, and are always listed in
#'   `run.json`), the model is copied into `models/` and its digest is
#'   recorded for verification by the template.
#'
#' @param x An `sg_mask`, `sg_run`, list with `mask`/`image`, or a StarDist
#'   protocol id / `sg_protocol`.
#' @param destination Output directory (must not exist or be empty).
#' @param ... Protocol parameter overrides for the `stardist` task.
#' @param image `sg_image` describing the QuPath image (size, pixel size,
#'   plane, channels). Required for the `stardist` task.
#' @param image_name Name of the image in the QuPath project (checked by
#'   the templates); `NULL` skips the name check.
#' @param model StarDist model file/directory or `sg_trained_model` for the
#'   `stardist` task.
#' @param region_policy `"whole_image"`, `"selected_annotations"` or
#'   `"all_annotations"`.
#' @param save_policy `"none"` (default) or `"project"`.
#' @param object_type QuPath object type for imported or exported objects.
#' @param require_calibration Logical; templates refuse uncalibrated images.
#' @param min_qupath_version Minimum QuPath version written to `run.json`.
#' @param allow_unsupported Logical; allow non-default parameters that the
#'   QuPath extension cannot honour (they are still listed).
#' @param overwrite Logical; replace an existing program directory created
#'   by segmantR.
#'
#' @return An `sg_qupath_program` (invisibly) with `path`, `task`, `run`
#'   (parsed `run.json`) and `commands` (headless command lines).
#' @export
#' @examples
#' m <- sg_example_mask("fluorescence_nuclei")
#' img <- sg_example_image("fluorescence_nuclei")
#' prog <- sg_export_qupath(m, tempfile("qupath"), image = img,
#'                          require_calibration = FALSE)
#' prog$commands[["import"]]
sg_export_qupath <- function(x, destination, ..., image = NULL,
                             image_name = NULL, model = NULL,
                             region_policy = c("whole_image",
                                               "selected_annotations",
                                               "all_annotations"),
                             save_policy = c("none", "project"),
                             object_type = c("detection", "annotation",
                                             "cell"),
                             require_calibration = TRUE,
                             min_qupath_version = "0.5.0",
                             allow_unsupported = FALSE, overwrite = FALSE) {
  region_policy <- match.arg(region_policy)
  save_policy <- match.arg(save_policy)
  object_type <- match.arg(object_type)
  is_protocol <- inherits(x, "sg_protocol") ||
    (is.character(x) && length(x) == 1L)
  task <- if (is_protocol) "stardist" else "import"
  if (task == "import" && length(list(...))) {
    .sg_abort("Parameter overrides are only used for the stardist task.",
              code = "UNKNOWN_PARAMETER")
  }
  staging <- .sg_prepare_destination(destination, overwrite)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  run_id <- .sg_new_run_id("qupath")
  if (task == "import") {
    parts <- .sg_interchange_parts(x, image)
    image <- parts$image
    if (is.null(parts$mask)) {
      .sg_abort("Nothing to import: {.arg x} has no mask.",
                code = "VALIDATION_FAILED")
    }
    bundle <- sg_export_interchange(
      list(image = image, mask = parts$mask, run = parts$run,
           measurements = parts$measurements),
      file.path(staging, "bundle"),
      formats = c("manifest", "mask_tiff", "geojson", "measurements",
                  "legend"),
      object_type = object_type
    )
    geo <- bundle$manifest$assets[vapply(bundle$manifest$assets,
                                         function(a) a$role == "geojson",
                                         logical(1))][[1]]
    shape <- as.integer(dim(parts$mask$labels))
    plane <- .sg_check_plane(parts$mask$plane)
    binding <- .sg_qupath_binding(image, shape, plane, image_name,
                                  require_calibration, run_id)
    run <- .sg_qupath_run(run_id, "import", binding, region_policy,
                          save_policy, min_qupath_version, NULL,
                          outputs = list(directory = "import_report",
                                         geojson = NULL, mask_tiff = NULL,
                                         measurements = NULL,
                                         native_measurements = NULL,
                                         manifest = "manifest.json",
                                         object_types = I(object_type)),
                          import = list(manifest = "bundle/manifest.json",
                                        geojson = paste0("bundle/", geo$path),
                                        geojson_sha256 = geo$sha256,
                                        object_type = object_type,
                                        replace_existing = FALSE))
  } else {
    p <- .sg_as_protocol(x)
    if (!identical(p$method$delegate, "sg_segment_stardist")) {
      .sg_abort("Only StarDist protocols can be exported as QuPath programs.",
                class = "sg_capability_error", code = "CAPABILITY_UNAVAILABLE")
    }
    if (is.null(image)) {
      .sg_abort("The stardist task needs {.arg image} for the image binding.",
                code = "VALIDATION_FAILED")
    }
    .sg_assert_image(image)
    if (is.null(model)) {
      .sg_abort(
        c("The stardist task needs a model file.",
          "i" = "QuPath loads .pb, SavedModel or bioimage.io models; pretrained names are not resolved."),
        code = "VALIDATION_FAILED"
      )
    }
    pmap <- sg_stardist_parameter_map(p, "qupath", ..., image = image)
    params <- attr(pmap, "parameters")
    bad <- pmap[pmap$status == "unsupported", , drop = FALSE]
    if (nrow(bad) && !allow_unsupported) {
      .sg_abort(
        c("Parameter{?s} {.val {bad$parameter}} cannot be honoured by the QuPath StarDist extension.",
          "i" = "Reset them to defaults or pass {.code allow_unsupported = TRUE}."),
        class = "sg_capability_error", code = "UNSUPPORTED_PARAMETER"
      )
    }
    # Validates shape, semantics and calibration requirements of the binding.
    .sg_check_inputs(p, list(image = image), params)
    model_src <- if (inherits(model, "sg_trained_model")) model$model_path else
      model
    sman <- sg_stardist_manifest(model)
    model_rel <- file.path("models", basename(model_src))
    dest <- file.path(staging, model_rel)
    if (isTRUE(file.info(model_src)$isdir)) {
      files <- vapply(sman$files, function(f) f$path, character(1))
      for (f in files) {
        dir.create(dirname(file.path(dest, f)), recursive = TRUE,
                   showWarnings = FALSE)
        file.copy(file.path(model_src, f), file.path(dest, f))
      }
    } else {
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      file.copy(model_src, dest)
    }
    if (!identical(.sg_model_inventory(dest)$digest, sman$digest)) {
      .sg_abort("Model copy does not match the source digest.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    ch_row <- pmap[pmap$parameter %in% c("channel", "channel_name",
                                         "wavelength_nm") &
                     pmap$status == "mapped", , drop = FALSE]
    channels <- ch_row$target_value[[1]]
    shape <- as.integer(dim(image$pixels)[1:2])
    plane <- .sg_image_plane(image)
    binding <- .sg_qupath_binding(image, shape, plane, image_name,
                                  require_calibration, run_id)
    measure <- unlist(p$output_contract$measurements)
    stardist <- list(
      model = list(path = model_rel,
                   representation = if (sman$representation %in%
                                        c("pb", "savedmodel", "bioimageio",
                                          "directory", "file"))
                     sman$representation else "unknown",
                   digest = sman$digest),
      threshold = params$prob_thresh,
      channels = I(channels),
      normalization = list(scope = params$normalize_scope,
                           low = params$normalize_low,
                           high = params$normalize_high,
                           max_dimension = if (params$normalize_scope ==
                                               "global") 4096L else NULL),
      pixel_size_um = params$pixel_size_um,
      tile_size = params$tile_size,
      include_probability = isTRUE(params$include_probability),
      cell_expansion_um = params$cell_expansion_um,
      cell_constrain_scale = NULL,
      create_annotations = isTRUE(params$create_annotations),
      classification = params$classification,
      measure_shape = any(c("area", "bbox") %in% measure),
      measure_intensity = "mean_intensity" %in% measure,
      n_threads = 1L
    )
    unsupported <- lapply(which(pmap$status %in% c("unsupported",
                                                   "approximated")),
                          function(i) {
      list(parameter = pmap$parameter[i], status = pmap$status[i],
           note = pmap$note[i])
    })
    run <- .sg_qupath_run(
      run_id, "stardist", binding, region_policy, save_policy,
      min_qupath_version,
      protocol = list(id = p$id, version = p$version,
                      digest = .sg_protocol_digest(p)),
      outputs = list(directory = "out", geojson = "objects.geojson",
                     mask_tiff = "mask.tif", measurements = "measurements.csv",
                     native_measurements = "qupath_detections.tsv",
                     manifest = "manifest.json",
                     object_types = I(if (isTRUE(params$create_annotations))
                       "annotation" else if (!is.null(params$cell_expansion_um))
                         "cell" else "detection")),
      stardist = stardist, unsupported = unsupported,
      parameters_digest = .sg_digest_json(.sg_params_json(params))
    )
    .sg_write_json(unclass(sman), file.path(staging, "models",
                                            "stardist_model.json"))
  }
  export_run <- run
  export_run$task <- "export"
  export_run$run_id <- paste0(run_id, "-export")
  export_run$stardist <- NULL
  export_run$import <- NULL
  export_run$save_policy <- "none"
  export_run$region_policy <- "whole_image"
  export_run$outputs <- list(directory = "qupath_export",
                             geojson = "objects.geojson",
                             mask_tiff = "mask.tif",
                             measurements = "measurements.csv",
                             native_measurements = "qupath_detections.tsv",
                             manifest = "manifest.json",
                             object_types = I(if (task == "import")
                               object_type else
                                 unlist(run$outputs$object_types)))
  export_run$expected_files <- I(paste0("qupath_export/",
                                        c("manifest.json", "integrity.json")))
  export_run$unsupported <- list()
  for (r in list(run, export_run)) {
    .sg_schema_assert(r, "qupath-run.schema.json", what = "QuPath run.json")
  }
  .sg_write_json(run, file.path(staging, "run.json"))
  .sg_write_json(export_run, file.path(staging, "run_export.json"))
  tpl <- unique(c(.sg_qupath_templates[[task]], .sg_qupath_templates[["export"]]))
  for (f in tpl) {
    src <- system.file("qupath", f, package = "segmantR")
    file.copy(src, file.path(staging, f))
  }
  commands <- .sg_qupath_commands(task, run, image_name)
  .sg_write_text(.sg_qupath_readme(task, run, commands),
                 file.path(staging, "README.md"))
  sg_hash_assets(staging, write = "sha256sum")
  .sg_commit_destination(staging, destination)
  on.exit(NULL)
  prog <- structure(list(path = normalizePath(destination, winslash = "/"),
                         task = task,
                         run = .sg_as_json_value(run),
                         commands = commands),
                    class = "sg_qupath_program")
  invisible(prog)
}

#' @export
print.sg_qupath_program <- function(x, ...) {
  cli::cli_text("{.cls sg_qupath_program} task {.val {x$task}}, run {x$run$run_id}")
  for (nm in names(x$commands)) cli::cli_text("{nm}: {.code {x$commands[[nm]]}}")
  invisible(x)
}

#' @noRd
.sg_qupath_binding <- function(image, shape, plane, image_name,
                               require_calibration, run_id) {
  ps <- if (is.null(image)) NULL else .sg_pixel_size(image)
  has_ps <- !is.null(ps) && !is.null(ps$x) && !is.null(ps$y)
  if (require_calibration && !has_ps) {
    .sg_abort(
      c("The image binding needs a pixel calibration.",
        "i" = "Set the image resolution or use {.code require_calibration = FALSE}."),
      class = "sg_calibration_error", code = "CALIBRATION_MISSING"
    )
  }
  list(
    image_name = image_name,
    image_id = if (is.null(image)) NULL else .sg_image_id(image),
    width = shape[2], height = shape[1],
    pixel_size_um = if (has_ps) list(x = ps$x, y = ps$y, tolerance = 1e-6)
    else NULL,
    plane = plane,
    channels = if (is.null(image)) NULL else I(as.character(image$channels)),
    require_calibration = isTRUE(require_calibration)
  )
}

#' @noRd
.sg_qupath_run <- function(run_id, task, binding, region_policy, save_policy,
                           min_qupath_version, protocol, outputs,
                           stardist = NULL, import = NULL,
                           unsupported = list(), parameters_digest = NULL) {
  qp <- .sg_detect_qupath()
  list(
    schema = "segmantR-qupath-run-v1",
    schema_version = "1.0.0",
    run_id = run_id,
    created = .sg_utc_now(),
    producer = .sg_producer(),
    task = task,
    template_version = .sg_qupath_template_version,
    qupath = list(
      min_version = min_qupath_version,
      tested_version = NULL,
      extension = if (task == "stardist") list(
        name = "qupath-extension-stardist", min_version = "0.5.0",
        tested_version = NULL) else NULL
    ),
    image_binding = binding,
    protocol = protocol,
    parameters_digest = parameters_digest,
    stardist = stardist,
    import = import,
    unsupported = unsupported,
    region_policy = region_policy,
    save_policy = save_policy,
    outputs = outputs,
    expected_files = I(if (task == "import") "import_report/import_report.json"
                       else paste0("out/", c("manifest.json",
                                             "integrity.json"))),
    extensions = .sg_json_object(list(
      detected_qupath = qp$version %||% NULL,
      detected_stardist_extension = if (is.na(qp$stardist_version)) NULL else
        qp$stardist_version
    ))
  )
}

#' @noRd
.sg_qupath_commands <- function(task, run, image_name) {
  img <- if (is.null(image_name)) "<image name>" else image_name
  save <- if (identical(run$save_policy, "project")) " --save" else ""
  main <- sprintf(
    "QuPath script --project=<project.qpproj> --image=\"%s\" --args=run.json%s %s",
    img, save, .sg_qupath_templates[[task]]
  )
  exp <- sprintf(
    "QuPath script --project=<project.qpproj> --image=\"%s\" --args=run_export.json segmantR_export.groovy",
    img
  )
  stats::setNames(list(main, exp), c(task, "export"))
}

#' @noRd
.sg_qupath_readme <- function(task, run, commands) {
  paste0(
    "# segmantR QuPath program (task: ", task, ")\n\n",
    "Run id: `", run$run_id, "`  \n",
    "Template version: ", run$template_version, "  \n",
    "Minimum QuPath: ", run$qupath$min_version, "\n\n",
    "## Headless\n\nRun from this directory (paths in run.json are relative to it):\n\n",
    "```\n", commands[[task]], "\n", commands[["export"]], "\n```\n\n",
    "`--save` is only part of the command when run.json declares ",
    "`save_policy: \"project\"`.\n\n",
    "## Interactive (Script editor)\n\n",
    "Copy this directory to `<project>/segmantR/`, open the image, open `",
    .sg_qupath_templates[[task]], "` in *Automate > Script editor* and run ",
    "it. Without `--args` the template reads `<project>/segmantR/run.json`. ",
    "To export afterwards, rename `run_export.json` to `run.json` or run ",
    "`segmantR_export.groovy` from the command line.\n\n",
    "## Way back\n\nImport the export directory in R:\n\n",
    "```r\nrep <- segmantR::sg_import_qupath(\"",
    if (task == "stardist") "out" else "qupath_export", "\")\n```\n\n",
    "Verify this directory with `sha256sum -c checksums.sha256`.\n"
  )
}

#' Import QuPath results into segmantR
#'
#' Reads the output of the segmantR QuPath templates (a directory with a
#' `qupath-export` manifest and `integrity.json`), a QuPath program
#' directory containing such an output (`out/` or `qupath_export/`), or a
#' plain QuPath GeoJSON export. All checks of [sg_import_interchange()] run
#' (inventory, schema, dtype, shape/orientation, legend, content digest and
#' revision); in addition the QuPath GeoJSON is rasterised and compared with
#' the QuPath label TIFF, object ids are matched through the legend, the
#' run id and image binding can be checked, and measurements are imported
#' in the canonical long format (`namespace = "stored"`). The mask is
#' staged.
#'
#' @param path Export directory, program directory or GeoJSON file.
#' @param ... Reserved; must be empty.
#' @param image Optional `sg_image` to check the binding (size, pixel size,
#'   plane) or to rasterise a plain GeoJSON.
#' @param expected_run_id Optional run id (`run.json` `run_id`) the export
#'   must belong to.
#' @param error Logical; signal failures instead of reporting them.
#'
#' @return An `sg_import_report` with an extra `qupath` element (QuPath and
#'   extension versions, template version, run id, GeoJSON/TIFF agreement).
#' @export
#' @examples
#' \donttest{
#' # rep <- sg_import_qupath("path/to/out")
#' }
sg_import_qupath <- function(path, ..., image = NULL, expected_run_id = NULL,
                             error = TRUE) {
  if (length(list(...))) {
    .sg_abort("Unused arguments in {.fn sg_import_qupath}.",
              code = "UNKNOWN_PARAMETER")
  }
  if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
    .sg_abort("QuPath export path does not exist.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  if (dir.exists(path) && !file.exists(file.path(path, "manifest.json"))) {
    cand <- file.path(path, c("out", "qupath_export"))
    cand <- cand[file.exists(file.path(cand, "manifest.json"))]
    if (length(cand) == 0L) {
      .sg_abort("No QuPath export (manifest.json) found.",
                class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
    }
    path <- cand[1]
  }
  if (!dir.exists(path)) {
    rep <- sg_import_interchange(path, format = "geojson", image = image,
                                 error = error)
    if (isTRUE(rep$ok)) {
      rep$measurements <- .sg_geojson_measurements(
        rep$features, sg_mask_legend(rep$mask),
        if (is.null(image)) NA_character_ else .sg_image_id(image)
      )
      rep$qupath <- list(source = "geojson")
    }
    return(rep)
  }
  rep <- sg_import_interchange(path, error = error)
  if (!isTRUE(rep$ok)) return(rep)
  man <- rep$manifest
  qp <- man$extensions$qupath
  checks <- .sg_checklist()
  res <- tryCatch({
    if (!identical(man$kind, "qupath-export")) {
      .sg_abort("Manifest kind is {.val {man$kind}}, not qupath-export.",
                code = "VALIDATION_FAILED")
    }
    if (!is.null(expected_run_id) && !identical(man$id, expected_run_id)) {
      .sg_abort("Export belongs to run {.val {man$id}}, not {.val {expected_run_id}}.",
                class = "sg_conflict_error", code = "REVISION_CONFLICT")
    }
    checks$add("qupath_run", "ok", man$id)
    if (!is.null(image)) {
      .sg_assert_image(image)
      shape <- unlist(man$mask$shape_yx)
      if (!identical(as.integer(dim(image$pixels)[1:2]), as.integer(shape))) {
        .sg_abort("QuPath export is {shape[1]} x {shape[2]} px but the image is {nrow(image$pixels)} x {ncol(image$pixels)}.",
                  code = "DIMENSION_MISMATCH")
      }
      ps <- .sg_pixel_size(image)
      mps <- man$image$pixel_size
      if (!is.null(ps$x) && !is.null(mps$x) &&
          (abs(ps$x - mps$x) > 1e-6 || abs(ps$y - mps$y) > 1e-6)) {
        .sg_abort("Pixel size of the QuPath image differs from the segmantR image.",
                  class = "sg_calibration_error", code = "CALIBRATION_MISSING")
      }
      ip <- .sg_image_plane(image)
      if (ip$z != man$mask$plane$z || ip$t != man$mask$plane$t) {
        .sg_abort("QuPath export plane differs from the image plane.",
                  code = "INVALID_PLANE")
      }
      checks$add("image_binding", "ok", "size, pixel size and plane agree")
    }
    roles <- vapply(man$assets, function(a) a$role, character(1))
    hit <- which(roles == "qupath_geojson")
    gpath <- if (length(hit)) man$assets[[hit[1]]]$path else NULL
    agreement <- NULL
    if (!is.null(gpath)) {
      gj <- .sg_read_geojson(file.path(path, gpath))
      legend <- sg_mask_legend(rep$mask)
      ras <- .sg_rasterise_features(gj$features, unlist(man$mask$shape_yx),
                                    .sg_origin_from_json(man$mask$origin),
                                    legend, checks,
                                    reference = rep$mask$labels)
      if (ras$exact_mismatch > 0L) {
        .sg_abort(
          "{ras$exact_mismatch_features} exact QuPath GeoJSON feature{?s} disagree{?s/} with the label TIFF.",
          code = "VALIDATION_FAILED",
          details = list(pixels = ras$exact_mismatch)
        )
      }
      diff <- sum(ras$labels != rep$mask$labels)
      agreement <- list(differing_pixels = as.integer(diff),
                        total_pixels = length(rep$mask$labels),
                        exact = isTRUE(ras$exact))
      checks$add("qupath_geojson_vs_tiff",
                 if (diff == 0L) "ok" else "approximated",
                 sprintf("%d of %d pixels differ", diff,
                         length(rep$mask$labels)))
      rep$features <- gj$features
      if (is.null(rep$measurements)) {
        rep$measurements <- .sg_geojson_measurements(gj$features, legend,
                                                     man$image$id)
      }
    }
    rep$qupath <- list(source = "template", version = qp$version,
                       stardist_extension_version = qp$stardist_extension_version,
                       template_version = qp$template_version,
                       task = qp$task, run_id = man$id,
                       agreement = agreement)
    rep
  }, sg_error = function(e) {
    if (error) stop(e)
    checks$add("qupath", "failed", conditionMessage(e))
    rep$ok <- FALSE
    rep$error <- e
    rep
  })
  res$checks <- rbind(res$checks, checks$table())
  res
}

#' Canonical long measurements from QuPath GeoJSON properties
#' @noRd
.sg_geojson_measurements <- function(features, legend, image_id) {
  rows <- list()
  for (f in features) {
    m <- f$properties$measurements
    if (is.null(m) || length(m) == 0L) next
    id <- as.character(f$id %||% f$properties$object_id %||% NA_character_)
    lab <- legend$label[match(id, legend$object_id)]
    if (is.null(names(m))) {
      nms <- vapply(m, function(e) as.character(e$name), character(1))
      vals <- lapply(m, function(e) e$value)
    } else {
      nms <- names(m)
      vals <- unname(m)
    }
    v <- vapply(vals, function(x) {
      if (is.null(x)) NA_real_ else if (is.character(x)) {
        switch(x, "NaN" = NaN, "Infinity" = Inf, "-Infinity" = -Inf, NA_real_)
      } else as.numeric(x)
    }, numeric(1))
    rows[[length(rows) + 1L]] <- tibble::tibble(
      image_id = image_id, object_id = id, label = as.integer(lab),
      name = nms, namespace = "stored", value = ifelse(is.finite(v), v, NA),
      value_state = .sg_value_state(v), unit = "unknown",
      provider_id = "qupath"
    )
  }
  if (length(rows) == 0L) {
    return(.sg_measurements_long(tibble::tibble(label = integer(0))))
  }
  do.call(rbind, rows)
}
