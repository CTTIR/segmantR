# Image dimensions at a pyramid level

Return the pixel dimensions `c(width, height)` of an
[sg_roi_frame](https://cttir.github.io/segmantR/reference/sg_roi_frame.md)
at a given pyramid level.

## Usage

``` r
sg_roi_dims(x, level = 0L, call = rlang::caller_env())
```

## Arguments

- x:

  An
  [sg_roi_frame](https://cttir.github.io/segmantR/reference/sg_roi_frame.md).

- level:

  Integer pyramid level, `0` for full resolution. Must be in the
  declared zero-based pyramid range.

- call:

  The calling environment, for error reporting.

## Value

An integer vector of length 2, `c(width, height)`.

## See also

[`sg_roi_frame()`](https://cttir.github.io/segmantR/reference/sg_roi_frame.md)

## Examples

``` r
sg_roi_dims(sg_roi_frame(c(100, 80)))
#> [1] 100  80
```
