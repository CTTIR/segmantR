# Stack per-layer masks into a 3D array

Stack per-layer masks into a 3D array

## Usage

``` r
sg_roi_mask_stack(
  project,
  layers = NULL,
  level = 0L,
  call = rlang::caller_env()
)
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- layers:

  Optional layer name(s) to include; all by default.

- level:

  Integer pyramid level. Default `0`.

- call:

  The calling environment, for error reporting.

## Value

A 3D integer array `[y, x, layer]`, one multi-class plane per layer; the
third dimension is named by layer.

## See also

Other masks:
[`sg_roi_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask.md),
[`sg_roi_mask_boundary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_boundary.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stats.md)
