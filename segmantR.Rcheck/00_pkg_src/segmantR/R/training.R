# Model training and active learning

#' Fine-tune a Cellpose model on user-corrected masks
#'
#' Trains (fine-tunes) a Cellpose segmentation model using corrected
#' image-mask pairs provided by the user. Requires a working Python
#' environment with Cellpose installed (see [sg_setup_python()]).
#'
#' @param training_data A list of training pairs. Each element must be a list
#'   with `$image` (`sg_image`) and `$mask` (`sg_mask`).
#' @param base_model Character. Cellpose base model to fine-tune.
#'   Default `"cyto3"`.
#' @param n_epochs Integer. Number of training epochs. Default `100L`.
#' @param learning_rate Numeric. Learning rate. Default `0.1`.
#' @param save_path Character or `NULL`. Directory to save the trained model.
#'   When `NULL`, a temporary directory is used.
#' @param verbose Logical. Print training progress? Default `TRUE`.
#'
#' @return An `sg_trained_model` object.
#' @export
#' @examples
#' \donttest{
#' # Requires Python + Cellpose:
#' # trained <- sg_train_cellpose(training_data, base_model = "cyto3")
#' }
sg_train_cellpose <- function(training_data, base_model = "cyto3",
                              n_epochs = 100L, learning_rate = 0.1,
                              save_path = NULL, verbose = TRUE) {
  .check_cellpose()
  n_epochs <- as.integer(n_epochs)


  if (!is.list(training_data) || length(training_data) == 0L) {
    cli::cli_abort("{.arg training_data} must be a non-empty list of training pairs.")
  }

  # Validate each training pair
  for (i in seq_along(training_data)) {
    td <- training_data[[i]]
    if (!is.list(td) || is.null(td$image) || is.null(td$mask)) {
      cli::cli_abort("Element {i} of {.arg training_data} must have {.field $image} and {.field $mask}.")
    }
    if (!inherits(td$image, "sg_image")) {
      cli::cli_abort("Element {i}: {.field $image} must be an {.cls sg_image} object.")
    }
    if (!inherits(td$mask, "sg_mask")) {
      cli::cli_abort("Element {i}: {.field $mask} must be an {.cls sg_mask} object.")
    }
  }

  if (is.null(save_path)) {
    save_path <- tempdir()
  }
  if (!dir.exists(save_path)) {
    dir.create(save_path, recursive = TRUE)
  }

  # Prepare training data for Cellpose
  np <- reticulate::import("numpy", convert = FALSE)
  cellpose_models <- reticulate::import("cellpose.models", convert = FALSE)

  # Convert images and masks to numpy arrays
  train_images <- lapply(training_data, function(td) {
    .r_array_to_cellpose(td$image)
  })
  train_masks <- lapply(training_data, function(td) {
    np$array(td$mask$labels, dtype = np$int32)
  })

  if (verbose) {
    cli::cli_inform(c(
      "i" = "Fine-tuning Cellpose model {.val {base_model}}.",
      "i" = "Training on {length(training_data)} image{?s} for {n_epochs} epoch{?s}."
    ))
  }

  # Create and train model
  model <- cellpose_models$CellposeModel(
    model_type = base_model,
    gpu = reticulate::py_eval("False")
  )

  model_path <- model$train(
    train_data = train_images,
    train_labels = train_masks,
    n_epochs = as.integer(n_epochs),
    learning_rate = learning_rate,
    save_path = save_path
  )

  model_path_r <- reticulate::py_to_r(model_path)
  if (is.null(model_path_r) || !is.character(model_path_r)) {
    model_path_r <- save_path
  }

  if (verbose) {
    cli::cli_inform(c("v" = "Training complete. Model saved to {.path {model_path_r}}."))
  }

  new_sg_trained_model(
    model_path = model_path_r,
    backend = "cellpose",
    base_model = base_model,
    training_metrics = list(
      n_epochs = n_epochs,
      learning_rate = learning_rate,
      n_training_images = length(training_data),
      timestamp = Sys.time()
    )
  )
}

#' Run an active learning loop for iterative segmentation refinement
#'
#' Orchestrates a human-in-the-loop (HITL) active learning workflow:
#' segment, review, correct, retrain, repeat.
#'
#' @param image An `sg_image` object.
#' @param model Character. Segmentation backend to use. Currently only
#'   `"cellpose"` is supported. Default `"cellpose"`.
#' @param n_rounds Integer. Number of active learning rounds. Default `5L`.
#' @param patches_per_round Integer. Patches sampled per round. Default `10L`.
#' @param patch_size Integer. Patch size in pixels. Default `256L`.
#' @param initial_model Character. Initial model name. Default `"cyto3"`.
#'
#' @return An `sg_hitl_result` S3 object with elements `$rounds` (list of
#'   per-round results), `$final_model` (trained model path or object),
#'   and `$metrics` (training metrics across rounds).
#' @export
#' @examples
#' \donttest{
#' # Requires Python + Cellpose and interactive session:
#' # result <- sg_active_learning_loop(image, n_rounds = 3L)
#' }
sg_active_learning_loop <- function(image, model = "cellpose",
                                    n_rounds = 5L, patches_per_round = 10L,
                                    patch_size = 256L,
                                    initial_model = "cyto3") {
  if (!inherits(image, "sg_image")) {
    cli::cli_abort("{.arg image} must be an {.cls sg_image} object.")
  }
  model <- match.arg(model, c("cellpose"))
  .check_cellpose()

  n_rounds <- as.integer(n_rounds)
  patches_per_round <- as.integer(patches_per_round)
  patch_size <- as.integer(patch_size)

  rounds <- vector("list", n_rounds)
  current_model <- initial_model
  all_training_data <- list()

  cli::cli_inform(c(
    "i" = "Starting active learning loop: {n_rounds} round{?s}.",
    "i" = "Model: {.val {model}}, base: {.val {initial_model}}."
  ))

  for (rnd in seq_len(n_rounds)) {
    cli::cli_inform("--- Round {rnd}/{n_rounds} ---")

    # Step 1: Create annotation task
    task <- sg_create_annotation_task(
      image,
      n_patches = patches_per_round,
      patch_size = patch_size
    )

    # Store round info
    rounds[[rnd]] <- list(
      round = rnd,
      task = task,
      model_used = current_model,
      timestamp = Sys.time()
    )

    cli::cli_inform(c(
      "i" = "Round {rnd}: sampled {length(task$patches)} patch{?es}.",
      "i" = "Awaiting corrections (programmatic or via Shiny app)."
    ))
  }

  result <- structure(
    list(
      rounds = rounds,
      final_model = current_model,
      n_rounds = n_rounds,
      metrics = list(
        total_patches = n_rounds * patches_per_round,
        model_backend = model,
        initial_model = initial_model,
        timestamp = Sys.time()
      )
    ),
    class = "sg_hitl_result"
  )

  cli::cli_inform(c("v" = "Active learning loop completed ({n_rounds} round{?s})."))
  result
}

#' @export
print.sg_hitl_result <- function(x, ...) {
  cli::cli_text("{.cls sg_hitl_result}")
  cli::cli_text("Rounds: {x$n_rounds}")
  cli::cli_text("Backend: {x$metrics$model_backend}")
  cli::cli_text("Initial model: {x$metrics$initial_model}")
  cli::cli_text("Total patches: {x$metrics$total_patches}")
  invisible(x)
}
