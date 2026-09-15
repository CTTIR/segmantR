# Classified conditions for the interchange, protocol and model contracts
#
# Every error raised by the contract code inherits from `sg_error` and one
# subclass, and carries a stable machine-readable `code` plus sanitised
# `details`. Callers can branch on the class or the code:
#
#   tryCatch(sg_import_interchange(p), sg_integrity_error = function(e) e$code)

#' Condition classes used by segmantR contracts
#'
#' Functions of the interchange, protocol, dataset, model and QuPath
#' adapters signal errors of class `sg_error` with one subclass. Each
#' condition has a `code` field (for example `"INTEGRITY_MISMATCH"`) and a
#' `details` list that never contains absolute file paths.
#'
#' \describe{
#'   \item{`sg_validation_error`}{Invalid input, schema or parameter
#'     (`VALIDATION_FAILED`, `UNKNOWN_PARAMETER`, `PARAMETER_OUT_OF_RANGE`,
#'     `DTYPE_MISMATCH`, `DIMENSION_MISMATCH`, `INVALID_PLANE`,
#'     `LEGEND_INCOMPLETE`, `NOT_INSTANCE_MASK`, `SPLIT_LEAKAGE`).}
#'   \item{`sg_protocol_error`}{Unknown protocol or unsupported schema major
#'     version (`PROTOCOL_NOT_FOUND`, `PROTOCOL_MISMATCH`,
#'     `SCHEMA_MISMATCH`).}
#'   \item{`sg_capability_error`}{An optional backend or runtime is missing
#'     (`CAPABILITY_UNAVAILABLE`).}
#'   \item{`sg_calibration_error`}{Pixel calibration is missing but required
#'     (`CALIBRATION_MISSING`).}
#'   \item{`sg_conflict_error`}{Revision or overwrite conflicts
#'     (`REVISION_CONFLICT`, `REVIEWED_OVERWRITE_DENIED`,
#'     `DESTINATION_EXISTS`, `IDEMPOTENCY_CONFLICT`).}
#'   \item{`sg_integrity_error`}{Hash, size or inventory mismatch
#'     (`INTEGRITY_MISMATCH`, `ARCHIVE_UNSAFE`).}
#'   \item{`sg_security_error`}{Path traversal or unsafe resource
#'     (`PATH_OUTSIDE_ROOT`).}
#' }
#'
#' @name sg_conditions
#' @keywords internal
NULL

#' Signal a classified segmantR error
#' @param message Character vector passed to [cli::cli_abort()].
#' @param class Subclass name, e.g. `"sg_validation_error"`.
#' @param code Stable error code.
#' @param details Named list of sanitised details.
#' @param .envir Environment for cli interpolation.
#' @noRd
.sg_abort <- function(message, class = "sg_validation_error",
                      code = "VALIDATION_FAILED", details = list(),
                      .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = c(class, "sg_error"),
    code = code,
    details = details,
    .envir = .envir
  )
}

#' Abort because an optional backend is not available
#' @noRd
.sg_abort_unavailable <- function(what, hint, details = list()) {
  .sg_abort(
    c("{what} is not available.", "i" = "{hint}"),
    class = "sg_capability_error",
    code = "CAPABILITY_UNAVAILABLE",
    details = c(list(capability = what), details)
  )
}

#' Escape text so cli does not interpolate braces in it
#' @noRd
.sg_cli_escape <- function(x) {
  gsub("\\}", "}}", gsub("\\{", "{{", x))
}
