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
#'   intended use, etc.).
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
                                 model_card = list()) {
  backend <- match.arg(backend)
  stopifnot(is.character(model_path), length(model_path) == 1L)
  stopifnot(is.character(base_model), length(base_model) == 1L)
  stopifnot(is.list(training_metrics))
  stopifnot(is.list(model_card))

  structure(
    list(
      model_path = model_path,
      backend = backend,
      base_model = base_model,
      training_metrics = training_metrics,
      model_card = model_card,
      created = Sys.time()
    ),
    class = "sg_trained_model"
  )
}

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
#' @param trained_model An `sg_trained_model` object.
#' @param output_path Character. Path for the output archive file.
#' @param name Character or `NULL`. Human-readable model name.
#' @param description Character or `NULL`. Short description of the model.
#' @param include_training_data Logical. Include training data in the archive?
#'   Default `FALSE`.
#' @param format Character. Archive format: `"segmantR"` (default),
#'   `"cellpose"`, or `"both"`.
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
                             format = c("segmantR", "cellpose", "both")) {
  if (!inherits(trained_model, "sg_trained_model")) {
    cli::cli_abort("{.arg trained_model} must be an {.cls sg_trained_model} object.")
  }
  format <- match.arg(format)

  staging_dir <- tempfile("segmantR_pkg_")
  dir.create(staging_dir, recursive = TRUE)
  on.exit(unlink(staging_dir, recursive = TRUE), add = TRUE)

  # Copy model weights
  model_src <- trained_model$model_path
  if (file.exists(model_src)) {
    if (file.info(model_src)$isdir) {
      model_files <- list.files(model_src, full.names = TRUE, recursive = TRUE)
      model_dest <- file.path(staging_dir, "weights")
      dir.create(model_dest, recursive = TRUE)
      file.copy(model_files, model_dest, overwrite = TRUE)
    } else {
      file.copy(model_src, file.path(staging_dir, basename(model_src)),
                overwrite = TRUE)
    }
  }

  # Build model card
  card <- list(
    name = name %||% paste0(trained_model$backend, "_", trained_model$base_model),
    description = description %||% "Trained segmentation model",
    backend = trained_model$backend,
    base_model = trained_model$base_model,
    training_metrics = trained_model$training_metrics,
    model_card = trained_model$model_card,
    created = format(trained_model$created, "%Y-%m-%dT%H:%M:%S"),
    packaged = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    segmantR_version = as.character(utils::packageVersion("segmantR")),
    format = format
  )
  jsonlite::write_json(card, file.path(staging_dir, "model_card.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  # Create ZIP
  files_to_zip <- list.files(staging_dir, full.names = TRUE, recursive = TRUE)
  utils::zip(output_path, files = files_to_zip,
             extras = "-j", flags = "-r9Xq")

  cli::cli_inform(c("v" = "Model packaged to {.path {output_path}}."))
  invisible(output_path)
}

#' Load a packaged segmantR model
#'
#' Reads a `.segmantR` archive created by [sg_package_model()] and
#' returns an `sg_trained_model` object.
#'
#' @param path Character. Path to the `.segmantR` archive file.
#'
#' @return An `sg_trained_model` object.
#' @export
#' @examples
#' \donttest{
#' # model <- sg_load_model("my_model.segmantR")
#' }
sg_load_model <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("Model file not found: {.path {path}}")
  }

  extract_dir <- tempfile("segmantR_load_")
  dir.create(extract_dir, recursive = TRUE)
  utils::unzip(path, exdir = extract_dir)

  # Find model_card.json
  card_path <- list.files(extract_dir, pattern = "model_card\\.json$",
                          recursive = TRUE, full.names = TRUE)
  if (length(card_path) == 0L) {
    cli::cli_abort("No {.file model_card.json} found in archive {.path {path}}.")
  }
  card <- jsonlite::read_json(card_path[1])

  # Find weights
  weights_dir <- list.dirs(extract_dir, recursive = TRUE, full.names = TRUE)
  weights_match <- weights_dir[grepl("weights", weights_dir)]
  model_path <- if (length(weights_match) > 0L) weights_match[1] else extract_dir

  result <- new_sg_trained_model(
    model_path = model_path,
    backend = card$backend %||% "cellpose",
    base_model = card$base_model %||% "unknown",
    training_metrics = card$training_metrics %||% list(),
    model_card = card$model_card %||% list()
  )

  cli::cli_inform(c(
    "v" = "Loaded model from {.path {path}}.",
    "i" = "Backend: {result$backend}, base: {result$base_model}."
  ))
  result
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
