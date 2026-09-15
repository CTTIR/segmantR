# Run a declarative segmentation protocol

Validates the protocol, the parameters and the inputs, delegates to the
corresponding direct function
([`sg_segment_threshold()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_threshold.md),
[`sg_segment_watershed()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_watershed.md),
[`sg_segment_propagate()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_propagate.md),
[`sg_cleanup_labels()`](https://cttir.github.io/segmantR/dev/reference/sg_cleanup_labels.md),
[`sg_segment_stardist()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_stardist.md),
[`sg_segment_cellpose()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_cellpose.md),
[`sg_segment_mesmer()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_mesmer.md))
with an explicit, recorded argument mapping, and returns the mask or a
run envelope.

## Usage

``` r
sg_protocol_run(image, protocol, ..., output = c("mask", "run"))
```

## Arguments

- image:

  The primary input: an `sg_image`, or an `sg_mask` for mask-input
  protocols such as `postprocess.label-cleanup.v1`.

- protocol:

  Protocol id, `sg_protocol`, named list, JSON text or `.json` file
  path.

- ...:

  Parameter overrides (for example `min_area = 20L`) and additional
  declared inputs (for example `seeds = nuclei_mask` for
  `propagate.voronoi.v1`, `model = trained_model`). Unknown names are
  errors.

- output:

  `"mask"` (default) returns the `sg_mask`; `"run"` returns an `sg_run`
  with `mask`, `measurements` and a schema-valid `record`.

## Value

An `sg_mask` or an `sg_run`.

## Details

Core protocols run without Python. Optional DNN protocols check their
backend first; when it is missing, `output = "mask"` signals an
`sg_capability_error` and `output = "run"` returns a run with
`status = "unavailable"`. There is never a silent fallback to another
method. DNN predictions are returned as staged masks.

## See also

[`sg_protocol_list()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_list.md),
[`sg_protocol_schema()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_schema.md),
[`sg_protocol_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_protocol_validate.md),
[`sg_export_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_export_interchange.md)

## Examples

``` r
img <- sg_example_image("fluorescence_nuclei")
mask <- sg_protocol_run(img, "threshold.otsu.v1", min_area = 5L)
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
run <- sg_protocol_run(img, "threshold.otsu.v1", min_area = 5L,
                       output = "run")
#> ℹ Threshold applied using "otsu" method.
#> ✔ Segmented 8 objects via threshold (otsu).
run$record$delegate$arguments
#> $channel
#> [1] 1
#> 
#> $image
#> [1] "<input:image>"
#> 
#> $max_area
#> [1] 5000
#> 
#> $method
#> [1] "otsu"
#> 
#> $min_area
#> [1] 5
#> 
#> $morphology
#> $morphology$fill_holes
#> [1] TRUE
#> 
#> $morphology$open
#> [1] 5
#> 
#> 
identical(mask$labels, run$mask$labels)
#> [1] TRUE
```
