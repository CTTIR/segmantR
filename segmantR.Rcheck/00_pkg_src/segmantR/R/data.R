# Documentation stubs for bundled example data
# Actual data is generated on the fly by sg_example_image() / sg_example_mask()

#' Example images for segmantR
#'
#' Synthetic 64x64 test images used for examples and demonstrations.
#' Generated on the fly by \code{\link{sg_example_image}}.
#'
#' @name example_images
#' @title Example segmantR images
#' @description
#' Three synthetic image types are available:
#' \describe{
#'   \item{he_breast}{64x64 single-channel matrix simulating an H&E stained
#'     breast tissue section with approximately 20 cell-like blobs.}
#'   \item{fluorescence_nuclei}{64x64 single-channel matrix simulating
#'     DAPI-stained nuclei with approximately 15 bright spots on a dark
#'     background.}
#'   \item{multiplex_4ch}{64x64x4 array simulating a 4-channel multiplex
#'     panel (DAPI, CD3, CD8, PanCK) with approximately 18 cells.}
#' }
#' @format An \code{sg_image} object.
#' @seealso \code{\link{sg_example_image}}, \code{\link{sg_example_mask}}
NULL

#' Example masks for segmantR
#'
#' Synthetic 64x64 label matrices matching the example images.
#' Generated on the fly by \code{\link{sg_example_mask}}.
#'
#' @name example_masks
#' @title Example segmantR masks
#' @description
#' Three synthetic mask types are available, each corresponding to an
#' example image type. Masks are integer matrices where 0 is background
#' and positive integers are cell IDs.
#' @format An \code{sg_mask} object.
#' @seealso \code{\link{sg_example_mask}}, \code{\link{sg_example_image}}
NULL
