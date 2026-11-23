# segmantR: Cell Segmentation for Histology with Human-in-the-Loop Training

Cell segmentation for histology and multiplexed tissue imaging:
classical methods that run in R alone, optional deep learning backends
through 'reticulate', a human-in-the-loop correction and training
workflow, and reproducible exchange with 'QuPath' and partner packages.

## Where to start

- Images and masks:
  [`new_sg_image()`](https://cttir.github.io/segmantR/reference/new_sg_image.md),
  [`sg_read_image()`](https://cttir.github.io/segmantR/reference/sg_read_image.md),
  [`new_sg_mask()`](https://cttir.github.io/segmantR/reference/new_sg_mask.md),
  and the synthetic examples from
  [`sg_example_image()`](https://cttir.github.io/segmantR/reference/sg_example_image.md)
  and
  [`sg_example_mask()`](https://cttir.github.io/segmantR/reference/sg_example_mask.md).

- Segmentation:
  [`sg_segment_threshold()`](https://cttir.github.io/segmantR/reference/sg_segment_threshold.md),
  [`sg_segment_watershed()`](https://cttir.github.io/segmantR/reference/sg_segment_watershed.md)
  and
  [`sg_segment_propagate()`](https://cttir.github.io/segmantR/reference/sg_segment_propagate.md)
  need no Python;
  [`sg_segment_cellpose()`](https://cttir.github.io/segmantR/reference/sg_segment_cellpose.md),
  [`sg_segment_stardist()`](https://cttir.github.io/segmantR/reference/sg_segment_stardist.md)
  and
  [`sg_segment_mesmer()`](https://cttir.github.io/segmantR/reference/sg_segment_mesmer.md)
  use a Python environment selected with
  [`sg_setup_python()`](https://cttir.github.io/segmantR/reference/sg_setup_python.md).

- Measurement and evaluation:
  [`sg_extract_features()`](https://cttir.github.io/segmantR/reference/sg_extract_features.md),
  [`sg_evaluate_segmentation()`](https://cttir.github.io/segmantR/reference/sg_evaluate_segmentation.md).

- Figures:
  [`sg_plot_overlay()`](https://cttir.github.io/segmantR/reference/sg_plot_overlay.md),
  [`sg_plot_mask()`](https://cttir.github.io/segmantR/reference/sg_plot_mask.md),
  [`sg_plot_features()`](https://cttir.github.io/segmantR/reference/sg_plot_features.md),
  [`sg_plot_comparison()`](https://cttir.github.io/segmantR/reference/sg_plot_comparison.md),
  [`sg_plot_metrics()`](https://cttir.github.io/segmantR/reference/sg_plot_metrics.md).

- Reproducible runs and exchange:
  [`sg_protocol_run()`](https://cttir.github.io/segmantR/reference/sg_protocol_run.md),
  [`sg_export_interchange()`](https://cttir.github.io/segmantR/reference/sg_export_interchange.md),
  [`sg_import_interchange()`](https://cttir.github.io/segmantR/reference/sg_import_interchange.md),
  [`sg_export_qupath()`](https://cttir.github.io/segmantR/reference/sg_export_qupath.md).

- Interactive correction:
  [`sg_app()`](https://cttir.github.io/segmantR/reference/sg_app.md) and
  [`sg_run_app()`](https://cttir.github.io/segmantR/reference/sg_run_app.md).

See
[`vignette("segmantR")`](https://cttir.github.io/segmantR/articles/segmantR.md)
for a first workflow and
[`vignette("protocols-and-interop")`](https://cttir.github.io/segmantR/articles/protocols-and-interop.md)
for protocols and exchange formats.

## See also

Useful links:

- <https://github.com/CTTIR/segmantR>

- <https://cttir.github.io/segmantR/>

- Report bugs at <https://github.com/CTTIR/segmantR/issues>

## Author

**Maintainer**: R. Heller <raban.heller@uni-ulm.de>
([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

Authors:

- R. Heller <raban.heller@uni-ulm.de>
  ([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]
