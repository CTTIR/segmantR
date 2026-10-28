# Display range of fluorescence values

Percentile-based display (black and white) levels for a set of pixel
values, as used to scale fluorescence channels for viewing: `lo` is the
lower percentile (or a given value), `hi` the larger of the upper
percentile, an optional floor and `lo + min_span`. Percentiles use
linear interpolation between order statistics
(`stats::quantile(type = 7)`).

## Usage

``` r
sg_display_range(
  x,
  probs = c(0.01, 0.997),
  lo = NULL,
  hi_floor = NULL,
  min_span = 1
)
```

## Arguments

- x:

  Numeric pixel values (any shape).

- probs:

  Lower and upper probabilities; either may be `NA` when `lo` or
  `hi_floor` replace it.

- lo:

  Optional fixed lower level (replaces the lower percentile).

- hi_floor:

  Optional value the upper level must at least reach.

- min_span:

  Minimum distance between the two levels.

## Value

Named numeric `c(lo = , hi = )`.

## See also

[`sg_slide_display_ranges()`](https://cttir.github.io/segmantR/dev/reference/sg_slide_display_ranges.md),
[`sg_display_levels()`](https://cttir.github.io/segmantR/dev/reference/sg_display_levels.md)

## Examples

``` r
sg_display_range(c(0, 1, 2, 3, 100))
#>     lo     hi 
#>  0.040 98.836 
sg_display_range(1:10, probs = c(NA, 0.995), lo = 2, hi_floor = 20)
#> lo hi 
#>  2 20 
```
