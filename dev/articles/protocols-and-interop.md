# Standard protocols, DNN training and QuPath/StarDist exchange

``` r

library(segmantR)
#> segmantR v0.1.0.9000 -- Cell Segmentation with Human-in-the-Loop
#> Optional backends are checked when used; see sg_interchange_capabilities().
```

This vignette walks through the reproducible, exchangeable side of
segmantR: versioned segmentation protocols, the neutral interchange
format, training datasets and model bundles, and the QuPath/StarDist
adapter. Everything executed here runs in R alone; steps that need
Python or QuPath are shown but not run.

## 1. Standard protocols

Protocols are declarative JSON definitions with whitelisted parameters.

``` r

protocols <- sg_protocol_list()
protocols[, c("id", "version", "status", "backend")]
#> # A tibble: 10 × 4
#>    id                           version status   backend        
#>    <chr>                        <chr>   <chr>    <chr>          
#>  1 cellpose.2d.v1               1.0.0   optional python-cellpose
#>  2 mesmer.2d.v1                 1.0.0   optional python-deepcell
#>  3 postprocess.label-cleanup.v1 1.0.0   core     segmantR-core  
#>  4 propagate.voronoi.v1         1.0.0   core     segmantR-core  
#>  5 stardist.2d.v1               1.0.0   optional python-stardist
#>  6 threshold.adaptive.v1        1.0.0   core     segmantR-core  
#>  7 threshold.otsu.v1            1.0.0   core     segmantR-core  
#>  8 threshold.triangle.v1        1.0.0   core     segmantR-core  
#>  9 watershed.distance.v1        1.0.0   core     segmantR-core  
#> 10 watershed.h_minima.v1        1.0.0   core     segmantR-core
```

Each parameter has a type, bounds, unit and calibration requirement:

``` r

spec <- sg_protocol_schema("threshold.otsu.v1")
spec[!spec$name %in% c("band_a_nm", "band_b_nm", "band_min_nm",
                       "band_max_nm"),
     c("name", "type", "unit", "maps_to")]
#> # A tibble: 9 × 4
#>   name                    type    unit  maps_to              
#>   <chr>                   <chr>   <chr> <chr>                
#> 1 band_operation          string  none  <channel selection>  
#> 2 channel                 integer index <channel selection>  
#> 3 channel_name            string  name  <channel selection>  
#> 4 fill_holes              boolean none  morphology.fill_holes
#> 5 max_area                integer px2   max_area             
#> 6 min_area                integer px2   min_area             
#> 7 open_size               integer px    morphology.open      
#> 8 wavelength_nm           number  nm    <channel selection>  
#> 9 wavelength_tolerance_nm number  nm    <channel selection>
```

Running a protocol delegates to the direct function with a recorded
argument mapping. The run envelope makes declarative and direct runs
comparable:

``` r

img <- sg_example_image("fluorescence_nuclei")
run <- sg_protocol_run(img, "threshold.otsu.v1", min_area = 5L,
                       output = "run")
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
run
#> <sg_run> "threshold.otsu.v1" 1.0.0: succeeded
#> Objects: 8 (instance, draft)
#> Revision:
#> sha256:4060328284931abf3fc37d6c056992a3a4f02d50c09b1e4868a6bb6ef355e685
str(run$record$delegate$arguments)
#> List of 6
#>  $ channel   : int 1
#>  $ image     : chr "<input:image>"
#>  $ max_area  : int 5000
#>  $ method    : chr "otsu"
#>  $ min_area  : int 5
#>  $ morphology:List of 2
#>   ..$ fill_holes: logi TRUE
#>   ..$ open      : int 5
direct <- sg_segment_threshold(img, method = "otsu", min_area = 5L)
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
identical(direct$labels, run$mask$labels)
#> [1] TRUE
```

Invalid input is refused with classified conditions instead of being
guessed:

``` r

res <- sg_protocol_validate("threshold.otsu.v1", img, min_area = -1L,
                            error = FALSE)
res$error$code
#> [1] "PARAMETER_OUT_OF_RANGE"
try(sg_protocol_run(img, "mesmer.2d.v1"))
#> Error in .sg_check_inputs(p, inputs, params) : 
#>   "mesmer.2d.v1" needs at least 2 channels; the image has 1.
```

Post-processing is a protocol too:

``` r

clean <- sg_protocol_run(run$mask, "postprocess.label-cleanup.v1",
                         min_area = 40L, fill_holes = TRUE)
clean$n_cells
#> [1] 8
```

### Hyperspectral channels

Bands are selected by index, name, wavelength or a registered operation;
value semantics are declared, never inferred.

``` r

cube <- array(runif(32 * 32 * 3), dim = c(32, 32, 3))
hsi <- new_sg_image(cube, channels = c("b460", "b550", "b650"),
                    bands = data.frame(wavelength_nm = c(460, 550, 650)),
                    value_semantics = "reflectance")
nd <- sg_select_channel(hsi, band_operation = "normalized_difference",
                        band_a_nm = 650, band_b_nm = 550)
nd$provenance$band_selection[c("operation", "wavelength_nm")]
#> $operation
#> [1] "normalized_difference"
#> 
#> $wavelength_nm
#> [1] 650 550
```

Optional DNN protocols check their backend when they run and never fall
back to another method:

``` r

dnn <- sg_protocol_run(img, "stardist.2d.v1", output = "run")
dnn$record$status
#> [1] "unavailable"
```

## 2. Neutral interchange

A bundle contains an integer label TIFF, exact pixel-edge GeoJSON with
stable object ids, the legend, long-format measurements, a manifest and
a SHA-256 inventory.

``` r

dest <- file.path(tempdir(), "segmantR-bundle")
unlink(dest, recursive = TRUE)
bundle <- sg_export_interchange(run, dest, image = img)
list.files(dest)
#> [1] "integrity.json"   "manifest.json"    "mask.legend.json" "mask.tif"        
#> [5] "measurements.csv" "objects.geojson"
bundle$bundle_digest
#> [1] "sha256:fabf96d86935442920e41949935c52a74c525352cf6821b27e9e8266f587c215"
```

Imports verify integrity, schema, dtype, orientation, plane, legend and
the agreement between GeoJSON and TIFF, and return a **staged** mask:

``` r

imported <- sg_import_interchange(dest,
                                  expected_digest = bundle$bundle_digest)
imported$checks[, c("check", "status")]
#> # A tibble: 15 × 2
#>    check               status
#>    <chr>               <chr> 
#>  1 format              ok    
#>  2 integrity           ok    
#>  3 expected_digest     ok    
#>  4 manifest            ok    
#>  5 assets              ok    
#>  6 plane               ok    
#>  7 legend_sidecar      ok    
#>  8 mask_tiff           ok    
#>  9 mask_content_digest ok    
#> 10 geojson_features    ok    
#> 11 geojson_vs_tiff     ok    
#> 12 legend              ok    
#> 13 mask_contract       ok    
#> 14 mask_revision       ok    
#> 15 measurements        ok
sg_mask_status(imported$mask)$status
#> [1] "staged"
```

Reviewed masks are protected:

``` r

reviewed <- sg_review_mask(imported$mask,
                           expected_revision = sg_mask_revision(imported$mask))
candidate <- clean
try(sg_replace_mask(reviewed, candidate))
#> <sg_mask>: 64 x 64, 8 cells
#> Status: reviewed
replaced <- sg_replace_mask(reviewed, candidate,
                            expected_revision = sg_mask_revision(reviewed),
                            overwrite = TRUE)
sg_mask_status(replaced)$status
#> [1] "reviewed"
```

## 3. Training data, StarDist training and prediction

Dataset manifests tile image/mask pairs and split them by origin so
tiles of one subject never appear in two splits.

``` r

mask <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                          disconnected = "split")
pairs <- lapply(c("A", "B", "C"), function(s) {
  list(image = img, mask = mask, subject_id = s)
})
ts <- sg_prepare_training_data(pairs, tile_size = 32L,
                               split = c(train = 0.34, validation = 0.33,
                                         test = 0.33))
ts
#> <sg_training_set> dataset-59bd8753d8c7688e: 12 tiles (instance)
#> Splits: test=4, train=4, validation=4
sg_validate_training_manifest(ts$manifest, mask_type = "instance")$ok
#> [1] TRUE
```

A foreground/background mask is not accepted as instance training data:

``` r

binary <- new_sg_mask(ifelse(mask$labels > 0L, 1L, 0L))
try(sg_dataset_manifest(list(list(image = img, mask = binary,
                                  subject_id = "A")), tile_size = 32L))
#> Error in .sg_assert_training_mask(msk, mask_type, i) : 
#>   Pair 1: the mask looks like a foreground/background mask, not an
#> instance mask.
#> ✖ 1 instance label(s) consist of several disconnected parts (e.g. 1)
#> ℹ Instance training needs a unique positive id per object and background 0
#>   (split objects with sg_cleanup_labels(disconnected = 'split') after checking
#>   them).
```

Training needs the Python `stardist` and `tensorflow` modules; all data
checks run before Python is touched:

``` r

model <- sg_train_stardist(ts, n_epochs = 50L, save_path = "models",
                           model_card = list(
                             data_domain = "synthetic fluorescence nuclei",
                             limitations = "demonstration only",
                             license = list(id = "CC-BY-4.0")))
sg_package_model(model, "nuclei.segmantR")
loaded <- sg_load_model("nuclei.segmantR")   # checksums verified
pred <- sg_predict_model(loaded, img, output = "run")
sg_mask_status(pred$mask)$status              # "staged"
```

## 4. QuPath and StarDist

[`sg_stardist_parameter_map()`](https://cttir.github.io/segmantR/dev/reference/sg_stardist_parameter_map.md)
shows how every protocol parameter maps to the QuPath StarDist
extension, including what cannot be honoured:

``` r

map <- sg_stardist_parameter_map("stardist.2d.v1", "qupath",
                                 normalize_scope = "tile",
                                 normalize_low = 1, normalize_high = 99)
map[, c("parameter", "target_option", "status")]
#> # A tibble: 16 × 3
#>    parameter               target_option                 status        
#>    <chr>                   <chr>                         <chr>         
#>  1 channel                 channels                      mapped        
#>  2 channel_name            channels                      not_applicable
#>  3 wavelength_nm           channels                      not_applicable
#>  4 wavelength_tolerance_nm <export>                      runner        
#>  5 model                   StarDist2D.builder(modelPath) not_applicable
#>  6 prob_thresh             threshold                     mapped        
#>  7 nms_thresh              NA                            approximated  
#>  8 normalize_low           normalizePercentiles          mapped        
#>  9 normalize_high          normalizePercentiles          mapped        
#> 10 normalize_scope         <builder choice>              mapped        
#> 11 pixel_size_um           pixelSize                     mapped        
#> 12 tile_size               tileSize                      mapped        
#> 13 include_probability     includeProbability            mapped        
#> 14 cell_expansion_um       cellExpansion                 mapped        
#> 15 create_annotations      createAnnotations             mapped        
#> 16 classification          classify                      mapped
```

A QuPath program contains `run.json`, the Groovy templates and hashed
resources. segmantR never starts QuPath itself.

``` r

calibrated <- img
calibrated$resolution <- list(x_um = 0.5, y_um = 0.5)
prog <- sg_export_qupath(run$mask, file.path(tempdir(), "qupath-import"),
                         image = calibrated, image_name = "nuclei.tif",
                         save_policy = "project", overwrite = TRUE)
prog$commands
#> $import
#> [1] "QuPath script --project=<project.qpproj> --image=\"nuclei.tif\" --args=run.json --save segmantR_import.groovy"
#> 
#> $export
#> [1] "QuPath script --project=<project.qpproj> --image=\"nuclei.tif\" --args=run_export.json segmantR_export.groovy"
```

For StarDist in QuPath, pass a model file (`.pb`, SavedModel or
bioimage.io) and an image describing the binding, then run the template
headless or from the Script Editor and import the results:

``` r

sd <- sg_export_qupath("stardist.2d.v1", "qupath-stardist",
                       image = calibrated, image_name = "nuclei.tif",
                       model = "dsb2018_heavy_augment.pb",
                       normalize_scope = "tile", normalize_low = 1,
                       normalize_high = 99, pixel_size_um = 0.5,
                       save_policy = "project")
# In a shell, from qupath-stardist/:
#   QuPath script --project=project.qpproj --image="nuclei.tif" \
#     --args=run.json --save segmantR_stardist.groovy
back <- sg_import_qupath("qupath-stardist/out", image = calibrated,
                         expected_run_id = sd$run$run_id)
back$qupath$agreement
```

## 5. Capabilities

``` r

caps <- sg_interchange_capabilities()
vapply(caps$profiles, function(p) p$status, character(1))
#>               I0               I1              app          control 
#>      "supported"      "supported"        "planned"        "planned" 
#>         datasets           models partner_annotatR partner_qupflowR 
#>      "supported"      "supported"        "planned"        "planned" 
#>  qupath_programs  stardist_python  stardist_qupath 
#>        "planned"    "unavailable"        "planned"
```

See `system.file("interop", "INTEROP.md", package = "segmantR")` for the
full contract, migration notes and security boundaries.
