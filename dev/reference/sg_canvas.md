# Draw cell boundaries on a microscopy image

The canvas uses local array pixel coordinates (top-left origin, x right,
y down). Drawing emits Shiny inputs suffixed `_created`, `_edited`, and
`_erased`. Use
[`sg_canvas_correct()`](https://cttir.github.io/segmantR/dev/reference/sg_canvas_correct.md)
to stage changes to a mask.

## Usage

``` r
sg_canvas(
  image,
  mask = NULL,
  channel = 1L,
  tool = "pan",
  width = NULL,
  height = 600,
  elementId = NULL
)
```

## Arguments

- image:

  An `sg_image`.

- mask:

  Optional `sg_mask` bound to the same image.

- channel:

  One-based display channel.

- tool:

  Drawing tool.

- width, height:

  Widget dimensions.

- elementId:

  Optional widget id.

## Value

An HTML widget.
