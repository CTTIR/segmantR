# Declarative protocol runner and segmentation run envelope

#' Run a declarative segmentation protocol
#'
#' Validates the protocol, the parameters and the inputs, delegates to the
#' corresponding direct function (`sg_segment_threshold()`,
#' `sg_segment_watershed()`, `sg_segment_propagate()`, `sg_cleanup_labels()`,
#' `sg_segment_stardist()`, `sg_segment_cellpose()`, `sg_segment_mesmer()`)
#' with an explicit, recorded argument mapping, and returns the mask or a
#' run envelope.
#'
#' Core protocols run without Python. Optional DNN protocols check their
#' backend first; when it is missing, `output = "mask"` signals an
#' `sg_capability_error` and `output = "run"` returns a run with
#' `status = "unavailable"`. There is never a silent fallback to another
#' method. DNN predictions are returned as staged masks.
#'
#' @param image The primary input: an `sg_image`, or an `sg_mask` for
#'   mask-input protocols such as `postprocess.label-cleanup.v1`.
#' @param protocol Protocol id, `sg_protocol`, named list, JSON text or
#'   `.json` file path.
#' @param ... Parameter overrides (for example `min_area = 20L`) and
#'   additional declared inputs (for example `seeds = nuclei_mask` for
#'   `propagate.voronoi.v1`, `model = trained_model`). Unknown names are
#'   errors.
#' @param output `"mask"` (default) returns the `sg_mask`; `"run"` returns an
#'   `sg_run` with `mask`, `measurements` and a schema-valid `record`.
#'
#' @return An `sg_mask` or an `sg_run`.
#' @seealso [sg_protocol_list()], [sg_protocol_schema()],
#'   [sg_protocol_validate()], [sg_export_interchange()]
#' @export
#' @examples
#' img <- sg_example_image("fluorescence_nuclei")
#' mask <- sg_protocol_run(img, "threshold.otsu.v1", min_area = 5L)
#' run <- sg_protocol_run(img, "threshold.otsu.v1", min_area = 5L,
#'                        output = "run")
#' run$record$delegate$arguments
#' identical(mask$labels, run$mask$labels)
sg_protocol_run <- function(image, protocol, ..., output = c("mask", "run")) {
  output <- match.arg(output)
  started <- Sys.time()
  p <- .sg_as_protocol(protocol)
  args <- list(...)
  split <- .sg_split_run_args(p, args)
  params <- .sg_resolve_parameters(p, split$parameters)
  inputs <- .sg_bind_inputs(p, image, split$inputs)
  ctx <- .sg_check_inputs(p, inputs, params)
  run_id <- .sg_new_run_id("run")

  backend <- .sg_backend_status(p$method$backend)
  if (!backend$available) {
    cond <- tryCatch(
      .sg_abort_unavailable(
        paste0("Backend '", p$method$backend, "' for ", p$id),
        backend$install_hint %||% "See the protocol runtime_profile.",
        details = list(reason = backend$reason)
      ),
      sg_error = function(e) e
    )
    if (output == "mask") stop(cond)
    record <- .sg_run_record(p, params, inputs, ctx, NULL, NULL, run_id,
                             started, status = "unavailable", error = cond,
                             delegate = list(function_name = p$method$delegate,
                                             arguments = list(),
                                             postprocess = list()))
    return(structure(list(record = record, mask = NULL,
                          measurements = NULL), class = "sg_run"))
  }

  seed <- p$seed_policy
  exec <- function() .sg_delegate(p, params, inputs, ctx)
  result <- if (identical(seed$policy, "fixed") && !is.null(seed$seed)) {
    .sg_with_seed(seed$seed, exec())
  } else {
    exec()
  }
  mask <- result$mask
  for (step in p$postprocess$steps) {
    cleanup <- sg_protocol_get("postprocess.label-cleanup.v1")
    sp <- .sg_resolve_parameters(cleanup, step$parameters)
    mask <- do.call(sg_cleanup_labels, c(
      list(mask = mask),
      .sg_cleanup_args(sp, ctx$calibration$pixel_size)
    ))
    result$postprocess <- c(result$postprocess, list(list(
      protocol = "postprocess.label-cleanup.v1", parameters = sp
    )))
  }
  mask <- .sg_finalise_mask(mask, p, inputs, ctx, run_id, params)
  wide <- .sg_measure_labels(
    mask$labels, pixels = result$measure_pixels,
    channels = result$measure_channels,
    origin = .sg_check_origin(mask$origin),
    pixel_size = ctx$calibration$pixel_size,
    which = unlist(p$output_contract$measurements)
  )
  if (output == "mask") return(mask)
  record <- .sg_run_record(p, params, inputs, ctx, mask, wide, run_id,
                           started, status = "succeeded",
                           delegate = list(function_name = p$method$delegate,
                                           arguments = result$record_args,
                                           postprocess = result$postprocess %||%
                                             list()))
  structure(list(record = record, mask = mask, measurements = wide),
            class = "sg_run")
}

#' Split runner arguments into declared inputs and parameter overrides
#' @noRd
.sg_split_run_args <- function(p, args) {
  if (length(args) && (is.null(names(args)) || any(!nzchar(names(args))))) {
    .sg_abort("All additional arguments must be named.",
              code = "UNKNOWN_PARAMETER")
  }
  roles <- vapply(p$input_contract$inputs, function(i) i$role, character(1))
  is_input <- names(args) %in% roles
  list(inputs = args[is_input], parameters = args[!is_input])
}

#' Bind the primary argument and extra inputs to declared roles
#' @noRd
.sg_bind_inputs <- function(p, primary, extra) {
  decl <- p$input_contract$inputs
  roles <- vapply(decl, function(i) i$role, character(1))
  types <- vapply(decl, function(i) i$type, character(1))
  bound <- list()
  if (!is.null(primary)) {
    cls <- if (inherits(primary, "sg_image")) "sg_image" else
      if (inherits(primary, "sg_mask")) "sg_mask" else NA_character_
    hit <- which(types == cls & !roles %in% names(extra))[1]
    if (is.na(cls) || is.na(hit)) {
      .sg_abort(
        "The first argument must be an {.cls {types[1]}} for protocol {.val {p$id}}.",
        code = "VALIDATION_FAILED"
      )
    }
    bound[[roles[hit]]] <- primary
  }
  for (nm in names(extra)) bound[[nm]] <- extra[[nm]]
  for (i in seq_along(decl)) {
    role <- roles[i]
    val <- bound[[role]]
    if (is.null(val)) {
      if (isTRUE(decl[[i]]$required)) {
        .sg_abort("Protocol {.val {p$id}} requires input {.field {role}} ({.cls {types[i]}}).",
                  code = "VALIDATION_FAILED", details = list(input = role))
      }
      next
    }
    if (!inherits(val, types[i])) {
      .sg_abort("Input {.field {role}} must be an {.cls {types[i]}}.",
                code = "VALIDATION_FAILED", details = list(input = role))
    }
  }
  bound
}

#' Check inputs against the input contract; returns run context
#' @noRd
.sg_check_inputs <- function(p, inputs, params) {
  ic <- p$input_contract
  decl <- ic$inputs
  primary_role <- decl[[1]]$role
  primary <- inputs[[primary_role]]
  grid <- if (inherits(primary, "sg_image")) dim(primary$pixels) else
    dim(primary$labels)
  min_shape <- unlist(ic$min_shape_yx)
  if (grid[1] < min_shape[1] || grid[2] < min_shape[2]) {
    .sg_abort("Input is {grid[1]} x {grid[2]} px; {.val {p$id}} needs at least {min_shape[1]} x {min_shape[2]}.",
              code = "DIMENSION_MISMATCH")
  }
  max_px <- p$tiling$max_pixels
  if (!is.null(max_px) && prod(grid[1:2]) > max_px) {
    .sg_abort(
      c("Input has {prod(grid[1:2])} pixels; {.val {p$id}} processes at most {max_px} in memory.",
        "i" = "Split the image into tiles before running the protocol."),
      code = "PAYLOAD_TOO_LARGE"
    )
  }
  for (i in seq_along(decl)) {
    val <- inputs[[decl[[i]]$role]]
    if (is.null(val)) next
    d <- if (inherits(val, "sg_image")) dim(val$pixels) else
      if (inherits(val, "sg_mask")) dim(val$labels) else NULL
    if (!is.null(d) && !identical(as.integer(d[1:2]), as.integer(grid[1:2]))) {
      .sg_abort("Input {.field {decl[[i]]$role}} is {d[1]} x {d[2]} px but the primary input is {grid[1]} x {grid[2]} px.",
                code = "DIMENSION_MISMATCH",
                details = list(input = decl[[i]]$role))
    }
    if (inherits(val, "sg_mask")) {
      want <- decl[[i]]$mask_type
      chk <- .sg_check_labels(val$labels, want %||% "labelled")
      if (!chk$ok) {
        .sg_abort(c("Input {.field {decl[[i]]$role}} is not a valid mask.",
                    stats::setNames(.sg_cli_escape(chk$problems),
                                    rep("x", length(chk$problems)))),
                  code = if (identical(want, "instance")) "NOT_INSTANCE_MASK"
                  else "VALIDATION_FAILED")
      }
    }
  }
  images <- Filter(function(v) inherits(v, "sg_image"), inputs)
  for (nm in names(images)) {
    sem <- images[[nm]]$value_semantics %||% "unknown"
    allowed <- unlist(ic$value_semantics)
    if (!sem %in% allowed) {
      .sg_abort(
        "Input {.field {nm}} has value semantics {.val {sem}}; {.val {p$id}} accepts {.val {allowed}}.",
        code = "VALIDATION_FAILED", details = list(input = nm)
      )
    }
  }
  if (!is.null(ic$channel) && inherits(primary, "sg_image")) {
    n_ch <- if (length(grid) == 3L) grid[3] else 1L
    if (n_ch < ic$channel$min_channels) {
      .sg_abort("{.val {p$id}} needs at least {ic$channel$min_channels} channel{?s}; the image has {n_ch}.",
                code = "DIMENSION_MISMATCH")
    }
    for (nm in intersect(c("membrane_channel", "nuclear_channel"),
                         names(params))) {
      v <- params[[nm]]
      if (!is.null(v) && v > n_ch) {
        .sg_abort("{.field {nm}} = {v} exceeds the {n_ch} image channel{?s}.",
                  code = "PARAMETER_OUT_OF_RANGE")
      }
    }
  }
  calib_image <- if (inherits(primary, "sg_image")) primary else
    inputs$reference
  px <- calib_image$resolution$x_um %||% NA_real_
  py <- calib_image$resolution$y_um %||% NA_real_
  calibrated <- is.numeric(px) && is.numeric(py) && isTRUE(is.finite(px)) &&
    isTRUE(is.finite(py)) && px > 0 && py > 0
  cal <- ic$calibration
  needs <- switch(
    cal$required,
    never = FALSE,
    always = TRUE,
    when_parameters_set = any(vapply(unlist(cal$parameters), function(nm) {
      !is.null(params[[nm]])
    }, logical(1)))
  )
  if (identical(cal$required, "always") && !calibrated &&
      any(vapply(unlist(cal$parameters), function(nm) {
        !is.null(params[[nm]])
      }, logical(1)))) {
    given <- Filter(Negate(is.null), params[unlist(cal$parameters)])
    px <- py <- given[[1]]
    calibrated <- TRUE
  }
  if (needs && !calibrated) {
    needing <- unlist(cal$parameters)
    .sg_abort(
      c("Protocol {.val {p$id}} needs a pixel calibration for this run.",
        "i" = "Set the image {.field resolution} (x_um, y_um){if (length(needing)) paste0(' or adjust ', paste(needing, collapse = ', ')) else ''}."),
      class = "sg_calibration_error", code = "CALIBRATION_MISSING",
      details = list(protocol = p$id)
    )
  }
  list(
    grid = grid,
    calibration = list(
      status = if (calibrated) "calibrated" else "uncalibrated",
      required = needs,
      pixel_size = list(x = if (calibrated) px else NA_real_,
                        y = if (calibrated) py else NA_real_)
    )
  )
}

#' Availability of a protocol backend (checked at the point of use)
#' @noRd
.sg_backend_status <- function(backend) {
  probe <- function(check, hint) {
    tryCatch({
      check()
      list(available = TRUE, reason = NULL, install_hint = hint,
           checked = TRUE)
    }, error = function(e) {
      list(available = FALSE, reason = conditionMessage(e),
           install_hint = hint, checked = TRUE)
    })
  }
  switch(
    backend,
    "segmantR-core" = list(available = TRUE, reason = NULL,
                           install_hint = NULL, checked = TRUE),
    "python-stardist" = probe(.check_stardist, paste(
      "Install the Python packages 'stardist' and 'tensorflow'",
      "(sg_setup_python(backends = 'stardist'))."
    )),
    "python-cellpose" = probe(.check_cellpose, paste(
      "Install the Python package 'cellpose'",
      "(sg_setup_python(backends = 'cellpose'))."
    )),
    "python-deepcell" = probe(.check_mesmer,
                              "Install the Python package 'deepcell'."),
    list(available = FALSE, reason = "Backend is not runnable from R.",
         install_hint = "Use sg_export_qupath() to run it in QuPath.",
         checked = TRUE)
  )
}

#' Evaluate code with a fixed seed and restore the previous RNG state
#' @noRd
.sg_with_seed <- function(seed, code) {
  genv <- globalenv()
  had <- exists(".Random.seed", envir = genv, inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = genv) else NULL
  on.exit({
    if (had) {
      assign(".Random.seed", old, envir = genv)
    } else if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
      rm(".Random.seed", envir = genv)
    }
  })
  set.seed(seed)
  force(code)
}

#' Convert cleanup protocol parameters to sg_cleanup_labels arguments
#' @noRd
.sg_cleanup_args <- function(params, pixel_size = NULL) {
  list(min_area = params$min_area, max_area = params$max_area,
       min_area_um2 = params$min_area_um2,
       max_area_um2 = params$max_area_um2,
       fill_holes = params$fill_holes, connectivity = params$connectivity,
       border = params$border, touching = params$touching,
       disconnected = params$disconnected, relabel = params$relabel,
       pixel_size = if (!is.null(pixel_size) && is.finite(pixel_size$x))
         pixel_size else NULL)
}

#' Selection arguments for sg_select_channel()
#' @noRd
.sg_selection_args <- function(params) {
  keep <- intersect(names(params), .sg_selection_params)
  out <- params[keep]
  out[!vapply(out, is.null, logical(1))]
}

#' Build nested delegate arguments from the protocol mapping
#' @noRd
.sg_mapped_args <- function(p, params, skip = character(0)) {
  out <- list()
  mapping <- p$method$mapping
  for (nm in names(mapping)) {
    target <- mapping[[nm]]
    if (is.null(target) || nm %in% skip) next
    val <- params[[nm]]
    if (grepl(".", target, fixed = TRUE)) {
      parts <- strsplit(target, ".", fixed = TRUE)[[1]]
      sub <- out[[parts[1]]] %||% list()
      sub[parts[2]] <- list(val)
      out[[parts[1]]] <- sub
    } else {
      out[target] <- list(val)
    }
  }
  fixed <- p$method$fixed_arguments %||% list()
  for (nm in names(fixed)) out[nm] <- list(fixed[[nm]])
  out
}

#' Dispatch to the whitelisted delegate
#' @return List with `mask`, `record_args`, `measure_pixels`,
#'   `measure_channels`.
#' @noRd
.sg_delegate <- function(p, params, inputs, ctx) {
  switch(
    p$method$delegate,
    sg_segment_threshold = .sg_delegate_single(p, params, inputs,
                                               sg_segment_threshold),
    sg_segment_watershed = .sg_delegate_watershed(p, params, inputs),
    sg_segment_propagate = .sg_delegate_propagate(p, params, inputs),
    sg_cleanup_labels = .sg_delegate_cleanup(p, params, inputs, ctx),
    sg_segment_stardist = .sg_delegate_stardist(p, params, inputs, ctx),
    sg_segment_cellpose = .sg_delegate_cellpose(p, params, inputs, ctx),
    sg_segment_mesmer = .sg_delegate_mesmer(p, params, inputs, ctx),
    .sg_abort("Delegate {.val {p$method$delegate}} is not whitelisted.",
              class = "sg_security_error", code = "VALIDATION_FAILED")
  )
}

#' @noRd
.sg_delegate_single <- function(p, params, inputs, fn) {
  image <- inputs$image
  sel <- do.call(sg_select_channel, c(list(image = image),
                                      .sg_selection_args(params)))
  args <- .sg_mapped_args(p, params)
  args$channel <- 1L
  mask <- do.call(fn, c(list(image = sel), args))
  rec <- args
  rec$channel <- sel$provenance$band_selection$channels[1]
  list(mask = mask, record_args = .sg_record_args(rec, sel),
       measure_pixels = sel$pixels, measure_channels = sel$channels)
}

#' @noRd
.sg_delegate_watershed <- function(p, params, inputs) {
  image <- inputs$image
  sel <- do.call(sg_select_channel, c(list(image = image),
                                      .sg_selection_args(params)))
  args <- .sg_mapped_args(p, params)
  work <- sel
  if (!is.null(params$membrane_channel)) {
    mem <- sg_select_channel(image, channel = params$membrane_channel)
    work <- new_sg_image(array(c(sel$pixels, mem$pixels),
                               dim = c(dim(sel$pixels), 2L)),
                         channels = c(sel$channels, mem$channels))
    args$membrane_channel <- 2L
  }
  args$channel <- 1L
  mask <- do.call(sg_segment_watershed, c(list(image = work), args))
  rec <- args
  rec$channel <- sel$provenance$band_selection$channels[1]
  if (!is.null(params$membrane_channel)) {
    rec$membrane_channel <- params$membrane_channel
  }
  list(mask = mask, record_args = .sg_record_args(rec, sel),
       measure_pixels = sel$pixels, measure_channels = sel$channels)
}

#' @noRd
.sg_delegate_propagate <- function(p, params, inputs) {
  args <- .sg_mapped_args(p, params)
  mask <- do.call(sg_segment_propagate, c(
    list(image = inputs$image, nuclear_mask = inputs$seeds,
         membrane_image = inputs$membrane),
    args
  ))
  rec <- c(list(nuclear_mask = "<input:seeds>",
                membrane_image = if (is.null(inputs$membrane)) NULL else
                  "<input:membrane>"), args)
  list(mask = mask, record_args = .sg_record_args(rec, NULL),
       measure_pixels = NULL, measure_channels = NULL)
}

#' @noRd
.sg_delegate_cleanup <- function(p, params, inputs, ctx) {
  args <- .sg_cleanup_args(params, ctx$calibration$pixel_size)
  mask <- do.call(sg_cleanup_labels, c(list(mask = inputs$mask), args))
  ref <- inputs$reference
  list(mask = mask, record_args = .sg_record_args(args, NULL),
       measure_pixels = if (is.null(ref)) NULL else ref$pixels,
       measure_channels = if (is.null(ref)) NULL else ref$channels)
}

#' @noRd
.sg_delegate_stardist <- function(p, params, inputs, ctx) {
  for (nm in c("cell_expansion_um")) {
    if (!is.null(params[[nm]])) {
      .sg_abort(
        c("{.field {nm}} is only supported by the QuPath StarDist extension.",
          "i" = "Use {.fn sg_export_qupath} or leave it null for the Python backend."),
        class = "sg_capability_error", code = "UNSUPPORTED_PARAMETER"
      )
    }
  }
  if (isTRUE(params$create_annotations)) {
    .sg_abort("{.field create_annotations} is only supported in QuPath.",
              class = "sg_capability_error", code = "UNSUPPORTED_PARAMETER")
  }
  if (!identical(params$normalize_scope, "global")) {
    .sg_abort("Tile-wise normalisation is only supported in QuPath.",
              class = "sg_capability_error", code = "UNSUPPORTED_PARAMETER")
  }
  image <- inputs$image
  sel <- do.call(sg_select_channel, c(list(image = image),
                                      .sg_selection_args(params)))
  model_name <- params$model
  custom <- NULL
  if (!is.null(inputs$trained_model)) {
    if (!identical(inputs$trained_model$backend, "stardist")) {
      .sg_abort("The model input must be a StarDist model.",
                code = "VALIDATION_FAILED")
    }
    model_name <- "custom"
    custom <- inputs$trained_model$model_path
  }
  ch <- sel$pixels
  q <- stats::quantile(ch, c(params$normalize_low, params$normalize_high) /
                         100, names = FALSE, na.rm = TRUE, type = 7)
  if (q[2] > q[1]) ch <- (ch - q[1]) / (q[2] - q[1])
  scale <- if (!is.null(params$pixel_size_um)) {
    ctx$calibration$pixel_size$x / params$pixel_size_um
  } else {
    NULL
  }
  n_tiles <- if (!is.null(params$tile_size)) {
    as.integer(ceiling(dim(ch)[1:2] / params$tile_size))
  } else {
    NULL
  }
  mask <- .sg_stardist_predict(ch, model = model_name,
                               custom_model_path = custom,
                               prob_thresh = params$prob_thresh,
                               nms_thresh = params$nms_thresh, scale = scale,
                               n_tiles = n_tiles)
  rec <- list(model = model_name, channel = sel$provenance$band_selection$
                channels[1], prob_thresh = params$prob_thresh,
              nms_thresh = params$nms_thresh, scale = scale,
              n_tiles = if (is.null(n_tiles)) NULL else I(n_tiles),
              custom_model_path = if (is.null(custom)) NULL else
                "<input:trained_model>",
              normalization = list(method = "percentile",
                                   low = params$normalize_low,
                                   high = params$normalize_high,
                                   applied_by = "runner"))
  list(mask = mask, record_args = .sg_record_args(rec, sel),
       measure_pixels = sel$pixels, measure_channels = sel$channels)
}

#' @noRd
.sg_delegate_cellpose <- function(p, params, inputs, ctx) {
  args <- .sg_mapped_args(p, params, skip = "diameter_um")
  if (!is.null(params$diameter_um)) {
    args$diameter <- params$diameter_um / ctx$calibration$pixel_size$x
  }
  rec <- args
  if (!is.null(inputs$trained_model)) {
    if (!identical(inputs$trained_model$backend, "cellpose")) {
      .sg_abort("The model input must be a Cellpose model.",
                code = "VALIDATION_FAILED")
    }
    args$model <- "custom"
    args$custom_model_path <- inputs$trained_model$model_path
    rec$model <- "custom"
    rec$custom_model_path <- "<input:trained_model>"
  }
  mask <- do.call(sg_segment_cellpose, c(list(image = inputs$image), args))
  list(mask = mask, record_args = .sg_record_args(rec, NULL),
       measure_pixels = inputs$image$pixels,
       measure_channels = inputs$image$channels)
}

#' @noRd
.sg_delegate_mesmer <- function(p, params, inputs, ctx) {
  image <- inputs$image
  nuc <- sg_select_channel(image, channel = params$nuclear_channel)
  mem <- sg_select_channel(image, channel = params$membrane_channel)
  pair <- new_sg_image(array(c(nuc$pixels, mem$pixels),
                             dim = c(dim(nuc$pixels), 2L)),
                       channels = c(nuc$channels, mem$channels),
                       resolution = image$resolution)
  mpp <- params$image_mpp %||% ctx$calibration$pixel_size$x
  mask <- sg_segment_mesmer(pair, compartment = params$compartment,
                            image_mpp = mpp)
  rec <- list(compartment = params$compartment, image_mpp = mpp,
              channels = I(c(params$nuclear_channel,
                             params$membrane_channel)))
  list(mask = mask, record_args = .sg_record_args(rec, NULL),
       measure_pixels = pair$pixels, measure_channels = pair$channels)
}

#' JSON-able delegate arguments (objects replaced by references)
#' @noRd
.sg_record_args <- function(args, selection_image) {
  out <- lapply(args, function(v) {
    if (inherits(v, c("sg_image", "sg_mask", "sg_trained_model"))) {
      paste0("<", class(v)[1], ">")
    } else {
      v
    }
  })
  out$image <- "<input:image>"
  if (!is.null(selection_image)) {
    sel <- selection_image$provenance$band_selection
    if (!identical(sel$method, "index")) {
      out$image <- "<derived:sg_select_channel>"
    }
  }
  out[!vapply(out, is.null, logical(1))]
}

#' Attach image binding, contract fields and provenance to a result mask
#' @noRd
.sg_finalise_mask <- function(mask, p, inputs, ctx, run_id, params) {
  primary <- inputs[[p$input_contract$inputs[[1]]$role]]
  ref_image <- if (inherits(primary, "sg_image")) primary else inputs$reference
  if (!is.null(ref_image)) {
    mask$image_id <- mask$image_id %||% .sg_image_id(ref_image)
    mask$plane <- .sg_image_plane(ref_image)
    mask$plane$c <- NA_integer_
    mask$origin <- .sg_image_origin(ref_image)
  } else if (inherits(primary, "sg_mask")) {
    mask$image_id <- mask$image_id %||% primary$image_id
  }
  mask$mask_type <- p$output_contract$mask_type
  mask$provenance <- c(mask$provenance %||% list(), list(protocol_run = list(
    run_id = run_id,
    protocol = list(id = p$id, version = p$version,
                    digest = .sg_protocol_digest(p)),
    parameters_digest = .sg_digest_json(.sg_params_json(params))
  )))
  if (identical(p$output_contract$status, "staged")) {
    mask <- sg_stage_mask(mask, source = paste(p$id, "prediction"))
  }
  mask
}

#' Parameters as a JSON-safe named object
#' @noRd
.sg_params_json <- function(params) {
  .sg_json_object(params)
}

#' Stable image identifier: declared id or short content hash
#' @noRd
.sg_image_id <- function(image) {
  if (!is.null(image$id)) return(image$id)
  d <- .sg_array_digest(image$pixels)
  paste0("sha256:", substr(sub("^sha256:", "", d), 1L, 16L))
}

#' Build the schema-conformant run record
#' @noRd
.sg_run_record <- function(p, params, inputs, ctx, mask, wide, run_id,
                           started, status, delegate, error = NULL) {
  finished <- Sys.time()
  decl <- p$input_contract$inputs
  input_rows <- list()
  for (d in decl) {
    v <- inputs[[d$role]]
    if (is.null(v)) next
    digest <- if (inherits(v, "sg_image")) {
      .sg_array_digest(v$pixels)
    } else if (inherits(v, "sg_mask")) {
      sg_mask_revision(v)
    } else if (inherits(v, "sg_trained_model")) {
      v$weights_digest %||% NULL
    } else {
      NULL
    }
    id <- if (inherits(v, "sg_image")) .sg_image_id(v) else
      if (inherits(v, "sg_mask")) (v$id %||% v$image_id) else
        (v$model_card$name %||% NULL)
    input_rows[[length(input_rows) + 1L]] <- list(
      role = d$role, type = d$type, id = id, digest = digest
    )
  }
  mask_out <- NULL
  meas_out <- NULL
  if (!is.null(mask)) {
    mask_out <- list(
      content_digest = .sg_array_digest(mask$labels),
      revision = sg_mask_revision(mask),
      label_count = as.integer(length(unique(mask$labels[mask$labels > 0L]))),
      mask_type = mask$mask_type,
      dtype = "int32",
      status = .sg_review(mask)$status,
      shape_yx = I(as.integer(dim(mask$labels)))
    )
    meas_out <- list(
      n_objects = nrow(wide),
      names = I(setdiff(names(wide), "label")),
      digest = .sg_digest_json(wide)
    )
  }
  seed_val <- p$seed_policy$seed
  record <- list(
    schema = .sg_interchange_schema,
    schema_version = .sg_interchange_version,
    kind = "segmentation-run",
    run_id = run_id,
    status = status,
    protocol = list(id = p$id, version = p$version,
                    digest = .sg_protocol_digest(p)),
    parameters = .sg_params_json(params),
    parameters_digest = .sg_digest_json(.sg_params_json(params)),
    delegate = list(
      "function" = delegate$function_name,
      arguments = .sg_json_object(delegate$arguments),
      backend = p$method$backend,
      postprocess = delegate$postprocess
    ),
    inputs = input_rows,
    outputs = list(mask = mask_out, measurements = meas_out),
    seed = list(policy = p$seed_policy$policy,
                value = if (is.null(seed_val)) NULL else as.integer(seed_val),
                rng_kind = if (identical(p$seed_policy$policy, "fixed"))
                  paste(RNGkind(), collapse = "/") else NULL),
    runtime = .sg_runtime(),
    started = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    finished = format(finished, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    duration_s = as.numeric(difftime(finished, started, units = "secs")),
    error = if (is.null(error)) NULL else list(
      class = class(error)[1], code = error$code %||% "UNKNOWN",
      message = conditionMessage(error)
    ),
    warnings = I(character(0)),
    extensions = .sg_json_object(list(calibration = ctx$calibration$status))
  )
  record <- .sg_as_json_value(record)
  .sg_schema_assert(record, "run.schema.json", what = "run record")
  record
}

#' @export
print.sg_run <- function(x, ...) {
  r <- x$record
  cli::cli_text("{.cls sg_run} {.val {r$protocol$id}} {r$protocol$version}: {r$status}")
  if (!is.null(x$mask)) {
    cli::cli_text("Objects: {r$outputs$mask$label_count} ({r$outputs$mask$mask_type}, {r$outputs$mask$status})")
    cli::cli_text("Revision: {r$outputs$mask$revision}")
  }
  if (!is.null(r$error)) {
    cli::cli_text("Error: {r$error$code} - {r$error$message}")
  }
  invisible(x)
}
