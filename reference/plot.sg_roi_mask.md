# Plot a mask

Plot a mask

## Usage

``` r
# S3 method for class 'sg_roi_mask'
plot(x, legend = TRUE, ...)
```

## Arguments

- x:

  An `sg_roi_mask`.

- legend:

  Logical; show the fill legend. Default `TRUE`.

- ...:

  Ignored.

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object (discrete fill from the legend colours, image orientation). When
two labels share a legend colour, as labels from different layers do by
default, the plot uses one Okabe-Ito colour per label instead. Not
drawn; print it to render.
