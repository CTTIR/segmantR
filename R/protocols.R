# Versioned, declarative protocol registry (segmantR-protocol-v1)

.sg_registry <- new.env(parent = emptyenv())

# Parameters handled by the runner itself (channel/band selection) rather
# than mapped one-to-one to a delegate argument.
.sg_selection_params <- c("channel", "channel_name", "wavelength_nm",
                          "wavelength_tolerance_nm", "band_operation",
                          "band_a_nm", "band_b_nm", "band_min_nm",
                          "band_max_nm")

#' Load all shipped protocol definitions (cached)
#' @noRd
.sg_registry_protocols <- function() {
  if (!is.null(.sg_registry$protocols)) return(.sg_registry$protocols)
  dir <- system.file("protocols", package = "segmantR")
  files <- sort(list.files(dir, pattern = "\\.json$", full.names = TRUE))
  protos <- lapply(files, function(f) {
    p <- .sg_protocol_from_list(.sg_read_json(f), source = "registry")
    if (!identical(paste0(p$id, ".json"), basename(f))) {
      .sg_abort("Registry file {.file {basename(f)}} does not match id {.val {p$id}}.",
                class = "sg_protocol_error", code = "SCHEMA_MISMATCH")
    }
    p
  })
  names(protos) <- vapply(protos, function(p) p$id, character(1))
  .sg_registry$protocols <- protos
  protos
}

#' Validate a parsed protocol definition and wrap it as sg_protocol
#' @noRd
.sg_protocol_from_list <- function(def, source = "user") {
  if (inherits(def, "sg_protocol")) return(def)
  if (!is.list(def) || is.null(names(def))) {
    .sg_abort("A protocol must be a JSON object / named list.",
              code = "VALIDATION_FAILED")
  }
  def <- .sg_as_json_value(unclass(def))
  family <- def$schema %||% ""
  major <- .sg_family_major(family)
  if (!is.character(family) || !startsWith(family, "segmantR-protocol-v") ||
      is.na(major)) {
    .sg_abort("Unknown protocol schema {.val {family}}.",
              class = "sg_protocol_error", code = "SCHEMA_MISMATCH",
              details = list(schema = family))
  }
  if (major != 1L) {
    .sg_abort(
      c("Protocol schema major version {major} is not supported.",
        "i" = "This segmantR understands {.val segmantR-protocol-v1}."),
      class = "sg_protocol_error", code = "PROTOCOL_MISMATCH",
      details = list(schema = family)
    )
  }
  sv <- .sg_semver(def$version %||% "")
  id_major <- .sg_family_major(sub("\\.v([0-9]+)$", "-v\\1", def$id %||% ""))
  if (is.null(sv)) {
    .sg_abort("Protocol version must be a semantic version (x.y.z).",
              code = "VALIDATION_FAILED", details = list(field = "version"))
  }
  if (!is.na(id_major) && sv$major != id_major) {
    .sg_abort(
      "Protocol {.val {def$id}} declares version {def$version}; major version must be {id_major}.",
      class = "sg_protocol_error", code = "PROTOCOL_MISMATCH",
      details = list(id = def$id, version = def$version)
    )
  }
  errs <- .sg_schema_errors(def, "protocol.schema.json", normalise = FALSE)
  if (length(errs)) {
    shown <- utils::head(errs, 8L)
    .sg_abort(
      c("Protocol does not conform to {.file protocol.schema.json}.",
        stats::setNames(.sg_cli_escape(shown), rep("x", length(shown)))),
      code = "VALIDATION_FAILED", details = list(errors = errs)
    )
  }
  params <- def$parameters
  mapping <- def$method$mapping
  roles <- vapply(def$input_contract$inputs, function(i) i$role, character(1))
  clash <- intersect(roles, names(params))
  if (length(clash)) {
    .sg_abort("Input role{?s} {.val {clash}} collide{?s/} with parameter names.",
              code = "VALIDATION_FAILED")
  }
  unmapped_keys <- setdiff(names(mapping), names(params))
  if (length(unmapped_keys)) {
    .sg_abort("Protocol mapping refers to undeclared parameter{?s} {.val {unmapped_keys}}.",
              code = "VALIDATION_FAILED")
  }
  missing_map <- setdiff(names(params), c(names(mapping),
                                          .sg_selection_params))
  if (length(missing_map)) {
    .sg_abort(
      "Parameter{?s} {.val {missing_map}} {?is/are} neither mapped nor handled by the runner.",
      code = "VALIDATION_FAILED"
    )
  }
  for (nm in names(params)) {
    spec <- params[[nm]]
    msg <- .sg_check_param_value(nm, spec$default, spec)
    if (!is.null(msg)) {
      .sg_abort("Default of parameter {.field {nm}} is invalid: {msg}",
                code = "VALIDATION_FAILED", details = list(parameter = nm))
    }
  }
  for (step in def$postprocess$steps) {
    cleanup <- .sg_registry_protocols_raw("postprocess.label-cleanup.v1")
    unknown <- setdiff(names(step$parameters), names(cleanup$parameters))
    if (length(unknown)) {
      .sg_abort("Postprocess step uses unknown parameter{?s} {.val {unknown}}.",
                code = "UNKNOWN_PARAMETER")
    }
  }
  structure(def, class = c("sg_protocol", "list"), source = source)
}

#' Raw cleanup protocol definition without recursion through validation
#' @noRd
.sg_registry_protocols_raw <- function(id) {
  f <- system.file("protocols", paste0(id, ".json"), package = "segmantR")
  .sg_read_json(f)
}

#' Check one parameter value against its specification
#' @return NULL if valid, otherwise a message.
#' @noRd
.sg_check_param_value <- function(name, value, spec) {
  if (is.null(value)) {
    return(if (isTRUE(spec$nullable)) NULL else "must not be null")
  }
  if (is.list(value) || length(value) != 1L || is.na(value)) {
    return("must be a single non-missing value")
  }
  type <- spec$type
  ok <- switch(
    type,
    integer = is.numeric(value) && is.finite(value) && value == trunc(value),
    number = is.numeric(value) && is.finite(value),
    boolean = is.logical(value),
    string = is.character(value),
    FALSE
  )
  if (!ok) return(paste("must be of type", type))
  if (!is.null(spec$enum)) {
    allowed <- unlist(spec$enum)
    if (!(value %in% allowed)) {
      return(paste0("must be one of ", paste(allowed, collapse = ", ")))
    }
  }
  if (!is.null(spec$minimum) && value < spec$minimum) {
    return(paste(">= ", spec$minimum, "required"))
  }
  if (!is.null(spec$maximum) && value > spec$maximum) {
    return(paste("<=", spec$maximum, "required"))
  }
  if (!is.null(spec$exclusive_minimum) && value <= spec$exclusive_minimum) {
    return(paste(">", spec$exclusive_minimum, "required"))
  }
  if (isTRUE(spec$odd) && value != 0 && value %% 2 != 1) {
    return("must be 0 or an odd integer")
  }
  NULL
}

#' Resolve effective parameters from defaults and overrides
#' @noRd
.sg_resolve_parameters <- function(protocol, overrides = list()) {
  specs <- protocol$parameters
  unknown <- setdiff(names(overrides), names(specs))
  if (length(unknown)) {
    .sg_abort(
      c("Unknown parameter{?s} {.val {unknown}}.",
        "i" = "Protocol: {.val {protocol$id}}.",
        "i" = "Declared parameters: {.val {names(specs)}}."),
      code = "UNKNOWN_PARAMETER",
      details = list(protocol = protocol$id, parameters = unknown)
    )
  }
  params <- lapply(specs, function(s) s[["default"]])
  names(params) <- names(specs)
  for (nm in names(overrides)) {
    params[nm] <- list(overrides[[nm]])
  }
  problems <- character(0)
  for (nm in names(specs)) {
    msg <- .sg_check_param_value(nm, params[[nm]], specs[[nm]])
    if (!is.null(msg)) {
      problems <- c(problems, paste0(nm, ": ", msg))
      next
    }
    v <- params[[nm]]
    if (!is.null(v)) {
      params[[nm]] <- switch(specs[[nm]]$type, integer = as.integer(v),
                             number = as.numeric(v), v)
    }
  }
  if (length(problems)) {
    .sg_abort(
      c("Invalid parameter value(s) for {.val {protocol$id}}.",
        stats::setNames(.sg_cli_escape(problems),
                        rep("x", length(problems)))),
      code = "PARAMETER_OUT_OF_RANGE",
      details = list(protocol = protocol$id, problems = problems)
    )
  }
  explicit <- names(overrides)
  if (all(c("channel_name", "wavelength_nm") %in% names(params)) &&
      !is.null(params$channel_name) && !is.null(params$wavelength_nm)) {
    .sg_abort("Set either {.field channel_name} or {.field wavelength_nm}, not both.",
              code = "VALIDATION_FAILED")
  }
  if ("channel" %in% explicit &&
      (!is.null(params$channel_name) || !is.null(params$wavelength_nm) ||
       !identical(params$band_operation %||% "none", "none"))) {
    .sg_abort("Ambiguous channel selection: {.field channel} was given together with another selector.",
              code = "VALIDATION_FAILED")
  }
  if (!is.null(params$diameter) && !is.null(params$diameter_um)) {
    .sg_abort("Set either {.field diameter} or {.field diameter_um}, not both.",
              code = "VALIDATION_FAILED")
  }
  if (!is.null(params$normalize_low) && !is.null(params$normalize_high) &&
      params$normalize_low >= params$normalize_high) {
    .sg_abort("{.field normalize_low} must be smaller than {.field normalize_high}.",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  if (!is.null(params$max_area) && !is.null(params$min_area) &&
      params$min_area > params$max_area) {
    .sg_abort("{.field min_area} must not exceed {.field max_area}.",
              code = "PARAMETER_OUT_OF_RANGE")
  }
  params
}

#' List registered segmentation protocols
#'
#' @param check_available Logical; if `TRUE`, probe optional Python backends
#'   (this initialises Python through reticulate). Default `FALSE` reports
#'   `NA` availability for optional backends.
#'
#' @return A tibble with one row per protocol: `id`, `version`, `title`,
#'   `family`, `backend`, `delegate`, `requires_python`, `status`
#'   (`"core"` or `"optional"`), `available`, `qupath_mapping` and `digest`.
#' @export
#' @examples
#' sg_protocol_list()
sg_protocol_list <- function(check_available = FALSE) {
  protos <- .sg_registry_protocols()
  rows <- lapply(protos, function(p) {
    needs_py <- isTRUE(p$runtime_profile$requires_python)
    avail <- if (!needs_py) {
      TRUE
    } else if (check_available) {
      .sg_backend_status(p$method$backend)$available
    } else {
      NA
    }
    tibble::tibble(
      id = p$id, version = p$version, title = p$title, family = p$family,
      backend = p$method$backend, delegate = p$method$delegate,
      requires_python = needs_py,
      status = if (needs_py) "optional" else "core",
      available = avail,
      qupath_mapping = !is.null(p$runtime_profile$qupath),
      digest = .sg_protocol_digest(p)
    )
  })
  do.call(rbind, unname(rows))
}

#' Get a registered protocol
#'
#' @param id Protocol identifier, e.g. `"threshold.otsu.v1"`.
#' @param version Optional exact semantic version. `NULL` returns the
#'   registered version.
#'
#' @return An `sg_protocol` object (a validated named list).
#' @export
#' @examples
#' p <- sg_protocol_get("threshold.otsu.v1")
#' p$version
sg_protocol_get <- function(id, version = NULL) {
  if (!is.character(id) || length(id) != 1L || is.na(id)) {
    .sg_abort("{.arg id} must be a single protocol identifier.",
              code = "VALIDATION_FAILED")
  }
  protos <- .sg_registry_protocols()
  p <- protos[[id]]
  if (is.null(p)) {
    .sg_abort(
      c("Protocol {.val {id}} is not registered.",
        "i" = "Available: {.val {names(protos)}}."),
      class = "sg_protocol_error", code = "PROTOCOL_NOT_FOUND",
      details = list(id = id)
    )
  }
  if (!is.null(version) && !identical(version, p$version)) {
    req <- .sg_semver(version)
    code <- if (!is.null(req) && req$major != .sg_semver(p$version)$major) {
      "PROTOCOL_MISMATCH"
    } else {
      "PROTOCOL_NOT_FOUND"
    }
    .sg_abort(
      "Protocol {.val {id}} version {.val {version}} is not available (registered: {.val {p$version}}).",
      class = "sg_protocol_error", code = code,
      details = list(id = id, requested = version, available = p$version)
    )
  }
  p
}

#' Protocol schema and parameter specifications
#'
#' @param id `NULL` for the JSON Schema of `segmantR-protocol-v1` (as a
#'   parsed list), or a protocol id for its parameter table.
#'
#' @return For `id = NULL`, the parsed JSON Schema. Otherwise a tibble with
#'   `name`, `type`, `default`, `nullable`, `minimum`, `maximum`, `enum`,
#'   `unit`, `requires_calibration`, `maps_to` and `description`.
#' @export
#' @examples
#' names(sg_protocol_schema()$properties)
#' sg_protocol_schema("threshold.otsu.v1")[, c("name", "default", "unit")]
sg_protocol_schema <- function(id = NULL) {
  if (is.null(id)) {
    return(.sg_load_schema("protocol.schema.json"))
  }
  p <- if (inherits(id, "sg_protocol")) id else sg_protocol_get(id)
  specs <- p$parameters
  mapping <- p$method$mapping
  num_or_na <- function(v) if (is.null(v)) NA_real_ else as.numeric(v)
  tibble::tibble(
    name = names(specs),
    type = vapply(specs, function(s) s$type, character(1)),
    default = unname(lapply(specs, function(s) s[["default"]])),
    nullable = vapply(specs, function(s) isTRUE(s$nullable), logical(1)),
    minimum = vapply(specs, function(s) {
      num_or_na(s$minimum %||% s$exclusive_minimum)
    }, numeric(1)),
    maximum = vapply(specs, function(s) num_or_na(s$maximum), numeric(1)),
    enum = unname(lapply(specs, function(s) unlist(s$enum))),
    unit = vapply(specs, function(s) s$unit, character(1)),
    requires_calibration = vapply(specs, function(s) {
      isTRUE(s$requires_calibration)
    }, logical(1)),
    maps_to = vapply(names(specs), function(nm) {
      if (nm %in% .sg_selection_params) return("<channel selection>")
      m <- mapping[[nm]]
      if (is.null(m)) "<runner>" else m
    }, character(1), USE.NAMES = FALSE),
    description = vapply(specs, function(s) s$description, character(1))
  )
}

#' SHA-256 digest of a protocol definition
#' @noRd
.sg_protocol_digest <- function(protocol) {
  .sg_digest_json(unclass(protocol))
}

#' Coerce user input (id, list, JSON text or file) to an sg_protocol
#' @noRd
.sg_as_protocol <- function(protocol) {
  if (inherits(protocol, "sg_protocol")) return(protocol)
  if (is.character(protocol) && length(protocol) == 1L && !is.na(protocol)) {
    if (grepl("^\\s*\\{", protocol)) {
      def <- tryCatch(jsonlite::parse_json(protocol, simplifyVector = FALSE),
                      error = function(e) {
                        .sg_abort("Protocol JSON text could not be parsed.",
                                  code = "VALIDATION_FAILED")
                      })
      return(.sg_protocol_from_list(def))
    }
    if (grepl("\\.json$", protocol, ignore.case = TRUE) &&
        file.exists(protocol)) {
      return(.sg_protocol_from_list(.sg_read_json(protocol)))
    }
    return(sg_protocol_get(protocol))
  }
  if (is.list(protocol)) return(.sg_protocol_from_list(protocol))
  .sg_abort("{.arg protocol} must be a protocol id, list, JSON text or JSON file.",
            code = "VALIDATION_FAILED")
}

#' Validate a protocol, optionally against an image and parameters
#'
#' Checks the definition against `segmantR-protocol-v1` (schema family and
#' major version, JSON Schema, parameter mapping completeness, defaults),
#' resolves parameters (unknown names and out-of-range values are errors),
#' and, when an image is given, checks the input contract: array order and
#' size, value semantics, channel/band selection and pixel calibration.
#'
#' @param protocol Protocol id, `sg_protocol`, named list, JSON text or path
#'   to a `.json` file.
#' @param image Optional `sg_image` (or `sg_mask` for mask-input protocols).
#' @param ... Parameter overrides and additional inputs (for example
#'   `seeds = mask`).
#' @param error Logical; if `FALSE`, return a report with `ok = FALSE`
#'   instead of signalling the first error.
#'
#' @return An `sg_protocol_validation` list with `ok`, `protocol`,
#'   `parameters`, `checks` (tibble) and `error` (condition or `NULL`).
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' v <- sg_protocol_validate("threshold.otsu.v1", img, min_area = 5L)
#' v$ok
#' bad <- sg_protocol_validate("threshold.otsu.v1", img, min_area = -1L,
#'                             error = FALSE)
#' bad$error$code
sg_protocol_validate <- function(protocol, image = NULL, ..., error = TRUE) {
  checks <- list()
  add <- function(check, status, detail = NA_character_) {
    checks[[length(checks) + 1L]] <<- tibble::tibble(
      check = check, status = status, detail = detail
    )
  }
  result <- tryCatch({
    p <- .sg_as_protocol(protocol)
    add("definition", "ok", paste(p$id, p$version))
    args <- list(...)
    split <- .sg_split_run_args(p, args)
    params <- .sg_resolve_parameters(p, split$parameters)
    add("parameters", "ok", paste(length(params), "parameter(s)"))
    ctx <- NULL
    if (!is.null(image)) {
      inputs <- .sg_bind_inputs(p, image, split$inputs)
      ctx <- .sg_check_inputs(p, inputs, params)
      add("inputs", "ok", paste(names(inputs), collapse = ", "))
      add("calibration", "ok", ctx$calibration$status)
    }
    list(ok = TRUE, protocol = p, parameters = params, context = ctx,
         error = NULL)
  }, sg_error = function(e) {
    if (error) stop(e)
    add("validation", "failed", conditionMessage(e))
    list(ok = FALSE, protocol = NULL, parameters = NULL, context = NULL,
         error = e)
  })
  result$checks <- do.call(rbind, checks)
  structure(result, class = "sg_protocol_validation")
}

#' @export
print.sg_protocol <- function(x, ...) {
  cli::cli_text("{.cls sg_protocol} {.val {x$id}} {x$version} ({x$family}, {x$method$backend})")
  cli::cli_text("{x$title}")
  cli::cli_text("Parameters: {paste(names(x$parameters), collapse = ', ')}")
  invisible(x)
}

#' @export
print.sg_protocol_validation <- function(x, ...) {
  cli::cli_text("{.cls sg_protocol_validation}: {if (x$ok) 'ok' else 'failed'}")
  for (i in seq_len(nrow(x$checks))) {
    cli::cli_text("{x$checks$check[i]}: {x$checks$status[i]} {if (!is.na(x$checks$detail[i])) paste0('(', x$checks$detail[i], ')') else ''}")
  }
  invisible(x)
}
