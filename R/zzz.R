# Package load and attach hooks

#' @noRd
.onLoad <- function(libname, pkgname) {
  # Reserved for future initialisation (e.g., default options)
  invisible(NULL)
}

#' @noRd
.onAttach <- function(libname, pkgname) {
  ver <- utils::packageVersion(pkgname)

  # Optional backends (EBImage, Python/reticulate, QuPath) are checked at the
  # point of use only, so attaching never loads Python or Bioconductor
  # packages. See sg_interchange_capabilities(check_backends = TRUE).
  packageStartupMessage(
    "segmantR v", ver, " -- Cell Segmentation with Human-in-the-Loop\n",
    "Optional backends are checked when used; see sg_interchange_capabilities()."
  )
}
