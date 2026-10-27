# Create a layer

Create a layer

## Usage

``` r
sg_roi_layer(
  name,
  labels = character(),
  style = sg_roi_style(),
  ...,
  call = rlang::caller_env()
)
```

## Arguments

- name:

  Single string layer name (unique within a project).

- labels:

  Character vector; the controlled label vocabulary for the layer.

- style:

  An `annot_style`, from
  [`sg_roi_style()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_style.md).

- ...:

  Additional named metadata stored on the layer.

- call:

  The calling environment, for error reporting.

## Value

An sg_roi_layer with no ROIs and a resolved colour mapping.

## See also

[`sg_roi_style()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_style.md),
[`sg_roi_layer_add()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_add.md)

Other layers:
[`sg_roi_layer_add()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_add.md),
[`sg_roi_layer_n()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_n.md),
[`sg_roi_layer_remove()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_remove.md),
[`sg_roi_layer_rois()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_layer_rois.md),
[`sg_roi_style()`](https://cttir.github.io/segmantR/dev/reference/sg_roi_style.md)

## Examples

``` r
lyr <- sg_roi_layer("tumour", labels = c("tumour", "stroma"))
sg_roi_layer_n(lyr)
#> [1] 0
```
