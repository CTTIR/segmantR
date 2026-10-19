.sg_roi_at_abort <- function(message, class = "validation", code = "VALIDATION_FAILED", details = list(), call = rlang::caller_env(), .envir = parent.frame()) {
 cli::cli_abort(message, class = c(paste0("sg_roi_", class, "_error"), "sg_roi_error"), code = code, details = details, call = call, .envir = .envir)
}
.sg_roi_sha256_bytes <- function(x, call = rlang::caller_env()) {
 if (is.character(x)) x <- charToRaw(enc2utf8(paste(x, collapse = "")))
 digest::digest(x, algo = "sha256", serialize = FALSE)
}
