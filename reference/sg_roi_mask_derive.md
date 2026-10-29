# Derive a training mask from layer masks

Combine rasterised layer masks into the derived training mask
`state WHERE anatomy == keep_label AND artefact == 0 AND state != background`.
This is the cross-layer operation the four-layer HSI scheme relies on:
it keeps a state (class) label only where the anatomy layer marks the
region of interest, no artefact bit is set, and the state is actually
labelled.

## Usage

``` r
sg_roi_mask_derive(
  state,
  anatomy,
  artefact = NULL,
  keep_label = "wound",
  background = 0L,
  call = rlang::caller_env()
)
```

## Arguments

- state:

  An `sg_roi_mask` of state (class) codes.

- anatomy:

  An `sg_roi_mask` of anatomy codes, sharing `state`'s dimensions and
  level.

- artefact:

  Optional `sg_roi_mask` (bitfield); pixels with any artefact bit set
  are dropped. `NULL` (default) applies no artefact exclusion.

- keep_label:

  The anatomy label whose region is kept (e.g. `"wound"`).

- background:

  Integer background/unlabelled value. Default `0`.

- call:

  The calling environment, for error reporting.

## Value

An `sg_roi_mask` (multiclass) of the surviving state codes, with the
state legend restricted to those classes and pixel counts recomputed.

## See also

[`sg_roi_mask()`](https://cttir.github.io/segmantR/reference/sg_roi_mask.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stack.md)

Other masks:
[`sg_roi_mask()`](https://cttir.github.io/segmantR/reference/sg_roi_mask.md),
[`sg_roi_mask_boundary()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_boundary.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stack.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/reference/sg_roi_mask_stats.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
# A single-layer project derives trivially; the four-layer HSI workflow passes
# separate anatomy/state/artefact masks. See the masks vignette.
m <- sg_roi_mask(proj, "multiclass")
sg_roi_mask_derive(m, m, keep_label = sg_roi_mask_legend(m)$label[1])
#> <sg_roi_mask> multiclass  |  20 x 20 px  |  level 0
#> values: 1
#> # A tibble: 1 × 6
#>   value label  layer  roi_id  n_px colour 
#>   <int> <chr>  <chr>  <chr>  <int> <chr>  
#> 1     1 tissue tissue NA        36 #999999
```
