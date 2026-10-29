# Slide-wide display ranges from sampled image blocks

Estimates fixed per-channel display ranges for a whole slide from a
sample of the image blocks (tiles) that contain cells: `n_cells` cell
positions are drawn, their storage blocks collected, `n_tiles` of these
blocks drawn, every `step`-th pixel in both directions taken, and
[`sg_display_range()`](https://cttir.github.io/segmantR/dev/reference/sg_display_range.md)
applied per channel. Tiles follow the block grid of the file, so the
estimate reads few blocks even for very large scans.

## Usage

``` r
sg_slide_display_ranges(
  path,
  channels,
  cells,
  x = "x",
  y = "y",
  pixel_size = 1,
  n_cells = 4000,
  n_tiles = 60,
  step = 3,
  probs = c(0.01, 0.997),
  min_span = 1,
  seed = 0,
  source = NULL
)
```

## Arguments

- path:

  Path to the image file.

- channels:

  Channel names or numbers.

- cells:

  Data frame of cell positions in physical units.

- x, y:

  Column names of the positions.

- pixel_size:

  Physical size of one pixel.

- n_cells, n_tiles:

  Numbers of cells and tiles drawn.

- step:

  Pixel subsampling step inside each tile.

- probs, min_span:

  Passed to
  [`sg_display_range()`](https://cttir.github.io/segmantR/dev/reference/sg_display_range.md).

- seed:

  Random seed for the draws (the global RNG state is restored).

- source:

  Optional label stored in a `source` column (for example the image
  name), so that ranges of several images can be stacked.

## Value

A data frame with columns `channel`, `lo`, `hi`, `tiles`, `pixels` and,
with `source`, `source`.

## See also

[`sg_display_levels()`](https://cttir.github.io/segmantR/dev/reference/sg_display_levels.md)

## Examples

``` r
f <- tempfile(fileext = ".tif")
planes <- list(outer(1:64, 1:64, function(i, j) (i + j) %% 200),
               outer(1:64, 1:64, function(i, j) (i * j) %% 250))
invisible(tiff::writeTIFF(lapply(planes, function(p) p / 255), f,
                          bits.per.sample = 8L))
cells <- data.frame(x = c(10, 30, 50, 60), y = c(12, 40, 55, 5))
sg_slide_display_ranges(f, c("ch1", "ch2"), cells, n_tiles = 2)
#>   channel   lo      hi tiles pixels
#> 1     ch1 8.00 125.000     1    484
#> 2     ch2 1.83 247.551     1    484
```
