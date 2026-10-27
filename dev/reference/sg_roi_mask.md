# Rasterise ROIs to a mask ("Schablone")

Produce a binary, labelled, or multi-class integer mask from
annotations. This is the package's core output artifact.

## Usage

``` r
sg_roi_mask(
  x,
  type = c("binary", "labelled", "multiclass"),
  layer = NULL,
  label = NULL,
  level = 0L,
  background = 0L,
  touches = FALSE,
  dims = NULL,
  values = NULL,
  overlap = c("last", "first", "max", "min", "error", "bitor"),
  engine = c("stars", "terra"),
  call = rlang::caller_env()
)
```

## Arguments

- x:

  An [sg_roi](https://cttir.github.io/segmantR/dev/reference/sg_roi.md),
  [sg_roi_layer](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer.md),
  or
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- type:

  `"binary"` (a logical matrix), `"labelled"` (one integer id per ROI),
  or `"multiclass"` (one id per label class).

- layer:

  Optional layer name(s) to restrict to (projects only).

- label:

  Optional label(s) to restrict to.

- level:

  Integer pyramid level at which to rasterise. Default `0`.

- background:

  Integer background value. Default `0`.

- touches:

  Logical; see the coverage contract. Default `FALSE`.

- dims:

  Optional `c(width, height)`; taken from the image (projects) or the
  geometry bounding box otherwise.

- values:

  Optional named integer vector mapping labels to explicit class codes
  (e.g. `c(specular = 1L, blood = 2L, shadow = 4L)`), used only for
  `type = "multiclass"`. When `NULL` (default) codes follow first-seen
  label order. Supply power-of-two codes together with
  `overlap = "bitor"` to build a bitfield mask.

- overlap:

  How overlapping ROIs resolve: `"last"` (later z-order wins, the
  default), `"first"`, `"max"`, `"min"`, `"error"` (abort on any
  overlap), or `"bitor"` (bitwise-OR the overlapping values, for
  bitfield masks; use with power-of-two `values` and `background = 0`).

- engine:

  `"stars"` (reference) or `"terra"` (accelerated, if installed); the
  two produce identical masks.

- call:

  The calling environment, for error reporting.

## Value

An `sg_roi_mask`: a matrix (logical for `"binary"`, otherwise integer)
with attributes `legend` (a tibble with columns `value`, `label`,
`layer`, `roi_id`, `n_px`, `colour`), `level`, `dims`, `type`, and
`created`. An all-background mask of the correct dimensions is returned
when there are no ROIs.

## Details

**Pixel-coverage contract.** Pixel `(i, j)` covers the half-open square
`[j-1, j) x [i-1, i)` with `(0, 0)` at the top-left corner of the
top-left pixel; its centre is `(j - 0.5, i - 0.5)`. With
`touches = FALSE` (default) a pixel is included when its centre lies
inside the polygon; with `touches = TRUE` a pixel is included if the
polygon touches it at all. ROI coordinates use the image convention
(top-left origin, y down).

## See also

[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stats.md)

Other masks:
[`sg_roi_mask_boundary()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_boundary.md),
[`sg_roi_mask_derive()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_derive.md),
[`sg_roi_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_legend.md),
[`sg_roi_mask_preview()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_preview.md),
[`sg_roi_mask_stack()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stack.md),
[`sg_roi_mask_stats()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_mask_stats.md)

## Examples

``` r
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), sg_roi_layer_add(sg_roi_layer("tissue"), sg_roi_rect(2, 2, 8, 8, "tissue")))
m <- sg_roi_mask(proj, type = "multiclass")
table(as.integer(m))
#> 
#>   0   1 
#> 364  36 
```
