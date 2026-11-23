# Plot an ROI

Plot an ROI

## Usage

``` r
# S3 method for class 'sg_roi'
plot(x, ...)
```

## Arguments

- x:

  An [sg_roi](https://cttir.github.io/segmantR/reference/sg_roi.md).

- ...:

  Ignored.

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object in image orientation (origin at the top left, y pointing down;
this needs 'ggplot2' 4.0.0 or later, older versions draw y pointing up).
The plot is not drawn; print it to render.
