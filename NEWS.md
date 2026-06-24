# segmantR (development version)

## Bug fixes

* `sg_segment_threshold(method = "adaptive")` no longer errors with
  "replacement has length zero". The internal integral-image lookup now
  treats out-of-range indices as contributing zero, so adaptive
  thresholding works for all images.

# segmantR 0.1.0

* Initial release.
* Classical segmentation: adaptive thresholding, watershed, Voronoi propagation.
* Deep learning wrappers: Cellpose, StarDist, Mesmer (via reticulate).
* Human-in-the-loop annotation and correction workflow.
* Custom model training and portable model export (`.segmantR` archives).
* Feature extraction: intensity, morphology, texture, location.
* Shiny application with six tabs for interactive segmentation workflows.
* Export to GeoJSON, QuPath, CSV, SpatialExperiment.
* Bundled synthetic sample data for demonstrations.
