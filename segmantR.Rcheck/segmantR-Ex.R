pkgname <- "segmantR"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
options(pager = "console")
library('segmantR')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("new_sg_image")
### * new_sg_image

flush(stderr()); flush(stdout())

### Name: new_sg_image
### Title: Create a new sg_image object
### Aliases: new_sg_image

### ** Examples

pixels <- matrix(runif(100), nrow = 10, ncol = 10)
img <- new_sg_image(pixels)
print(img)



cleanEx()
nameEx("new_sg_mask")
### * new_sg_mask

flush(stderr()); flush(stdout())

### Name: new_sg_mask
### Title: Create a new sg_mask object
### Aliases: new_sg_mask

### ** Examples

labels <- matrix(c(0L, 0L, 1L, 1L, 0L, 2L, 2L, 0L, 0L), nrow = 3)
mask <- new_sg_mask(labels)
print(mask)



cleanEx()
nameEx("new_sg_trained_model")
### * new_sg_trained_model

flush(stderr()); flush(stdout())

### Name: new_sg_trained_model
### Title: Create a new sg_trained_model object
### Aliases: new_sg_trained_model

### ** Examples

mdl <- new_sg_trained_model(
  model_path = tempdir(),
  backend = "cellpose",
  base_model = "cyto3",
  training_metrics = list(n_epochs = 100L, final_loss = 0.05)
)
print(mdl)



cleanEx()
nameEx("sg_active_learning_loop")
### * sg_active_learning_loop

flush(stderr()); flush(stdout())

### Name: sg_active_learning_loop
### Title: Run an active learning loop for iterative segmentation
###   refinement
### Aliases: sg_active_learning_loop

### ** Examples




cleanEx()
nameEx("sg_apply_corrections")
### * sg_apply_corrections

flush(stderr()); flush(stdout())

### Name: sg_apply_corrections
### Title: Apply manual corrections to a segmentation mask
### Aliases: sg_apply_corrections

### ** Examples

labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
corrected <- sg_apply_corrections(mask, list(
  list(action = "delete", cell_id = 2L)
))
print(corrected)



cleanEx()
nameEx("sg_create_annotation_task")
### * sg_create_annotation_task

flush(stderr()); flush(stdout())

### Name: sg_create_annotation_task
### Title: Create an annotation task for human review
### Aliases: sg_create_annotation_task

### ** Examples

pixels <- matrix(runif(100 * 100), nrow = 100, ncol = 100)
img <- new_sg_image(pixels)
task <- sg_create_annotation_task(img, n_patches = 4L, patch_size = 32L)
print(task)



cleanEx()
nameEx("sg_evaluate_segmentation")
### * sg_evaluate_segmentation

flush(stderr()); flush(stdout())

### Name: sg_evaluate_segmentation
### Title: Evaluate segmentation quality
### Aliases: sg_evaluate_segmentation

### ** Examples

pred_labels <- matrix(0L, nrow = 20, ncol = 20)
pred_labels[3:8, 3:8] <- 1L
pred_labels[12:18, 12:18] <- 2L
gt_labels <- matrix(0L, nrow = 20, ncol = 20)
gt_labels[3:9, 3:9] <- 1L
gt_labels[12:17, 12:17] <- 2L
pred <- new_sg_mask(pred_labels)
gt <- new_sg_mask(gt_labels)
result <- sg_evaluate_segmentation(pred, gt)
print(result)



cleanEx()
nameEx("sg_example_image")
### * sg_example_image

flush(stderr()); flush(stdout())

### Name: sg_example_image
### Title: Load a bundled example image
### Aliases: sg_example_image

### ** Examples

img <- sg_example_image("he_breast")
print(img)



cleanEx()
nameEx("sg_example_mask")
### * sg_example_mask

flush(stderr()); flush(stdout())

### Name: sg_example_mask
### Title: Load a bundled example mask
### Aliases: sg_example_mask

### ** Examples

mask <- sg_example_mask("he_breast")
print(mask)



cleanEx()
nameEx("sg_export_mask")
### * sg_export_mask

flush(stderr()); flush(stdout())

### Name: sg_export_mask
### Title: Export mask to file
### Aliases: sg_export_mask

### ** Examples




cleanEx()
nameEx("sg_extract_features")
### * sg_extract_features

flush(stderr()); flush(stdout())

### Name: sg_extract_features
### Title: Extract per-cell features from an image and mask
### Aliases: sg_extract_features

### ** Examples

pixels <- array(runif(20 * 20 * 2), dim = c(20, 20, 2))
img <- new_sg_image(pixels, channels = c("DAPI", "CD3"))
labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
feats <- sg_extract_features(img, mask, features = c("intensity", "morphology"))
print(feats)



cleanEx()
nameEx("sg_filter_cells")
### * sg_filter_cells

flush(stderr()); flush(stdout())

### Name: sg_filter_cells
### Title: Filter cells by morphological criteria
### Aliases: sg_filter_cells

### ** Examples

labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
filtered <- sg_filter_cells(mask, min_area = 10L, max_area = 100L)
print(filtered)



cleanEx()
nameEx("sg_load_model")
### * sg_load_model

flush(stderr()); flush(stdout())

### Name: sg_load_model
### Title: Load a packaged segmantR model
### Aliases: sg_load_model

### ** Examples




cleanEx()
nameEx("sg_mask_to_polygons")
### * sg_mask_to_polygons

flush(stderr()); flush(stdout())

### Name: sg_mask_to_polygons
### Title: Convert mask to polygon geometries
### Aliases: sg_mask_to_polygons

### ** Examples

labels <- matrix(0L, nrow = 20, ncol = 20)
labels[3:8, 3:8] <- 1L
labels[12:18, 12:18] <- 2L
mask <- new_sg_mask(labels)
polys <- sg_mask_to_polygons(mask, simplify = FALSE)
head(polys)



cleanEx()
nameEx("sg_merge_masks")
### * sg_merge_masks

flush(stderr()); flush(stdout())

### Name: sg_merge_masks
### Title: Merge nuclear and cell body masks
### Aliases: sg_merge_masks

### ** Examples

nuc_labels <- matrix(0L, nrow = 20, ncol = 20)
nuc_labels[5:7, 5:7] <- 1L
nuc_labels[14:16, 14:16] <- 2L
cell_labels <- matrix(0L, nrow = 20, ncol = 20)
cell_labels[3:9, 3:9] <- 1L
cell_labels[12:18, 12:18] <- 2L
nuc_mask <- new_sg_mask(nuc_labels)
cell_mask <- new_sg_mask(cell_labels)
merged <- sg_merge_masks(nuc_mask, cell_mask)
print(merged$nuclear)



cleanEx()
nameEx("sg_model_card")
### * sg_model_card

flush(stderr()); flush(stdout())

### Name: sg_model_card
### Title: Display a formatted model card
### Aliases: sg_model_card

### ** Examples

mdl <- new_sg_trained_model(
  model_path = tempdir(),
  backend = "cellpose",
  base_model = "cyto3",
  training_metrics = list(n_epochs = 100L),
  model_card = list(author = "Test User", tissue = "lung")
)
sg_model_card(mdl)



cleanEx()
nameEx("sg_package_model")
### * sg_package_model

flush(stderr()); flush(stdout())

### Name: sg_package_model
### Title: Package a trained model for sharing
### Aliases: sg_package_model

### ** Examples




cleanEx()
nameEx("sg_plot_comparison")
### * sg_plot_comparison

flush(stderr()); flush(stdout())

### Name: sg_plot_comparison
### Title: Side-by-side comparison of two masks
### Aliases: sg_plot_comparison

### ** Examples

m1 <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2, 2))
m2 <- new_sg_mask(matrix(c(0L, 0L, 1L, 1L), 2, 2))
p <- sg_plot_comparison(m1, m2)
p



cleanEx()
nameEx("sg_plot_features")
### * sg_plot_features

flush(stderr()); flush(stdout())

### Name: sg_plot_features
### Title: Scatter plot of cell features
### Aliases: sg_plot_features

### ** Examples

feat <- data.frame(
  cell_id = 1:10,
  area = rpois(10, 200),
  mean_intensity = runif(10)
)
p <- sg_plot_features(feat, x = "area", y = "mean_intensity")
p



cleanEx()
nameEx("sg_plot_mask")
### * sg_plot_mask

flush(stderr()); flush(stdout())

### Name: sg_plot_mask
### Title: Render a mask as a coloured image
### Aliases: sg_plot_mask

### ** Examples

labels <- matrix(c(0L, 1L, 1L, 2L, 2L, 0L, 3L, 3L, 0L), 3, 3)
mask <- new_sg_mask(labels)
p <- sg_plot_mask(mask)
p



cleanEx()
nameEx("sg_plot_metrics")
### * sg_plot_metrics

flush(stderr()); flush(stdout())

### Name: sg_plot_metrics
### Title: Bar chart of evaluation metrics
### Aliases: sg_plot_metrics

### ** Examples

res <- data.frame(
  metric = c("IoU", "Precision", "Recall", "F1"),
  value = c(0.82, 0.90, 0.85, 0.87)
)
p <- sg_plot_metrics(res)
p



cleanEx()
nameEx("sg_plot_overlay")
### * sg_plot_overlay

flush(stderr()); flush(stdout())

### Name: sg_plot_overlay
### Title: Overlay cell boundaries on an image
### Aliases: sg_plot_overlay

### ** Examples

img <- new_sg_image(matrix(runif(400), 20, 20))
p <- sg_plot_overlay(img)
p



cleanEx()
nameEx("sg_preprocess")
### * sg_preprocess

flush(stderr()); flush(stdout())

### Name: sg_preprocess
### Title: Preprocess an image
### Aliases: sg_preprocess

### ** Examples

pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
img2 <- sg_preprocess(img)
img3 <- sg_preprocess(img, contrast = "stretch", denoise = TRUE)



cleanEx()
nameEx("sg_read_image")
### * sg_read_image

flush(stderr()); flush(stdout())

### Name: sg_read_image
### Title: Read an image file
### Aliases: sg_read_image

### ** Examples




cleanEx()
nameEx("sg_run_app")
### * sg_run_app

flush(stderr()); flush(stdout())

### Name: sg_run_app
### Title: Launch the segmantR Shiny application
### Aliases: sg_run_app

### ** Examples




cleanEx()
nameEx("sg_segment_cellpose")
### * sg_segment_cellpose

flush(stderr()); flush(stdout())

### Name: sg_segment_cellpose
### Title: Cellpose cell segmentation
### Aliases: sg_segment_cellpose

### ** Examples




cleanEx()
nameEx("sg_segment_mesmer")
### * sg_segment_mesmer

flush(stderr()); flush(stdout())

### Name: sg_segment_mesmer
### Title: Mesmer (DeepCell) cell segmentation
### Aliases: sg_segment_mesmer

### ** Examples




cleanEx()
nameEx("sg_segment_propagate")
### * sg_segment_propagate

flush(stderr()); flush(stdout())

### Name: sg_segment_propagate
### Title: Voronoi propagation from nuclear seeds
### Aliases: sg_segment_propagate

### ** Examples

set.seed(42)
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
seeds <- matrix(0L, nrow = 20, ncol = 20)
seeds[5, 5] <- 1L
seeds[15, 15] <- 2L
nuc_mask <- new_sg_mask(seeds)
result <- sg_segment_propagate(img, nuclear_mask = nuc_mask)
print(result)



cleanEx()
nameEx("sg_segment_stardist")
### * sg_segment_stardist

flush(stderr()); flush(stdout())

### Name: sg_segment_stardist
### Title: StarDist cell segmentation
### Aliases: sg_segment_stardist

### ** Examples




cleanEx()
nameEx("sg_segment_threshold")
### * sg_segment_threshold

flush(stderr()); flush(stdout())

### Name: sg_segment_threshold
### Title: Threshold-based cell segmentation
### Aliases: sg_segment_threshold

### ** Examples

set.seed(42)
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
mask <- sg_segment_threshold(img, method = "otsu")
print(mask)



cleanEx()
nameEx("sg_segment_watershed")
### * sg_segment_watershed

flush(stderr()); flush(stdout())

### Name: sg_segment_watershed
### Title: Marker-controlled watershed segmentation
### Aliases: sg_segment_watershed

### ** Examples

set.seed(42)
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
mask <- sg_segment_watershed(img, seed_method = "distance", h = 0.3)
print(mask)



cleanEx()
nameEx("sg_setup_python")
### * sg_setup_python

flush(stderr()); flush(stdout())

### Name: sg_setup_python
### Title: Set up a Python environment for deep learning backends
### Aliases: sg_setup_python

### ** Examples




cleanEx()
nameEx("sg_stain_deconvolve")
### * sg_stain_deconvolve

flush(stderr()); flush(stdout())

### Name: sg_stain_deconvolve
### Title: Separate H&E stain channels by colour deconvolution
### Aliases: sg_stain_deconvolve

### ** Examples




cleanEx()
nameEx("sg_train_cellpose")
### * sg_train_cellpose

flush(stderr()); flush(stdout())

### Name: sg_train_cellpose
### Title: Fine-tune a Cellpose model on user-corrected masks
### Aliases: sg_train_cellpose

### ** Examples




### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
