#' segmantR: Cell Segmentation for Histology with Human-in-the-Loop Training
#'
#' Cell segmentation for histology and multiplexed tissue imaging: classical
#' methods that run in R alone, optional deep learning backends through
#' 'reticulate', a human-in-the-loop correction and training workflow, and
#' reproducible exchange with 'QuPath' and partner packages.
#'
#' @section Where to start:
#' * Images and masks: [new_sg_image()], [sg_read_image()], [new_sg_mask()],
#'   and the synthetic examples from [sg_example_image()] and
#'   [sg_example_mask()].
#' * Segmentation: [sg_segment_threshold()], [sg_segment_watershed()] and
#'   [sg_segment_propagate()] need no Python; [sg_segment_cellpose()],
#'   [sg_segment_stardist()] and [sg_segment_mesmer()] use a Python
#'   environment selected with [sg_setup_python()].
#' * Measurement and evaluation: [sg_extract_features()],
#'   [sg_evaluate_segmentation()].
#' * Figures: [sg_plot_overlay()], [sg_plot_mask()], [sg_plot_features()],
#'   [sg_plot_comparison()], [sg_plot_metrics()].
#' * Reproducible runs and exchange: [sg_protocol_run()],
#'   [sg_export_interchange()], [sg_import_interchange()],
#'   [sg_export_qupath()].
#' * Interactive correction: [sg_app()] and [sg_run_app()].
#'
#' See `vignette("segmantR")` for a first workflow and
#' `vignette("protocols-and-interop")` for protocols and exchange formats.
#'
#' @keywords internal
"_PACKAGE"
