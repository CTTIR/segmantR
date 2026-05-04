# Package load and attach hooks

#' @noRd
.onLoad <- function(libname, pkgname) {
  # Reserved for future initialisation (e.g., default options)
  invisible(NULL)
}

#' @noRd
.onAttach <- function(libname, pkgname) {
  ver <- utils::packageVersion(pkgname)

  backends <- character(0)
  if (requireNamespace("EBImage", quietly = TRUE)) {
    backends <- c(backends, "EBImage")
  }
  if (requireNamespace("reticulate", quietly = TRUE)) {
    if (reticulate::py_module_available("cellpose")) {
      backends <- c(backends, "cellpose")
    }
    if (reticulate::py_module_available("stardist")) {
      backends <- c(backends, "stardist")
    }
  }

  backend_msg <- if (length(backends) > 0L) {
    paste0("Backends: ", paste(backends, collapse = ", "))
  } else {
    "Backends: none detected (using pure-R methods)"
  }

  packageStartupMessage(
    "segmantR v", ver, " -- Cell Segmentation with Human-in-the-Loop\n",
    backend_msg
 )
}
