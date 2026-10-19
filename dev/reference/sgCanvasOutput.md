# Shiny bindings for the cell canvas

Shiny bindings for the cell canvas

## Usage

``` r
sgCanvasOutput(outputId, width = "100%", height = "600px")

renderSgCanvas(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- outputId:

  Output id.

- width, height:

  Output dimensions.

- expr:

  Expression returning
  [`sg_canvas()`](https://cttir.github.io/segmantR/dev/reference/sg_canvas.md).

- env:

  Evaluation environment.

- quoted:

  Whether expr is quoted.

## Value

A Shiny output element or render function.
