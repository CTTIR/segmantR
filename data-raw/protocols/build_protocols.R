# Generates inst/protocols/*.json from the definitions below.
#
# Run from the package root:  Rscript data-raw/protocols/build_protocols.R
#
# The generated JSON files are the shipped, declarative protocol registry.
# This script only avoids copy-paste errors between protocols; it is not
# needed at runtime and is excluded from the package build.

pkgload::load_all(".", quiet = TRUE)

p_int <- function(default, description, minimum = NULL, maximum = NULL,
                  unit = "px", nullable = FALSE, calib = FALSE, odd = NULL,
                  enum = NULL) {
  out <- list(type = "integer", default = default, unit = unit,
              requires_calibration = calib, description = description)
  if (!is.null(minimum)) out$minimum <- minimum
  if (!is.null(maximum)) out$maximum <- maximum
  if (nullable) out$nullable <- TRUE
  if (!is.null(odd)) out$odd <- odd
  if (!is.null(enum)) out$enum <- I(enum)
  out
}
p_num <- function(default, description, minimum = NULL, maximum = NULL,
                  unit = "none", nullable = FALSE, calib = FALSE,
                  exclusive_minimum = NULL) {
  out <- list(type = "number", default = default, unit = unit,
              requires_calibration = calib, description = description)
  if (!is.null(minimum)) out$minimum <- minimum
  if (!is.null(maximum)) out$maximum <- maximum
  if (!is.null(exclusive_minimum)) out$exclusive_minimum <- exclusive_minimum
  if (nullable) out$nullable <- TRUE
  out
}
p_bool <- function(default, description) {
  list(type = "boolean", default = default, unit = "none",
       requires_calibration = FALSE, description = description)
}
p_str <- function(default, description, enum = NULL, nullable = FALSE,
                  unit = "none") {
  out <- list(type = "string", default = default, unit = unit,
              requires_calibration = FALSE, description = description)
  if (!is.null(enum)) out$enum <- I(enum)
  if (nullable) out$nullable <- TRUE
  out
}

channel_params <- list(
  channel = p_int(1L, paste(
    "1-based channel (band) position in the [y, x, channel] array.",
    "Used when channel_name, wavelength_nm and band_operation are not set."
  ), minimum = 1, unit = "index"),
  channel_name = p_str(NULL, "Channel or band name to select instead of an index.",
                       nullable = TRUE, unit = "name"),
  wavelength_nm = p_num(NULL, paste(
    "Centre wavelength of the band to select (requires band wavelengths",
    "in the image metadata)."
  ), unit = "nm", nullable = TRUE, exclusive_minimum = 0),
  wavelength_tolerance_nm = p_num(5, paste(
    "Maximum distance between wavelength_nm and the nearest band centre."
  ), minimum = 0, unit = "nm"),
  band_operation = p_str("none", paste(
    "Registered band operation producing the single input channel:",
    "none (use the selected channel), band_mean (mean of bands within",
    "[band_min_nm, band_max_nm]), ratio (a / b) or normalized_difference",
    "((a - b) / (a + b)) of the bands nearest band_a_nm and band_b_nm."
  ), enum = c("none", "band_mean", "ratio", "normalized_difference")),
  band_a_nm = p_num(NULL, "Wavelength of band a for ratio/normalized_difference.",
                    unit = "nm", nullable = TRUE, exclusive_minimum = 0),
  band_b_nm = p_num(NULL, "Wavelength of band b for ratio/normalized_difference.",
                    unit = "nm", nullable = TRUE, exclusive_minimum = 0),
  band_min_nm = p_num(NULL, "Lower wavelength bound for band_mean.",
                      unit = "nm", nullable = TRUE, exclusive_minimum = 0),
  band_max_nm = p_num(NULL, "Upper wavelength bound for band_mean.",
                      unit = "nm", nullable = TRUE, exclusive_minimum = 0)
)

all_semantics <- c("unknown", "intensity", "raw", "reflectance", "radiance",
                   "absorbance", "probability")

core_runtime <- list(language = "R", requires_python = FALSE,
                     python_modules = I(character(0)),
                     r_packages = I(character(0)), gpu = "never",
                     install_hint = NULL, qupath = NULL)
core_seed <- list(policy = "deterministic", seed = NULL,
                  note = "The algorithm uses no random numbers.")
core_tiling <- list(mode = "none", tile_size = NULL, overlap = 0L,
                    max_pixels = 4194304L,
                    note = paste("Core protocols process the whole plane in",
                                 "memory; split larger images before running."))
provenance <- list(record = I(c("protocol_digest", "parameters_digest",
                                "input_digests", "runtime", "delegate_call",
                                "mask_revision", "measurements_digest")),
                   hash = "sha256")
no_norm <- list(normalization = list(method = "none", scope = "none",
                                     low = NULL, high = NULL, clip = FALSE,
                                     note = paste(
                                       "Thresholds are computed on the",
                                       "selected values; Otsu and triangle",
                                       "are invariant to affine scaling.")),
                target_pixel_size_um = NULL, resample = "none")
image_input <- list(role = "image", type = "sg_image", required = TRUE,
                    description = "Image providing the segmentation channel.")
channel_contract <- list(parameters = I(c("channel", "channel_name",
                                          "wavelength_nm", "band_operation")),
                         operation = "single", min_channels = 1L)
observed_range <- list(min = NULL, max = NULL, policy = "observed")
core_measure <- I(c("area", "centroid", "bbox", "mean_intensity"))

threshold_protocol <- function(method) {
  params <- c(channel_params, list(
    open_size = p_int(5L, paste(
      "Square structuring element size for morphological opening",
      "(erosion then dilation); 0 disables opening."
    ), minimum = 0, maximum = 51, odd = TRUE),
    fill_holes = p_bool(TRUE, "Fill background holes enclosed by foreground."),
    min_area = p_int(50L, "Minimum object area.", minimum = 0, unit = "px2"),
    max_area = p_int(5000L, "Maximum object area.", minimum = 1, unit = "px2")
  ))
  mapping <- list(channel = "channel", open_size = "morphology.open",
                  fill_holes = "morphology.fill_holes", min_area = "min_area",
                  max_area = "max_area")
  if (method == "adaptive") {
    params$block_size <- p_int(51L, "Odd window size of the local mean.",
                               minimum = 3, maximum = 1025, odd = TRUE)
    params$offset <- p_num(0.05, paste(
      "Value subtracted from the local mean, in units of the selected",
      "channel values."
    ), unit = "intensity")
    mapping$block_size <- "block_size"
    mapping$offset <- "offset"
  }
  titles <- c(otsu = "Global Otsu threshold",
              adaptive = "Adaptive local-mean threshold",
              triangle = "Triangle threshold")
  list(
    schema = "segmantR-protocol-v1",
    id = paste0("threshold.", method, ".v1"),
    version = "1.0.0",
    title = unname(titles[method]),
    description = paste(
      "Thresholds one channel with the", method, "rule, applies",
      "morphological opening and hole filling, labels 4-connected",
      "components and removes objects outside the area limits.",
      "Delegates to sg_segment_threshold() with identical defaults."
    ),
    family = "threshold",
    input_contract = list(array_order = "y,x,channel",
                          inputs = list(image_input),
                          channel = channel_contract,
                          value_semantics = I(all_semantics),
                          value_range = observed_range,
                          calibration = list(required = "never",
                                             parameters = I(character(0))),
                          min_shape_yx = I(c(3L, 3L))),
    preprocess = no_norm,
    method = list(backend = "segmantR-core",
                  delegate = "sg_segment_threshold",
                  fixed_arguments = list(method = method),
                  mapping = mapping),
    postprocess = list(steps = list()),
    tiling = core_tiling,
    output_contract = list(mask_type = "instance", dtype = "int32",
                           background = 0L, connectivity = 4L,
                           label_order = "raster", measurements = core_measure,
                           status = "draft"),
    runtime_profile = core_runtime,
    seed_policy = core_seed,
    provenance_policy = provenance,
    parameters = params,
    extensions = .sg_json_object()
  )
}

watershed_protocol <- function(seed_method) {
  params <- c(channel_params, list(
    h = p_num(0.05, paste(
      "Fraction of the maximum distance-transform value above which pixels",
      "become seeds."
    ), minimum = 0, maximum = 1, unit = "fraction"),
    expand_method = p_str("voronoi", "Region expansion after flooding.",
                          enum = c("voronoi", "dilation")),
    expand_pixels = p_int(3L, "Expansion distance after flooding.",
                          minimum = 0, maximum = 1000),
    membrane_channel = p_int(NULL, paste(
      "1-based channel used as flooding surface; null uses the inverted",
      "segmentation channel."
    ), minimum = 1, unit = "index", nullable = TRUE)
  ))
  note <- if (seed_method == "h_minima") {
    paste(" In segmantR 0.1.x the h_minima seed rule uses the same",
          "distance-transform fraction as watershed.distance.v1; both",
          "protocols are kept so recorded runs stay unambiguous.")
  } else {
    ""
  }
  list(
    schema = "segmantR-protocol-v1",
    id = paste0("watershed.", seed_method, ".v1"),
    version = "1.0.0",
    title = paste("Marker-controlled watershed,", seed_method, "seeds"),
    description = paste0(
      "Otsu foreground, distance-transform seeds (h fraction), greedy ",
      "4-neighbour flooding and optional expansion. Delegates to ",
      "sg_segment_watershed(seed_method = '", seed_method, "'). The ",
      "min_distance argument of the direct function is not used by the core ",
      "implementation and is therefore not a protocol parameter.", note
    ),
    family = "watershed",
    input_contract = list(array_order = "y,x,channel",
                          inputs = list(image_input),
                          channel = channel_contract,
                          value_semantics = I(all_semantics),
                          value_range = observed_range,
                          calibration = list(required = "never",
                                             parameters = I(character(0))),
                          min_shape_yx = I(c(3L, 3L))),
    preprocess = no_norm,
    method = list(backend = "segmantR-core",
                  delegate = "sg_segment_watershed",
                  fixed_arguments = list(seed_method = seed_method),
                  mapping = list(channel = "channel", h = "h",
                                 expand_method = "expand_method",
                                 expand_pixels = "expand_pixels",
                                 membrane_channel = "membrane_channel")),
    postprocess = list(steps = list()),
    tiling = core_tiling,
    output_contract = list(mask_type = "instance", dtype = "int32",
                           background = 0L, connectivity = 4L,
                           label_order = "raster", measurements = core_measure,
                           status = "draft"),
    runtime_profile = core_runtime,
    seed_policy = core_seed,
    provenance_policy = provenance,
    parameters = params,
    extensions = .sg_json_object()
  )
}

propagate_protocol <- list(
  schema = "segmantR-protocol-v1",
  id = "propagate.voronoi.v1",
  version = "1.0.0",
  title = "Voronoi propagation from seed labels",
  description = paste(
    "Expands seed labels (for example nuclei) by 4-neighbour majority",
    "propagation for at most expand_max iterations. An optional membrane",
    "image restricts growth to pixels below its 90th percentile. Always uses",
    "the pure-R engine (sg_segment_propagate(engine = 'voronoi_r')) so the",
    "result does not depend on whether EBImage is installed."
  ),
  family = "propagate",
  input_contract = list(
    array_order = "y,x,channel",
    inputs = list(
      list(role = "image", type = "sg_image", required = TRUE,
           description = "Image the seeds belong to (defines the grid)."),
      list(role = "seeds", type = "sg_mask", required = TRUE,
           mask_type = "instance",
           description = "Instance mask with one label per seed."),
      list(role = "membrane", type = "sg_image", required = FALSE,
           description = "Optional single-channel membrane image.")
    ),
    channel = NULL,
    value_semantics = I(all_semantics),
    value_range = observed_range,
    calibration = list(required = "never", parameters = I(character(0))),
    min_shape_yx = I(c(3L, 3L))
  ),
  preprocess = list(normalization = list(method = "none", scope = "none",
                                         low = NULL, high = NULL,
                                         clip = FALSE,
                                         note = "Pixel values are not used."),
                    target_pixel_size_um = NULL, resample = "none"),
  method = list(backend = "segmantR-core", delegate = "sg_segment_propagate",
                fixed_arguments = list(engine = "voronoi_r"),
                mapping = list(expand_max = "expand_max")),
  postprocess = list(steps = list()),
  tiling = core_tiling,
  output_contract = list(mask_type = "instance", dtype = "int32",
                         background = 0L, connectivity = 4L,
                         label_order = "value",
                         measurements = I(c("area", "centroid", "bbox")),
                         status = "draft"),
  runtime_profile = core_runtime,
  seed_policy = core_seed,
  provenance_policy = provenance,
  parameters = list(
    expand_max = p_int(20L, "Maximum number of propagation iterations.",
                       minimum = 1, maximum = 10000, unit = "count")
  ),
  extensions = .sg_json_object()
)

cleanup_protocol <- list(
  schema = "segmantR-protocol-v1",
  id = "postprocess.label-cleanup.v1",
  version = "1.0.0",
  title = "Label cleanup",
  description = paste(
    "Removes objects outside area limits, optionally fills holes, splits or",
    "prunes disconnected parts, removes border objects, separates touching",
    "objects (the higher label yields its contact pixels) and relabels.",
    "Steps run in this order: disconnected, fill_holes, touching, border,",
    "area filter, relabel. Delegates to sg_cleanup_labels()."
  ),
  family = "postprocess",
  input_contract = list(
    array_order = "y,x,channel",
    inputs = list(list(role = "mask", type = "sg_mask", required = TRUE,
                       description = "Mask to clean."),
                  list(role = "reference", type = "sg_image",
                       required = FALSE,
                       description = paste(
                         "Optional image providing pixel calibration",
                         "(for the um2 limits) and intensities for",
                         "measurements."))),
    channel = NULL,
    value_semantics = I(all_semantics),
    value_range = observed_range,
    calibration = list(required = "when_parameters_set",
                       parameters = I(c("min_area_um2", "max_area_um2"))),
    min_shape_yx = I(c(1L, 1L))
  ),
  preprocess = list(normalization = list(method = "none", scope = "none",
                                         low = NULL, high = NULL,
                                         clip = FALSE,
                                         note = "Operates on labels only."),
                    target_pixel_size_um = NULL, resample = "none"),
  method = list(backend = "segmantR-core", delegate = "sg_cleanup_labels",
                mapping = list(min_area = "min_area", max_area = "max_area",
                               min_area_um2 = "min_area_um2",
                               max_area_um2 = "max_area_um2",
                               fill_holes = "fill_holes",
                               connectivity = "connectivity",
                               border = "border", touching = "touching",
                               disconnected = "disconnected",
                               relabel = "relabel")),
  postprocess = list(steps = list()),
  tiling = core_tiling,
  output_contract = list(mask_type = "instance", dtype = "int32",
                         background = 0L, connectivity = NULL,
                         label_order = "value",
                         measurements = I(c("area", "centroid", "bbox")),
                         status = "draft"),
  runtime_profile = core_runtime,
  seed_policy = core_seed,
  provenance_policy = provenance,
  parameters = list(
    min_area = p_int(0L, "Minimum object area.", minimum = 0, unit = "px2"),
    max_area = p_int(NULL, "Maximum object area; null = no limit.",
                     minimum = 1, unit = "px2", nullable = TRUE),
    min_area_um2 = p_num(NULL, "Minimum object area in square micrometres.",
                         minimum = 0, unit = "um2", nullable = TRUE,
                         calib = TRUE),
    max_area_um2 = p_num(NULL, "Maximum object area in square micrometres.",
                         exclusive_minimum = 0, unit = "um2", nullable = TRUE,
                         calib = TRUE),
    fill_holes = p_bool(FALSE, "Fill background holes enclosed by one label."),
    connectivity = p_int(4L, "Object connectivity (4 or 8).", unit = "none",
                         enum = c(4L, 8L)),
    border = p_str("keep", "Objects touching the array border.",
                   enum = c("keep", "remove")),
    touching = p_str("keep", "Touching objects of different labels.",
                     enum = c("keep", "separate")),
    disconnected = p_str("keep", "Labels made of several disconnected parts.",
                         enum = c("keep", "split", "keep_largest")),
    relabel = p_str("value", paste(
      "Relabel to 1..N keeping label order (value), by raster order",
      "(raster) or not at all (none)."
    ), enum = c("value", "raster", "none"))
  ),
  extensions = .sg_json_object()
)

dnn_seed <- list(policy = "backend", seed = NULL,
                 note = paste("Inference with fixed weights is deterministic",
                              "on CPU; GPU kernels may introduce small",
                              "differences."))
dnn_semantics <- I(c("unknown", "intensity", "raw"))

stardist_protocol <- list(
  schema = "segmantR-protocol-v1",
  id = "stardist.2d.v1",
  version = "1.0.0",
  title = "StarDist 2D nucleus segmentation (optional backend)",
  description = paste(
    "Star-convex polygon nucleus detection. The R path delegates to",
    "sg_segment_stardist() through reticulate; sg_stardist_parameter_map()",
    "maps the same parameters to the QuPath StarDist extension. Predictions",
    "are staged for review. Percentile normalisation with low = 0 and",
    "high = 100 equals the min-max normalisation of sg_segment_stardist()."
  ),
  family = "dnn",
  input_contract = list(
    array_order = "y,x,channel",
    inputs = list(image_input,
                  list(role = "trained_model", type = "sg_trained_model",
                       required = FALSE,
                       description = "Custom StarDist model (backend stardist).")),
    channel = list(parameters = I(c("channel", "channel_name",
                                    "wavelength_nm")),
                   operation = "single", min_channels = 1L),
    value_semantics = dnn_semantics,
    value_range = observed_range,
    calibration = list(required = "when_parameters_set",
                       parameters = I(c("pixel_size_um", "cell_expansion_um"))),
    min_shape_yx = I(c(16L, 16L))
  ),
  preprocess = list(normalization = list(method = "percentile",
                                         scope = "global", low = 0,
                                         high = 100, clip = FALSE,
                                         note = paste(
                                           "Bounds come from the",
                                           "normalize_low/normalize_high",
                                           "parameters.")),
                    target_pixel_size_um = NULL, resample = "backend"),
  method = list(backend = "python-stardist", delegate = "sg_segment_stardist",
                mapping = list(channel = "channel", model = "model",
                               prob_thresh = "prob_thresh",
                               nms_thresh = "nms_thresh",
                               normalize_low = NULL, normalize_high = NULL,
                               normalize_scope = NULL,
                               pixel_size_um = "scale",
                               tile_size = "n_tiles",
                               include_probability = NULL,
                               cell_expansion_um = NULL,
                               create_annotations = NULL,
                               classification = NULL)),
  postprocess = list(steps = list()),
  tiling = list(mode = "backend", tile_size = 1024L, overlap = NULL,
                max_pixels = NULL,
                note = paste("tile_size maps to StarDist n_tiles",
                             "(ceiling(dimension / tile_size)) and to",
                             "QuPath tileSize; overlap is determined by the",
                             "backend from the model receptive field.")),
  output_contract = list(mask_type = "instance", dtype = "int32",
                         background = 0L, connectivity = NULL,
                         label_order = "backend", measurements = core_measure,
                         status = "staged"),
  runtime_profile = list(
    language = "R", requires_python = TRUE,
    python_modules = I(c("stardist", "tensorflow")),
    r_packages = I("reticulate"), gpu = "optional",
    install_hint = paste("Install the Python packages 'stardist' and",
                         "'tensorflow' (sg_setup_python(backends =",
                         "'stardist')) and make them visible to reticulate."),
    qupath = list(min_version = "0.5.0",
                  extension = "qupath-extension-stardist",
                  min_extension_version = "0.5.0")
  ),
  seed_policy = dnn_seed,
  provenance_policy = list(record = I(c("protocol_digest", "parameters_digest",
                                        "input_digests", "runtime",
                                        "delegate_call", "mask_revision",
                                        "measurements_digest",
                                        "model_digest")),
                           hash = "sha256"),
  parameters = c(channel_params[c("channel", "channel_name", "wavelength_nm",
                                  "wavelength_tolerance_nm")], list(
    model = p_str("2D_versatile_fluo", paste(
      "Pretrained model name; ignored when a model input is supplied."
    ), enum = c("2D_versatile_fluo", "2D_versatile_he", "2D_paper_dsb2018")),
    prob_thresh = p_num(0.5, "Object probability threshold (QuPath: threshold).",
                        minimum = 0, maximum = 1, unit = "fraction"),
    nms_thresh = p_num(0.4, "Non-maximum suppression overlap threshold.",
                       minimum = 0, maximum = 1, unit = "fraction"),
    normalize_low = p_num(0, "Lower normalisation percentile.",
                          minimum = 0, maximum = 100, unit = "percentile"),
    normalize_high = p_num(100, "Upper normalisation percentile.",
                           minimum = 0, maximum = 100, unit = "percentile"),
    normalize_scope = p_str("global", paste(
      "global: percentiles of the whole plane; tile: percentiles per tile",
      "(QuPath normalizePercentiles)."
    ), enum = c("global", "tile")),
    pixel_size_um = p_num(NULL, paste(
      "Target pixel size the model expects; null = use the image as is."
    ), exclusive_minimum = 0, unit = "um", nullable = TRUE, calib = TRUE),
    tile_size = p_int(NULL, "Tile size for prediction; null = backend default.",
                      minimum = 64, maximum = 16384, nullable = TRUE),
    include_probability = p_bool(FALSE, "Store the object probability."),
    cell_expansion_um = p_num(NULL, paste(
      "QuPath only: expand nuclei to approximate cells by this distance."
    ), exclusive_minimum = 0, unit = "um", nullable = TRUE, calib = TRUE),
    create_annotations = p_bool(FALSE, "QuPath only: create annotations instead of detections."),
    classification = p_str(NULL, "Class name assigned to all objects.",
                           nullable = TRUE, unit = "name")
  )),
  extensions = .sg_json_object()
)

cellpose_protocol <- list(
  schema = "segmantR-protocol-v1",
  id = "cellpose.2d.v1",
  version = "1.0.0",
  title = "Cellpose 2D cell segmentation (optional backend)",
  description = paste(
    "Delegates to sg_segment_cellpose() through reticulate. Channel indices",
    "follow the Cellpose convention (0 = grayscale, 1..3 = channel).",
    "Predictions are staged for review."
  ),
  family = "dnn",
  input_contract = list(
    array_order = "y,x,channel",
    inputs = list(image_input,
                  list(role = "trained_model", type = "sg_trained_model",
                       required = FALSE,
                       description = "Custom Cellpose model (backend cellpose).")),
    channel = list(parameters = I(c("cytoplasm_channel", "nucleus_channel")),
                   operation = "stack", min_channels = 1L),
    value_semantics = dnn_semantics,
    value_range = observed_range,
    calibration = list(required = "when_parameters_set",
                       parameters = I("diameter_um")),
    min_shape_yx = I(c(16L, 16L))
  ),
  preprocess = list(normalization = list(method = "percentile",
                                         scope = "global", low = 1,
                                         high = 99, clip = FALSE,
                                         note = paste(
                                           "Performed inside Cellpose",
                                           "(normalize = True default).")),
                    target_pixel_size_um = NULL, resample = "backend"),
  method = list(backend = "python-cellpose", delegate = "sg_segment_cellpose",
                mapping = list(model = "model",
                               cytoplasm_channel = "channels.cytoplasm",
                               nucleus_channel = "channels.nucleus",
                               diameter = "diameter", diameter_um = "diameter",
                               flow_threshold = "flow_threshold",
                               cellprob_threshold = "cellprob_threshold",
                               batch_size = "batch_size", tile = "tile")),
  postprocess = list(steps = list()),
  tiling = list(mode = "backend", tile_size = 224L, overlap = NULL,
                max_pixels = NULL,
                note = "Cellpose tiles internally (224 px, 10% overlap) when tile = true."),
  output_contract = list(mask_type = "instance", dtype = "int32",
                         background = 0L, connectivity = NULL,
                         label_order = "backend", measurements = core_measure,
                         status = "staged"),
  runtime_profile = list(
    language = "R", requires_python = TRUE, python_modules = I("cellpose"),
    r_packages = I("reticulate"), gpu = "optional",
    install_hint = paste("Install the Python package 'cellpose'",
                         "(sg_setup_python(backends = 'cellpose')) and make",
                         "it visible to reticulate."),
    qupath = NULL
  ),
  seed_policy = dnn_seed,
  provenance_policy = list(record = I(c("protocol_digest", "parameters_digest",
                                        "input_digests", "runtime",
                                        "delegate_call", "mask_revision",
                                        "measurements_digest",
                                        "model_digest")),
                           hash = "sha256"),
  parameters = list(
    model = p_str("cyto3", "Pretrained Cellpose model.",
                  enum = c("cyto3", "cyto2", "nuclei", "tissuenet", "livecell")),
    cytoplasm_channel = p_int(0L, "Cellpose cytoplasm channel (0 = grayscale).",
                              minimum = 0, maximum = 3, unit = "index"),
    nucleus_channel = p_int(1L, "Cellpose nucleus channel (0 = none).",
                            minimum = 0, maximum = 3, unit = "index"),
    diameter = p_num(NULL, "Expected cell diameter; null = estimated by Cellpose.",
                     exclusive_minimum = 0, unit = "px", nullable = TRUE),
    diameter_um = p_num(NULL, "Expected cell diameter in micrometres.",
                        exclusive_minimum = 0, unit = "um", nullable = TRUE,
                        calib = TRUE),
    flow_threshold = p_num(0.4, "Flow error threshold.", minimum = 0,
                           unit = "none"),
    cellprob_threshold = p_num(0, "Cell probability threshold (logit).",
                               minimum = -8, maximum = 8, unit = "none"),
    batch_size = p_int(8L, "Tiles per inference batch.", minimum = 1,
                       maximum = 256, unit = "count"),
    tile = p_bool(TRUE, "Tile large images inside Cellpose.")
  ),
  extensions = .sg_json_object()
)

mesmer_protocol <- list(
  schema = "segmantR-protocol-v1",
  id = "mesmer.2d.v1",
  version = "1.0.0",
  title = "Mesmer (DeepCell) whole-cell or nuclear segmentation (optional backend)",
  description = paste(
    "Delegates to sg_segment_mesmer() on a two-channel image built from",
    "nuclear_channel and membrane_channel. Unlike the direct function the",
    "protocol never assumes 0.5 um/px: the image must be calibrated or",
    "image_mpp must be given. Predictions are staged for review."
  ),
  family = "dnn",
  input_contract = list(
    array_order = "y,x,channel",
    inputs = list(image_input),
    channel = list(parameters = I(c("nuclear_channel", "membrane_channel")),
                   operation = "pair", min_channels = 2L),
    value_semantics = dnn_semantics,
    value_range = observed_range,
    calibration = list(required = "always", parameters = I("image_mpp")),
    min_shape_yx = I(c(16L, 16L))
  ),
  preprocess = list(normalization = list(method = "percentile",
                                         scope = "global", low = NULL,
                                         high = NULL, clip = FALSE,
                                         note = "Performed inside Mesmer."),
                    target_pixel_size_um = 0.5, resample = "backend"),
  method = list(backend = "python-deepcell", delegate = "sg_segment_mesmer",
                mapping = list(compartment = "compartment",
                               image_mpp = "image_mpp",
                               nuclear_channel = NULL,
                               membrane_channel = NULL)),
  postprocess = list(steps = list()),
  tiling = list(mode = "backend", tile_size = 512L, overlap = NULL,
                max_pixels = NULL,
                note = "Mesmer tiles internally (512 px tiles)."),
  output_contract = list(mask_type = "instance", dtype = "int32",
                         background = 0L, connectivity = NULL,
                         label_order = "backend", measurements = core_measure,
                         status = "staged"),
  runtime_profile = list(
    language = "R", requires_python = TRUE, python_modules = I("deepcell"),
    r_packages = I("reticulate"), gpu = "optional",
    install_hint = "Install the Python package 'deepcell' and make it visible to reticulate.",
    qupath = NULL
  ),
  seed_policy = dnn_seed,
  provenance_policy = list(record = I(c("protocol_digest", "parameters_digest",
                                        "input_digests", "runtime",
                                        "delegate_call", "mask_revision",
                                        "measurements_digest")),
                           hash = "sha256"),
  parameters = list(
    compartment = p_str("whole-cell", "Compartment to segment.",
                        enum = c("whole-cell", "nuclear")),
    nuclear_channel = p_int(1L, "1-based nuclear channel.", minimum = 1,
                            unit = "index"),
    membrane_channel = p_int(2L, "1-based membrane/cytoplasm channel.",
                             minimum = 1, unit = "index"),
    image_mpp = p_num(NULL, paste(
      "Pixel size in um; null = take it from the image resolution",
      "(required)."
    ), exclusive_minimum = 0, unit = "um", nullable = TRUE, calib = TRUE)
  ),
  extensions = .sg_json_object()
)

protocols <- list(
  threshold_protocol("otsu"), threshold_protocol("adaptive"),
  threshold_protocol("triangle"),
  watershed_protocol("distance"), watershed_protocol("h_minima"),
  propagate_protocol, cleanup_protocol,
  stardist_protocol, cellpose_protocol, mesmer_protocol
)

dir.create("inst/protocols", showWarnings = FALSE)
for (p in protocols) {
  path <- file.path("inst/protocols", paste0(p$id, ".json"))
  .sg_write_json(p, path)
  errs <- .sg_schema_errors(.sg_read_json(path), "protocol.schema.json",
                            normalise = FALSE)
  if (length(errs)) stop(p$id, ":\n", paste(errs, collapse = "\n"))
  cat("wrote", path, "\n")
}
