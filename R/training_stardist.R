# StarDist training and backend-agnostic prediction

#' Train a StarDist 2D model
#'
#' Trains a StarDist model on a prepared instance dataset. All data checks
#' run in R before Python is touched: the dataset must be an instance
#' dataset without split leakage, every training mask must be integer with
#' background 0 and one connected part per positive id, and the training
#' split must not be empty. Only then is the optional Python runtime
#' (`stardist`, `tensorflow`, `csbdeep` through reticulate) checked; when it
#' is missing an `sg_capability_error` with code `CAPABILITY_UNAVAILABLE`
#' and an installation hint is signalled.
#'
#' @param training_data An `sg_training_set` from
#'   [sg_prepare_training_data()] (in memory or on disk), or the path of a
#'   prepared dataset directory.
#' @param base_model Optional pretrained StarDist model name to fine-tune
#'   (e.g. `"2D_versatile_fluo"`); `NULL` trains from a new configuration.
#' @param n_epochs,steps_per_epoch Training length.
#' @param learning_rate Adam learning rate.
#' @param n_rays Number of radial directions.
#' @param grid Subsampling grid (length 2).
#' @param normalize Percentiles (length 2) for per-tile normalisation,
#'   recorded in the model card.
#' @param save_path Directory for the trained model (default: a temporary
#'   directory).
#' @param name Model name (directory name below `save_path`).
#' @param model_card Model card fields (purpose, data_domain, limitations,
#'   license, ...), see [new_sg_trained_model()].
#' @param seed Integer seed passed to the Python random number generators.
#' @param verbose Logical; print progress.
#'
#' @return An `sg_trained_model` with backend `"stardist"`, the dataset
#'   manifest, runtime description and evaluation metrics (validation split
#'   thresholds when available).
#' @export
#' @examples
#' \donttest{
#' img <- sg_example_image("fluorescence_nuclei")
#' msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
#'                          disconnected = "split")
#' ts <- sg_prepare_training_data(
#'   list(list(image = img, mask = msk, subject_id = "A"),
#'        list(image = img, mask = msk, subject_id = "B")),
#'   tile_size = 32L, split = c(train = 0.5, validation = 0.5, test = 0)
#' )
#' # Requires Python stardist; otherwise a classified capability error:
#' try(sg_train_stardist(ts, n_epochs = 1L))
#' }
sg_train_stardist <- function(training_data, base_model = NULL,
                              n_epochs = 100L, steps_per_epoch = 100L,
                              learning_rate = 3e-4, n_rays = 32L,
                              grid = c(2L, 2L), normalize = c(1, 99.8),
                              save_path = NULL, name = "stardist_model",
                              model_card = list(), seed = 1L,
                              verbose = TRUE) {
  ts <- .sg_as_training_set(training_data)
  man <- ts$manifest
  sg_validate_training_manifest(if (is.null(ts$path)) man else ts$path,
                                mask_type = "instance")
  tiles <- .sg_training_tiles(ts)
  train <- Filter(function(t) identical(t$split, "train"), tiles)
  valid <- Filter(function(t) identical(t$split, "validation"), tiles)
  if (length(train) == 0L) {
    .sg_abort("The training split contains no tiles.",
              code = "VALIDATION_FAILED")
  }
  for (t in c(train, valid)) {
    lab <- t$labels
    if (!is.integer(lab) || any(lab < 0L)) {
      .sg_abort("Tile {.val {t$tile_id}} mask is not an integer label matrix.",
                code = "DTYPE_MISMATCH")
    }
    chk <- .sg_check_labels(lab, "instance", 4L)
    if (!chk$ok) {
      .sg_abort(c("Tile {.val {t$tile_id}} is not a valid instance mask.",
                  stats::setNames(.sg_cli_escape(chk$problems),
                                  rep("x", length(chk$problems)))),
                code = "NOT_INSTANCE_MASK")
    }
  }
  stopifnot(length(grid) == 2L, length(normalize) == 2L,
            normalize[1] < normalize[2])
  n_epochs <- as.integer(n_epochs)
  steps_per_epoch <- as.integer(steps_per_epoch)
  n_rays <- as.integer(n_rays)

  status <- .sg_backend_status("python-stardist")
  if (!status$available) {
    .sg_abort_unavailable("StarDist training (Python stardist + tensorflow)",
                          status$install_hint,
                          details = list(reason = status$reason))
  }
  if (is.null(save_path)) save_path <- tempfile("stardist_")
  dir.create(save_path, recursive = TRUE, showWarnings = FALSE)

  np <- reticulate::import("numpy", convert = FALSE)
  models <- reticulate::import("stardist.models")
  csb <- reticulate::import("csbdeep.utils")
  reticulate::py_set_seed(as.integer(seed))
  to_np_image <- function(a) {
    if (length(dim(a)) == 2L) a <- array(a, dim = c(dim(a), 1L))
    x <- np$array(a, dtype = np$float32)
    csb$normalize(x, normalize[1], normalize[2], axis = c(0L, 1L))
  }
  to_np_mask <- function(l) np$array(l, dtype = np$int32)
  x_tr <- lapply(train, function(t) to_np_image(t$image))
  y_tr <- lapply(train, function(t) to_np_mask(t$labels))
  n_ch <- length(man$channels)
  if (verbose) {
    cli::cli_inform(c("i" = "Training StarDist on {length(train)} tile{?s} ({length(valid)} validation)."))
  }
  if (!is.null(base_model)) {
    model <- models$StarDist2D$from_pretrained(base_model)
  } else {
    conf <- models$Config2D(
      n_rays = n_rays, grid = as.integer(grid), n_channel_in = as.integer(n_ch),
      train_epochs = n_epochs, train_steps_per_epoch = steps_per_epoch,
      train_learning_rate = learning_rate,
      train_patch_size = as.integer(c(man$tile_size, man$tile_size))
    )
    model <- models$StarDist2D(conf, name = name, basedir = save_path)
  }
  vdata <- if (length(valid)) {
    reticulate::tuple(lapply(valid, function(t) to_np_image(t$image)),
                      lapply(valid, function(t) to_np_mask(t$labels)))
  } else {
    reticulate::tuple(x_tr, y_tr)
  }
  hist <- model$train(x_tr, y_tr, validation_data = vdata,
                      epochs = n_epochs, steps_per_epoch = steps_per_epoch)
  thresholds <- tryCatch({
    model$optimize_thresholds(vdata[[0]], vdata[[1]])
    reticulate::py_to_r(model$thresholds)
  }, error = function(e) NULL)
  loss <- tryCatch(unlist(reticulate::py_to_r(hist$history$loss)),
                   error = function(e) NULL)
  py_modules <- lapply(c(stardist = "stardist", tensorflow = "tensorflow",
                         csbdeep = "csbdeep", numpy = "numpy"), function(m) {
    tryCatch(as.character(reticulate::import(m)$`__version__`),
             error = function(e) NULL)
  })
  runtime <- .sg_runtime()
  runtime$python <- list(available = TRUE,
                         version = tryCatch(as.character(
                           reticulate::py_config()$version),
                           error = function(e) NULL),
                         modules = py_modules)
  card <- utils::modifyList(list(
    purpose = "Nucleus instance segmentation",
    channels = man$channels,
    target_pixel_size_um = man$pixel_size$x,
    input_value_semantics = man$value_semantics,
    normalization = list(method = "percentile", low = normalize[1],
                         high = normalize[2], scope = "tile"),
    evaluation = if (is.null(thresholds)) list() else thresholds,
    evaluation_split = if (length(valid)) "validation" else "train"
  ), model_card)
  model_dir <- file.path(save_path, name)
  new_sg_trained_model(
    model_path = if (dir.exists(model_dir)) model_dir else save_path,
    backend = "stardist",
    base_model = base_model %||% "none",
    training_metrics = list(n_epochs = n_epochs,
                            steps_per_epoch = steps_per_epoch,
                            learning_rate = learning_rate,
                            n_training_tiles = length(train),
                            n_validation_tiles = length(valid),
                            loss = loss, seed = as.integer(seed),
                            timestamp = Sys.time()),
    model_card = card,
    runtime = runtime,
    dataset_manifest = man,
    representation = "directory"
  )
}

#' Coerce training input to an sg_training_set
#' @noRd
.sg_as_training_set <- function(x) {
  if (inherits(x, "sg_training_set")) return(x)
  if (is.character(x) && length(x) == 1L && dir.exists(x)) {
    man <- .sg_read_json(file.path(x, "dataset_manifest.json"))
    return(structure(list(manifest = man,
                          path = normalizePath(x, winslash = "/"),
                          tiles = NULL), class = "sg_training_set"))
  }
  .sg_abort(
    c("{.arg training_data} must be an sg_training_set or a prepared dataset directory.",
      "i" = "Use {.fn sg_prepare_training_data} first."),
    code = "VALIDATION_FAILED"
  )
}

#' Included tiles with pixels and labels (from memory or disk)
#' @noRd
.sg_training_tiles <- function(ts) {
  man <- ts$manifest
  out <- list()
  for (t in man$tiles) {
    if (isTRUE(t$excluded)) next
    if (!is.null(ts$path)) {
      img <- .sg_read_tiff(.sg_resolve_in_root(ts$path, t$image_path))$data
      lab_t <- .sg_read_tiff(.sg_resolve_in_root(ts$path, t$mask_path))
      lab <- matrix(as.integer(lab_t$data), nrow(lab_t$data),
                    ncol(lab_t$data))
    } else {
      mem <- ts$tiles[[t$tile_id]]
      if (is.null(mem)) next
      img <- mem$image
      lab <- mem$labels
    }
    out[[length(out) + 1L]] <- list(tile_id = t$tile_id, split = t$split,
                                    image = img, labels = lab)
  }
  out
}

#' Predict with a trained model
#'
#' Backend-agnostic prediction facade. The model's backend selects the
#' protocol (`stardist.2d.v1` or `cellpose.2d.v1`); the run goes through
#' [sg_protocol_run()] so parameters are validated and recorded, the
#' backend is checked at the point of use, and the resulting mask is
#' **staged** with the model digest in its provenance. Predictions never
#' overwrite reviewed masks; use [sg_replace_mask()] to adopt a reviewed
#' result explicitly.
#'
#' @param model An `sg_trained_model` or the path of a `.segmantR` archive
#'   (loaded with integrity verification).
#' @param image An `sg_image`.
#' @param ... Protocol parameters (see `sg_protocol_schema(protocol)`).
#' @param protocol Optional protocol id overriding the backend default.
#' @param output `"mask"` or `"run"` (see [sg_protocol_run()]).
#'
#' @return A staged `sg_mask` or an `sg_run`.
#' @export
#' @examples
#' \donttest{
#' mdl <- new_sg_trained_model(tempfile("model"), backend = "stardist",
#'                             base_model = "none", training_metrics = list())
#' img <- sg_example_image("fluorescence_nuclei")
#' run <- sg_predict_model(mdl, img, output = "run")
#' run$record$status
#' }
sg_predict_model <- function(model, image, ..., protocol = NULL,
                             output = c("mask", "run")) {
  output <- match.arg(output)
  if (is.character(model) && length(model) == 1L) {
    model <- sg_load_model(model, allow_legacy = FALSE)
  }
  if (!inherits(model, "sg_trained_model")) {
    .sg_abort("{.arg model} must be an sg_trained_model or a .segmantR path.",
              code = "VALIDATION_FAILED")
  }
  protocol <- protocol %||% switch(model$backend,
                                   stardist = "stardist.2d.v1",
                                   cellpose = "cellpose.2d.v1")
  res <- sg_protocol_run(image, protocol, trained_model = model, ...,
                         output = output)
  add_digest <- function(mask) {
    if (is.null(mask)) return(mask)
    mask$provenance$model_digest <- model$bundle_digest %||%
      model$weights_digest %||% .sg_model_files_digest(model$model_path)
    mask
  }
  if (output == "mask") return(add_digest(res))
  res$mask <- add_digest(res$mask)
  res
}

#' Digest of model weight files (directory or single file)
#' @noRd
.sg_model_files_digest <- function(path) {
  if (is.null(path) || !file.exists(path)) return(NULL)
  if (isTRUE(file.info(path)$isdir)) {
    rel <- .sg_list_rel_files(path)
    if (length(rel) == 0L) return(NULL)
    return(sg_hash_assets(path)$bundle_digest)
  }
  paste0("sha256:", .sg_sha256_file(path))
}
