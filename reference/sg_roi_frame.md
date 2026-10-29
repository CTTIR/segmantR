# Declare the coordinate frame for histology ROIs

A metadata-only frame; no image reader, spectral backend, or pixel data
is loaded. Coordinates have top-left origin, x right, y down. Pyramid
dimensions are supplied explicitly, permitting anisotropic and
non-power-of-two levels. Calibration is the physical size of a
level-zero pixel along x and y.

## Usage

``` r
sg_roi_frame(
  dims,
  level_dims = list(dims),
  pixel_size = c(1, 1),
  pixel_unit = "px",
  source = ""
)
```

## Arguments

- dims:

  Integer-valued width and height at level zero.

- level_dims:

  List of width/height vectors, starting with `dims`.

- pixel_size:

  Positive finite x/y pixel sizes at level zero.

- pixel_unit:

  Unit of the calibration, e.g. `"um"` or `"px"`.

- source:

  Image identifier or path, recorded without reading the file.

## Value

A `sg_roi_frame` for
[`sg_roi_project()`](https://cttir.github.io/segmantR/reference/sg_roi_project.md)
and
[`sg_roi_transform()`](https://cttir.github.io/segmantR/reference/sg_roi_transform.md).

## Examples

``` r
frame <- sg_roi_frame(c(100, 80), list(c(100, 80), c(30, 20)), c(0.5, 0.8), "um")
sg_roi_dims(frame, 1)
#> [1] 30 20
```
