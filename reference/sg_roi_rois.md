# Query the ROIs of a project

Return a tidy table of ROIs, optionally filtered by layer and/or label.

## Usage

``` r
sg_roi_rois(project, layer = NULL, label = NULL, call = rlang::caller_env())
```

## Arguments

- project:

  An
  [sg_roi_project](https://cttir.github.io/segmantR/reference/sg_roi_project.md).

- layer:

  Optional single layer name to filter to.

- label:

  Optional character vector of labels to filter to.

- call:

  The calling environment, for error reporting.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per ROI and, in this exact order, the columns:

- `roi_id`:

  Unique identifier (character).

- `layer`:

  Layer name (character).

- `label`:

  Class label (character).

- `geom_type`:

  Geometry type, e.g. `"POLYGON"` (character).

- `level`:

  Reference pyramid level (integer).

- `area_px`:

  Area in level-0 pixels (double); `NA` for points/lines.

- `centroid_x`,`centroid_y`:

  Centroid at level 0 (double).

- `n_vertices`:

  Vertex count (integer).

- `created`,`modified`:

  Timestamps (POSIXct).

- `author`:

  Author (character).

- `source`:

  Provenance source (character).

- `geometry`:

  The `sf` geometry column (`sfc`), at level 0.

Returns a 0-row tibble with these columns if no ROIs match.

## Details

Coordinates in the `geometry` column, together with `area_px` and the
centroid, are expressed at pyramid level 0; the `level` column records
the level at which each ROI was originally defined.

## See also

[`sg_roi_layers()`](https://cttir.github.io/segmantR/reference/sg_roi_layers.md),
[`sg_roi_mask()`](https://cttir.github.io/segmantR/reference/sg_roi_mask.md)

Other projects:
[`sg_roi_add_layer()`](https://cttir.github.io/segmantR/reference/sg_roi_add_layer.md),
[`sg_roi_add_roi()`](https://cttir.github.io/segmantR/reference/sg_roi_add_roi.md),
[`sg_roi_layers()`](https://cttir.github.io/segmantR/reference/sg_roi_layers.md),
[`sg_roi_project()`](https://cttir.github.io/segmantR/reference/sg_roi_project.md),
[`sg_roi_remove_layer()`](https://cttir.github.io/segmantR/reference/sg_roi_remove_layer.md),
[`sg_roi_remove_roi()`](https://cttir.github.io/segmantR/reference/sg_roi_remove_roi.md),
[`sg_roi_summary()`](https://cttir.github.io/segmantR/reference/sg_roi_summary.md),
[`sg_roi_validate()`](https://cttir.github.io/segmantR/reference/sg_roi_validate.md)

## Examples

``` r
lyr <- sg_roi_layer_add(sg_roi_layer("tissue"),
                        sg_roi_rect(2, 2, 8, 8, label = "tissue"))
proj <- sg_roi_project(sg_roi_frame(c(20, 20)), lyr)
sg_roi_rois(proj)
#> # A tibble: 1 × 14
#>   roi_id    layer label geom_type level area_px centroid_x centroid_y n_vertices
#>   <chr>     <chr> <chr> <chr>     <int>   <dbl>      <dbl>      <dbl>      <int>
#> 1 roi_0000… tiss… tiss… POLYGON       0      36          5          5          5
#> # ℹ 5 more variables: created <dttm>, modified <dttm>, author <chr>,
#> #   source <chr>, geometry <POLYGON>
```
