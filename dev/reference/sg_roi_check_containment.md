# Check cross-layer containment

Report ROIs in a constrained layer that fall outside their container
region. A layer declares the constraint through its metadata, e.g.
`sg_roi_layer("state", within = list(layer = "anatomy", label = "wound"))`;
then every ROI in `state` must be spatially covered by the union of the
`anatomy` layer's `wound` ROIs. This enforces the annotation rule that a
class is painted only inside its region of interest. The report mirrors
the shape of
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_geometry.md).

## Usage

``` r
sg_roi_check_containment(project, tol = 0, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/dev/reference/sg_roi_project.md).

- tol:

  Non-negative slack, in level-0 pixels, by which the container is grown
  before testing, to tolerate sub-pixel tracing overhang. Default `0`.

- call:

  The calling environment, for error reporting.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with columns `roi_id`, `layer`, `issue`, `severity` (`"warning"` for an
ROI outside its container, `"error"` for a missing/empty container), and
`fixable` (always `FALSE`). A 0-row tibble when every constrained ROI is
contained, or when no layer declares a `within` constraint.

## See also

[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_geometry.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_validate.md)

Other geometry:
[`sg_roi_buffer()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_buffer.md),
[`sg_roi_check_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_check_geometry.md),
[`sg_roi_clamp()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_clamp.md),
[`sg_roi_contains()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_contains.md),
[`sg_roi_distance()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_distance.md),
[`sg_roi_fix_geometry()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_fix_geometry.md),
[`sg_roi_flip_y()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_flip_y.md),
[`sg_roi_overlaps()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_overlaps.md),
[`sg_roi_rescale()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rescale.md),
[`sg_roi_ring()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_ring.md),
[`sg_roi_rois_overlap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_rois_overlap.md),
[`sg_roi_setops`](https://cttir.github.io/segmantR/dev/reference/sg_roi_setops.md),
[`sg_roi_simplify()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_simplify.md),
[`sg_roi_snap()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_snap.md),
[`sg_roi_transform()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_transform.md)

## Examples

``` r
anatomy <- sg_roi_layer_add(sg_roi_layer("anatomy", labels = "wound"),
                        sg_roi_rect(2, 2, 8, 8, label = "wound"))
state <- sg_roi_layer("state", labels = "injury",
                  within = list(layer = "anatomy", label = "wound"))
state <- sg_roi_layer_add(state, sg_roi_rect(0, 0, 4, 4, label = "injury"))
sg_roi_check_containment(sg_roi_project(sg_roi_frame(c(100, 100)), list(anatomy, state)))
#> # A tibble: 1 × 5
#>   roi_id        layer issue                                     severity fixable
#>   <chr>         <chr> <chr>                                     <chr>    <lgl>  
#> 1 roi_000000006 state ROI is not contained in layer 'anatomy' … warning  FALSE  
```
