# Histology ROI transfer

Source provenance is recorded in source-provenance.json. The original MIT-licensed
ROI geometry, layer, project, rasterization and QuPath modules were transferred
from annotatR at the recorded revision. Public names use sg_roi_*; internal
helpers and classes are isolated from segmantR's existing sg_image/sg_mask APIs.
No annotatR runtime dependency exists. Existing QuPath UUID seed and annotatr_*
metadata keys remain wire compatibility details, not a runtime dependency.

The frame constructor is metadata-only. No HSI image readers, spectral cubes,
Shiny annotation UI, control service, training/handoff service or image backend
is transferred. Existing segmantR instance-mask QuPath APIs remain separate.
Native QuPath reopening, browser interaction and production pipeline adoption
require separate qualification; bundled historical QuPath fixtures are source
provenance, not evidence of a new native QuPath run.

Geometry coordinates use top-left origin, x right, y down. Declare non-power-of-
two pyramid dimensions explicitly in sg_roi_frame; sg_roi_transform uses their
per-axis ratios. Standalone ROI rescaling assumes powers of two. Cropped/global
coordinate transforms must be explicit. Mask pixel_size statistics take the
physical pixel size at the mask's own level, not automatically level-zero size.
Rasterizing an ROI is a separate conversion; import/export keeps vector geometry
rather than round-tripping through an instance mask. Ellipse polygons retain
approximation provenance. Text-valued QuPath measurements are not a supported
numeric measurement interchange; imported value states remain inspectable.

Derived geometries can inherit imported native-shape metadata; that metadata
is provenance, not certification that a derived polygon remains a native ellipse.
Nucleus geometry is retained as imported JSON: applications that rescale or
derive cell ROIs must also reconcile nucleus coordinates explicitly.
