# Get started with segmantR

![segmantR logo](figures/logo.svg)![segmantR
logo](figures/logo-dark.svg)

``` r

library(segmantR)
#> segmantR v0.3.0 -- Cell Segmentation with Human-in-the-Loop
#> Optional backends are checked when used; see sg_interchange_capabilities().
```

This vignette segments a small synthetic fluorescence image, measures
the cells, compares the result with a reference mask and draws the
standard figures. Everything here runs in R alone: no Python, QuPath or
Bioconductor package is needed. The deep learning backends, protocols
and exchange formats are covered in
[`vignette("protocols-and-interop")`](https://cttir.github.io/segmantR/articles/protocols-and-interop.md).

## Images and masks

An `sg_image` holds pixels as a `[row, column, channel]` array with
channel names; an `sg_mask` holds an integer label matrix in which 0 is
background and every positive value is one cell.
[`sg_read_image()`](https://cttir.github.io/segmantR/reference/sg_read_image.md)
reads image files; here the built-in synthetic example is used.

``` r

img <- sg_example_image("fluorescence_nuclei")
img
#> <sg_image>: 64 x 64 (1 channel)
reference <- sg_example_mask("fluorescence_nuclei")
reference
#> <sg_mask>: 64 x 64, 15 cells
#> Method: synthetic
```

[`sg_plot_overlay()`](https://cttir.github.io/segmantR/reference/sg_plot_overlay.md)
draws one channel with the cell outlines of a mask:

``` r

sg_plot_overlay(img, reference)
```

![Greyscale synthetic fluorescence image of 15 bright nuclei on a dark
background, each outlined in magenta along its pixel
edges.](segmantR_files/figure-html/overlay-1.png)

## Segment

Otsu thresholding followed by connected-component labelling is the
simplest method. `min_area` and `max_area` are in pixels.

``` r

otsu <- sg_segment_threshold(img, method = "otsu", min_area = 5)
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
otsu
#> <sg_mask>: 64 x 64, 8 cells
#> Method: threshold:otsu
```

Touching nuclei merge under a global threshold. A watershed seeded at
the intensity peaks (`seed_method = "h_minima"`, with `h` as the minimum
peak height) separates some of them:

``` r

ws <- sg_segment_watershed(img, seed_method = "h_minima", h = 0.1,
                           expand_pixels = 0)
#> ℹ Generated 10 seeds via "h_minima".
#> ✔ Watershed segmented 10 objects.
ws
#> <sg_mask>: 64 x 64, 10 cells
#> Method: watershed
```

``` r

sg_plot_comparison(otsu, ws, labels = c("Otsu threshold", "Watershed"))
```

![Two label masks side by side on a dark background: the Otsu threshold
result on the left and the watershed result on the right, cells coloured
by label.](segmantR_files/figure-html/comparison-1.png)

## Measure

[`sg_extract_features()`](https://cttir.github.io/segmantR/reference/sg_extract_features.md)
returns one row per cell. Intensity columns are named after the channel,
here `DAPI`.

``` r

feat <- sg_extract_features(img, otsu,
                            features = c("intensity", "morphology"))
#> ✔ Extracted intensity, morphology features for 8 cells.
feat[, c("cell_id", "DAPI_mean", "area", "circularity")]
#> # A tibble: 8 × 4
#>   cell_id DAPI_mean  area circularity
#>     <int>     <dbl> <int>       <dbl>
#> 1       1     0.698   122       1    
#> 2       2     0.772   105       1    
#> 3       3     0.721   128       0.513
#> 4       4     0.672    55       0.882
#> 5       5     0.752    77       1    
#> 6       6     0.800   134       0.870
#> 7       7     0.764    85       0.924
#> 8       8     0.952   139       1
```

``` r

sg_plot_features(feat, x = "area", y = "DAPI_mean", color = "circularity")
```

![Scatter plot of mean DAPI intensity against cell area in pixels for
the segmented cells, points coloured by
circularity.](segmantR_files/figure-html/features-1.png)

Any measured feature can be mapped back onto the mask:

``` r

sg_plot_mask(otsu, color_by = "area", features = feat)
```

![Label mask in which every segmented cell is filled with a colour for
its area, from dark purple for small cells to yellow for large
cells.](segmantR_files/figure-html/mask-area-1.png)

## Evaluate

[`sg_evaluate_segmentation()`](https://cttir.github.io/segmantR/reference/sg_evaluate_segmentation.md)
compares a predicted mask with a reference: pixel overlap (Dice,
Jaccard), the aggregated Jaccard index, panoptic quality, and detection
scores at IoU thresholds of 0.5 and 0.75.

``` r

metrics <- sg_evaluate_segmentation(otsu, reference)
#> ✔ Computed 7 segmentation metrics.
metrics
#> <sg_eval> — Segmentation Evaluation
#> ────────────────────────────────────────────────────────────────────────────────
#> dice: 0.969
#> jaccard: 0.9399
#> aji: 0.4793
#> panoptic_quality: 0.5492
#> ap50: 0.5333
#> ap75: 0.2778
#> f1_detection: 0.6957
#> ────────────────────────────────────────────────────────────────────────────────
```

``` r

sg_plot_metrics(metrics)
```

![Horizontal bar chart of seven segmentation metrics between 0 and 1 for
the Otsu result, sorted by
value.](segmantR_files/figure-html/metrics-1.png)

The pixel overlap is high, but the instance scores show that several
reference nuclei were merged. The watershed result can be scored in the
same way:

``` r

sg_evaluate_segmentation(ws, reference,
                         metrics = c("aji", "f1_detection"))
#> ✔ Computed 2 segmentation metrics.
#> <sg_eval> — Segmentation Evaluation
#> 
#> ────────────────────────────────────────────────────────────────────────────────
#> 
#> aji: 0.5362
#> 
#> f1_detection: 0.72
#> 
#> ────────────────────────────────────────────────────────────────────────────────
```

## Clean up and export

[`sg_filter_cells()`](https://cttir.github.io/segmantR/reference/sg_filter_cells.md)
removes implausible objects, and
[`sg_export_mask()`](https://cttir.github.io/segmantR/reference/sg_export_mask.md)
writes a mask as a label image (TIFF, PNG), as polygons (GeoJSON,
QuPath) or as a table (CSV).

``` r

kept <- sg_filter_cells(otsu, min_area = 20, max_area = 400,
                        min_circularity = 0.2)
#> ✔ Kept 7 of 8 cells.
#> ℹ Removed 1 cell by morphological filtering.
kept
#> <sg_mask>: 64 x 64, 7 cells
#> Method: threshold:otsu
```

## Where next

- [`sg_run_app()`](https://cttir.github.io/segmantR/reference/sg_run_app.md)
  opens the Shiny application for interactive correction.
- [`sg_segment_cellpose()`](https://cttir.github.io/segmantR/reference/sg_segment_cellpose.md),
  [`sg_segment_stardist()`](https://cttir.github.io/segmantR/reference/sg_segment_stardist.md)
  and
  [`sg_segment_mesmer()`](https://cttir.github.io/segmantR/reference/sg_segment_mesmer.md)
  use a Python environment chosen with
  [`sg_setup_python()`](https://cttir.github.io/segmantR/reference/sg_setup_python.md);
  see “Selecting Python” in
  [`?sg_setup_python`](https://cttir.github.io/segmantR/reference/sg_setup_python.md).
- [`vignette("protocols-and-interop")`](https://cttir.github.io/segmantR/articles/protocols-and-interop.md)
  covers versioned protocols, the neutral interchange format, model
  bundles and QuPath.
