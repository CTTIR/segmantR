# segmantR

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21889962.svg)](https://doi.org/10.5281/zenodo.21889962)

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

## Use of LLM tools

Portions of this package were prepared with assistance from large
language model tooling for narrowly defined, non-authorial tasks:
copyediting, prose smoothing, Markdown/LaTeX formatting, scaffolding of
boilerplate files (CI configs, build scripts), code refactoring. The
tools used were [Chat
AI](https://kisski.gwdg.de/leistungen/2-02-llm-service/), the LLM
service of KISSKI (GWDG), and a self-hosted **Mistral Small (24B,
Apache-2.0)** run locally via [Ollama](https://ollama.com/) and the
`ollamar` R package — local inference only, with no data sent to third
parties for the self-hosted model.

All scientific claims, methodological choices, analyses,
interpretations, and conclusions are the author’s own. No LLM-generated
text was incorporated without review and revision, and every reference
was verified against its DOI, arXiv ID, or ISBN.

## Citation

If you use this software, please cite it as:

> Heller, R. (2026). *segmantR: Cell segmentation of histology slides
> with human-in-the-loop training* (Version 0.1.0) \[Computer
> software\]. Zenodo. <https://doi.org/10.5281/zenodo.21889962>

DOI: [10.5281/zenodo.21889962](https://doi.org/10.5281/zenodo.21889962)
