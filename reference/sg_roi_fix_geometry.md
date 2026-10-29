# Repair the geometry of a project

Apply
[`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
to invalid ROIs (which also drops duplicate consecutive vertices) and
clamp out-of-bounds vertices into the image bounds, reporting what
changed.

## Usage

``` r
sg_roi_fix_geometry(project, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md).

- verbose:

  Logical; whether to report repairs. Default `TRUE`.

- call:

  The calling environment, for error reporting.

## Value

The
[sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md)
with repaired geometry. Repairs are reported via
[`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
when `verbose` is `TRUE`. Issues that cannot be repaired (zero area,
degenerate, `NA` coordinates) are left in place and reported.

## See also

[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_check_geometry.md)

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/reference/sg_roi_buffer.md),
[`sg_roi_check_containment()`](https://cttir.github.io/segmantR/reference/sg_roi_check_containment.md),
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_check_geometry.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/reference/sg_roi_clamp.md),
[`sg_roi_contains()`](https://cttir.github.io/segmantR/reference/sg_roi_contains.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/reference/sg_roi_distance.md),
[`sg_roi_flip_y()`](https://cttir.github.io/segmantR/reference/sg_roi_flip_y.md),
[`sg_roi_overlaps()`](https://cttir.github.io/segmantR/reference/sg_roi_overlaps.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/reference/sg_roi_ring.md),
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/reference/sg_roi_rois_overlap.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/reference/sg_roi_transform.md)

## Examples

``` r
# a rectangle reaching past the image edge is clamped into the image
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(-2, -2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
fixed <- sg_roi_fix_geometry(proj)
#> ✔ Repaired 1 ROI.
sg_roi_rois(fixed)$area_px
#> [1] 64
```
