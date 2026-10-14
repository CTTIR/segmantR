# segmantR

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21889962.svg)](https://doi.org/10.5281/zenodo.21889962)

segmantR segments microscopy images, records reproducible segmentation
protocols, and exchanges masks and measurements with downstream tools.
The core threshold and watershed workflows use R; optional external
engines require their own runtimes and model validation.

## Installation

``` r

install.packages("remotes")
remotes::install_github("CTTIR/segmantR", build_vignettes = TRUE)
```

See the declared R and package requirements in
[DESCRIPTION](https://cttir.github.io/segmantR/dev/DESCRIPTION).
Installing the R package does not install Python engines or download
models.

## Reproducible protocols and exchange

Besides the direct segmentation functions
([`sg_segment_threshold()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_threshold.md),
[`sg_segment_watershed()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_watershed.md),
[`sg_segment_propagate()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_propagate.md)
and the optional Cellpose, StarDist and Mesmer wrappers), segmantR
provides:

- **Versioned declarative protocols** (`segmantR-protocol-v1`):
  `threshold.otsu.v1`, `threshold.adaptive.v1`, `threshold.triangle.v1`,
  `watershed.distance.v1`, `watershed.h_minima.v1`,
  `propagate.voronoi.v1`, `postprocess.label-cleanup.v1` and the
  optional `stardist.2d.v1`, `cellpose.2d.v1`, `mesmer.2d.v1`.
  Parameters are whitelisted and every run records the exact delegate
  call.
- **A neutral interchange format** (`segmantR-interchange-v1`): JSON
  manifests, exact integer label TIFF, pixel-edge GeoJSON with stable
  object ids, measurement tables with explicit special values, and
  SHA-256 inventories. Imports are staged; reviewed masks are protected.
- **Training datasets and model bundles** with grouped, leakage-free
  splits, model cards, runtime descriptions and checksums.
- **QuPath programs**: readable Groovy templates driven by `run.json`
  for the Script Editor and `QuPath script`, and a StarDist parameter
  adapter.

``` r

library(segmantR)
img <- sg_example_image("fluorescence_nuclei")
run <- sg_protocol_run(img, "threshold.otsu.v1", min_area = 5L, output = "run")
bundle <- sg_export_interchange(run, tempfile("bundle"), image = img)
back <- sg_import_interchange(bundle$path, expected_digest = bundle$bundle_digest)
sg_mask_status(back$mask)$status  # "staged"
```

The core runs without Python, QuPath or EBImage; optional backends are
checked when used. Current capability status:

| Contract | Status |
|----|----|
| Neutral files and inventories (I0) | supported |
| Protocols and run envelopes (I1) | supported |
| Model bundles, training datasets | supported |
| QuPath programs, StarDist in QuPath | planned (headless runs verified with QuPath 0.7.0 and StarDist extension 0.6.0; no partner consumer yet) |
| Local control service | planned |

See
[`vignette("protocols-and-interop", package = "segmantR")`](https://cttir.github.io/segmantR/dev/articles/protocols-and-interop.md)
and `system.file("interop", "INTEROP.md", package = "segmantR")`.

## Citation

If you use this software, please cite it as:

> Heller, R. (2026). *segmantR: Cell segmentation of histology slides
> with human-in-the-loop training* (Version 0.1.0) \[Computer
> software\]. Zenodo. <https://doi.org/10.5281/zenodo.21889962>

DOI: [10.5281/zenodo.21889962](https://doi.org/10.5281/zenodo.21889962)

## Documentation and support

Start with the [protocols and interoperability
vignette](https://cttir.github.io/segmantR/dev/vignettes/protocols-and-interop.Rmd)
or
[`vignette("protocols-and-interop", package = "segmantR")`](https://cttir.github.io/segmantR/dev/articles/protocols-and-interop.md).
Use
[`help(package = "segmantR")`](https://cttir.github.io/segmantR/reference)
for the API and <https://github.com/CTTIR/segmantR/issues> for
reproducible bug reports. The package is MIT licensed; see
[LICENSE](https://cttir.github.io/segmantR/dev/LICENSE).
