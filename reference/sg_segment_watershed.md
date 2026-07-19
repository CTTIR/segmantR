# Marker-controlled watershed segmentation

Segments cells using a marker-controlled watershed algorithm. Seeds
(markers) are detected automatically via distance-transform peaks or
h-minima, and the watershed flood fills from these seeds.

## Usage

``` r
sg_segment_watershed(
  image,
  channel = 1L,
  seed_method = c("h_minima", "distance", "markers"),
  h = 0.05,
  min_distance = 10L,
  expand_method = c("voronoi", "dilation"),
  expand_pixels = 3L,
  membrane_channel = NULL
)
```

## Arguments

- image:

  An `sg_image` object.

- channel:

  Integer index of the image channel used for segmentation. Default is
  `1L`.

- seed_method:

  Character string specifying how seeds are generated. One of
  `"h_minima"` (default), `"distance"`, or `"markers"`.

- h:

  Numeric; height parameter for h-minima or distance threshold fraction
  for seed detection. Default is `0.05`.

- min_distance:

  Integer; minimum pixel distance between seeds. Default is `10L`.

- expand_method:

  Character string specifying how seed regions are expanded. One of
  `"voronoi"` (default) or `"dilation"`.

- expand_pixels:

  Integer; number of pixels to expand beyond the initial watershed
  regions. Default is `3L`.

- membrane_channel:

  Integer or `NULL`. If provided, this channel is used as the
  topographic surface for watershed flooding. If `NULL`, the inverted
  `channel` image is used.

## Value

An `sg_mask` object with labelled cell regions.

## Examples

``` r
set.seed(42)
pixels <- matrix(runif(400), nrow = 20, ncol = 20)
img <- new_sg_image(pixels)
mask <- sg_segment_watershed(img, seed_method = "distance", h = 0.3)
#> ℹ Generated 1 seed via "distance".
#> ✔ Watershed segmented 1 object.
print(mask)
#> <sg_mask>: 20 x 20, 1 cell
#> Method: watershed
```
