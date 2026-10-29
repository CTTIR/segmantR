# Display levels from positive and negative reference cells

Sets the black and full-colour levels of each channel from the signal
around reference cells, so that called-negative cells stay dark and
called-positive cells reach full colour: for every channel up to `n`
negative and `n` positive cells are drawn, a statistic of the
`(2 * half + 1)`-pixel square patch around each cell is taken (`"mean"`
or a percentile given as a probability), and the levels are the `black`
quantile of the negative and the `white` quantile of the positive cell
values.

## Usage

``` r
sg_display_levels(
  path,
  channels,
  cells,
  positive,
  negative,
  x = "x",
  y = "y",
  label = "label",
  pixel_size = 1,
  half = 7,
  statistic = 0.9,
  black = 0.5,
  white = 0.5,
  n = 300,
  seed = 0
)
```

## Arguments

- path:

  Path to the image file.

- channels:

  Channel names.

- cells:

  Data frame of cells with positions and labels.

- positive, negative:

  Named lists: channel name to the labels of the positive and negative
  reference cells.

- x, y, label:

  Column names in `cells` (positions in physical units).

- pixel_size:

  Physical size of one pixel.

- half:

  Patch half-width in pixels.

- statistic:

  `"mean"` or a probability for a patch percentile.

- black, white:

  Quantiles across negative and positive cells.

- n:

  Maximum number of reference cells per set.

- seed:

  Random seed for the draws (the global RNG state is restored).

## Value

A data frame with columns `channel`, `lo`, `hi`, `n_negative` and
`n_positive`.

## Details

Arguments that vary by channel (`half`, `statistic`, `black`, `white`)
accept a single value or a named list/vector by channel name, with an
optional `.default` entry.

## See also

[`sg_slide_display_ranges()`](https://cttir.github.io/segmantR/dev/reference/sg_slide_display_ranges.md),
[`sg_display_range()`](https://cttir.github.io/segmantR/dev/reference/sg_display_range.md)

## Examples

``` r
f <- tempfile(fileext = ".tif")
plane <- matrix(10, 40, 40)
plane[21:40, ] <- 200
invisible(tiff::writeTIFF(plane / 255, f, bits.per.sample = 8L))
cells <- data.frame(x = c(5, 15, 25, 35), y = c(5, 10, 30, 35),
                    label = c("neg", "neg", "pos", "pos"))
sg_display_levels(f, "ch1", cells, positive = list(ch1 = "pos"),
                  negative = list(ch1 = "neg"), half = 2)
#>   channel lo  hi n_negative n_positive
#> 1     ch1 10 200          2          2
```
