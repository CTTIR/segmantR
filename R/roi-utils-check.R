# Abort for an invalid argument: a classified validation error attributed to the
# user-facing caller. `.envir` is the validator's frame so its variables
# interpolate into the message.
.sg_roi_check_abort <- function(message, call, .envir = parent.frame()) {
  cli::cli_abort(message, class = c("sg_roi_validation_error", "sg_roi_error"),
                 code = "VALIDATION_FAILED", call = call, .envir = .envir)
}

# Internal input validators. Each accepts `arg` (the caller's argument name)
# and `call` (the caller's environment) so that errors are attributed to the
# user-facing function, not to the validator. None are exported.
#
# Every validator returns its (coerced) input invisibly on success and aborts
# via `.sg_roi_check_abort()` on failure.

# A single non-missing string.
.sg_roi_check_string <- function(x,
                          allow_null = FALSE,
                          arg = rlang::caller_arg(x),
                          call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(x))
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be a single string.",
        "x" = "You supplied {.cls {class(x)[1]}} of length {length(x)}."
      ),
      call = call
    )
  }
  invisible(x)
}

# A single non-missing TRUE/FALSE.
.sg_roi_check_flag <- function(x,
                        arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be a single {.code TRUE} or {.code FALSE}.",
        "x" = "You supplied {.cls {class(x)[1]}} of length {length(x)}."
      ),
      call = call
    )
  }
  invisible(x)
}

# A single finite number, optionally bounded.
.sg_roi_check_number <- function(x,
                          min = -Inf,
                          max = Inf,
                          allow_null = FALSE,
                          arg = rlang::caller_arg(x),
                          call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(x))
  }
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be a single finite number.",
        "x" = "You supplied {.cls {class(x)[1]}} of length {length(x)}."
      ),
      call = call
    )
  }
  if (x < min || x > max) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be in the range [{min}, {max}].",
        "x" = "You supplied {.val {x}}."
      ),
      call = call
    )
  }
  invisible(as.numeric(x))
}

# A single non-negative whole number (a count). Returns an integer.
.sg_roi_check_count <- function(x,
                         min = 0L,
                         arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x != round(x)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be a single whole number.",
        "x" = "You supplied {.cls {class(x)[1]}} of length {length(x)}."
      ),
      call = call
    )
  }
  xi <- as.integer(round(x))
  if (xi < min) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be at least {min}.",
        "x" = "You supplied {.val {xi}}."
      ),
      call = call
    )
  }
  invisible(xi)
}

# An existing file.
.sg_roi_check_file <- function(x,
                        arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  .sg_roi_check_string(x, arg = arg, call = call)
  if (!file.exists(x) || dir.exists(x)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be an existing file.",
        "x" = "{.path {x}} does not exist.",
        "i" = "Supply the path to an existing annotation file."
      ),
      call = call
    )
  }
  invisible(x)
}

# An existing directory.
.sg_roi_check_dir <- function(x,
                       arg = rlang::caller_arg(x),
                       call = rlang::caller_env()) {
  .sg_roi_check_string(x, arg = arg, call = call)
  if (!dir.exists(x)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be an existing directory.",
        "x" = "{.path {x}} does not exist or is not a directory."
      ),
      call = call
    )
  }
  invisible(x)
}

# `x` must inherit from S3 class `cls`.
.sg_roi_check_class <- function(x,
                         cls,
                         allow_null = FALSE,
                         arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(x))
  }
  if (!inherits(x, cls)) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be a {.cls {cls}} object.",
        "x" = "You supplied {.cls {class(x)[1]}}."
      ),
      call = call
    )
  }
  invisible(x)
}

# `x` must be exactly one of `choices` (no partial matching). Returns the match.
# When `x` is the full `choices` vector (the `c(...)` default idiom), the first
# choice is returned, mirroring `match.arg()`.
.sg_roi_check_choice <- function(x,
                          choices,
                          arg = rlang::caller_arg(x),
                          call = rlang::caller_env()) {
  if (identical(x, choices)) {
    return(choices[[1]])
  }
  if (length(x) == 0L) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be one of {.or {.val {choices}}}.",
        "x" = "You supplied a length-0 value."
      ),
      call = call
    )
  }
  if (length(x) != 1L) {
    x <- x[[1]]
  }
  if (is.numeric(choices)) {
    if (!is.numeric(x) || is.na(x) || !x %in% choices) {
      .sg_roi_check_abort(
        c(
          "{.arg {arg}} must be one of {.or {.val {choices}}}.",
          "x" = "You supplied {.val {x}}."
        ),
        call = call
      )
    }
    return(choices[match(x, choices)])
  }
  if (!is.character(x) || is.na(x) || !x %in% choices) {
    .sg_roi_check_abort(
      c(
        "{.arg {arg}} must be one of {.or {.val {choices}}}.",
        "x" = "You supplied {.val {x}}."
      ),
      call = call
    )
  }
  x
}

# Domain-object validators.

.sg_roi_check_image <- function(x,
                         arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  .sg_roi_check_class(x, "sg_roi_frame", arg = arg, call = call)
}

.sg_roi_check_roi <- function(x,
                       arg = rlang::caller_arg(x),
                       call = rlang::caller_env()) {
  .sg_roi_check_class(x, "sg_roi", arg = arg, call = call)
}

.sg_roi_check_layer <- function(x,
                         arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  .sg_roi_check_class(x, "sg_roi_layer", arg = arg, call = call)
}

.sg_roi_check_project <- function(x,
                           arg = rlang::caller_arg(x),
                           call = rlang::caller_env()) {
  .sg_roi_check_class(x, "sg_roi_project", arg = arg, call = call)
}
