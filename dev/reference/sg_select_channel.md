# Select one analysis channel from an image

Produces a single-channel `sg_image` from a channel index, a channel or
band name, a band wavelength, or one of the registered band operations
`band_mean`, `ratio` and `normalized_difference`. No free expressions
are accepted. The result records the source bands, wavelengths,
operation, value semantics and a transform digest so declarative
protocol runs and direct calls stay comparable.

## Usage

``` r
sg_select_channel(
  image,
  channel = 1L,
  channel_name = NULL,
  wavelength_nm = NULL,
  wavelength_tolerance_nm = 5,
  band_operation = "none",
  band_a_nm = NULL,
  band_b_nm = NULL,
  band_min_nm = NULL,
  band_max_nm = NULL
)
```

## Arguments

- image:

  An `sg_image` object.

- channel:

  1-based channel index (used when no other selector is given).

- channel_name:

  Channel or band name.

- wavelength_nm:

  Band centre wavelength to select.

- wavelength_tolerance_nm:

  Maximum distance to the nearest band centre.

- band_operation:

  One of `"none"`, `"band_mean"`, `"ratio"`, `"normalized_difference"`.

- band_a_nm, band_b_nm:

  Wavelengths of bands a and b for `ratio` and `normalized_difference`.

- band_min_nm, band_max_nm:

  Wavelength interval for `band_mean`.

## Value

A single-channel `sg_image`.

## Details

Band operations require band wavelengths (see
[`new_sg_image()`](https://cttir.github.io/segmantR/dev/reference/new_sg_image.md)
`bands` or
[`sg_read_envi()`](https://cttir.github.io/segmantR/dev/reference/sg_read_envi.md))
and refuse images whose `value_semantics` is `"unknown"` for `ratio` and
`normalized_difference`, because such ratios are only interpretable for
a declared value scale. Non-finite results (division by zero) are
replaced by the smallest finite result and counted in
`provenance$band_selection$non_finite_replaced`.

## Examples

``` r
cube <- array(runif(5 * 5 * 3), dim = c(5, 5, 3))
img <- new_sg_image(cube, channels = c("b450", "b550", "b650"),
                    bands = data.frame(wavelength_nm = c(450, 550, 650)),
                    value_semantics = "reflectance")
sg_select_channel(img, wavelength_nm = 552)$channels
#> [1] "b550"
nd <- sg_select_channel(img, band_operation = "normalized_difference",
                        band_a_nm = 650, band_b_nm = 550)
nd$provenance$band_selection$operation
#> [1] "normalized_difference"
```
