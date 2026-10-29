# Check the geometry of every ROI in a project

Check the geometry of every ROI in a project

## Usage

``` r
sg_roi_check_geometry(project, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md).

- call:

  The calling environment, for error reporting.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `roi_id` (character), `issue` (character), `severity`
(character, `"error"`/`"warning"`), and `fixable` (logical). Detected
issues: self-intersection, invalid geometry, zero area, degenerate
rings, out-of-bounds vertices, duplicate consecutive vertices, ring
orientation, and `NA` coordinates. A 0-row tibble when all geometry is
valid.

## See also

[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_fix_geometry.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/reference/sg_roi_validate.md)

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/reference/sg_roi_buffer.md),
[`sg_roi_check_containment()`](https://cttir.github.io/segmantR/reference/sg_roi_check_containment.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/reference/sg_roi_clamp.md),
[`sg_roi_contains()`](https://cttir.github.io/segmantR/reference/sg_roi_contains.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/reference/sg_roi_distance.md),
[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/reference/sg_roi_fix_geometry.md),
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
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
sg_roi_check_geometry(proj)
#> # A tibble: 0 × 4
#> # ℹ 4 variables: roi_id <chr>, issue <chr>, severity <chr>, fixable <lgl>
```
