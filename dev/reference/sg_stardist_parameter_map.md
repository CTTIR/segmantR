# Map StarDist protocol parameters to Python or QuPath

Every declared parameter of the protocol appears in the result with the
target option, the target value and a status: `mapped`, `approximated`,
`unsupported`, `not_applicable` or `runner` (handled by segmantR before
delegation). Unknown parameters are errors; nothing is dropped silently.

## Usage

``` r
sg_stardist_parameter_map(
  protocol = "stardist.2d.v1",
  target = c("python", "qupath"),
  ...,
  image = NULL
)
```

## Arguments

- protocol:

  Protocol id or `sg_protocol` (StarDist family).

- target:

  `"python"` (reticulate,
  [`sg_segment_stardist()`](https://cttir.github.io/segmantR/dev/reference/sg_segment_stardist.md))
  or `"qupath"` (StarDist extension builder).

- ...:

  Parameter overrides.

- image:

  Optional `sg_image` used to resolve channel indices and wavelengths to
  channel names for QuPath.

## Value

A tibble with `parameter`, `value`, `target`, `target_option`,
`target_value`, `status` and `note`; attribute `parameters` holds the
resolved parameters.

## Examples

``` r
sg_stardist_parameter_map("stardist.2d.v1", "qupath", prob_thresh = 0.6)
#> # A tibble: 16 × 7
#>    parameter               value  target target_option target_value status note 
#>    <chr>                   <list> <chr>  <chr>         <list>       <chr>  <chr>
#>  1 channel                 <int>  qupath channels      <int [1]>    mapped "QuP…
#>  2 channel_name            <NULL> qupath channels      <NULL>       not_a… ""   
#>  3 wavelength_nm           <NULL> qupath channels      <lgl [1]>    not_a… "QuP…
#>  4 wavelength_tolerance_nm <dbl>  qupath <export>      <dbl [1]>    runner "Use…
#>  5 model                   <chr>  qupath StarDist2D.b… <chr [1]>    not_a… "QuP…
#>  6 prob_thresh             <dbl>  qupath threshold     <dbl [1]>    mapped ""   
#>  7 nms_thresh              <dbl>  qupath NA            <dbl [1]>    appro… "The…
#>  8 normalize_low           <dbl>  qupath preprocessGl… <dbl [1]>    appro… "Glo…
#>  9 normalize_high          <dbl>  qupath preprocessGl… <dbl [1]>    appro… ""   
#> 10 normalize_scope         <chr>  qupath <builder cho… <chr [1]>    mapped "til…
#> 11 pixel_size_um           <NULL> qupath pixelSize     <NULL>       mapped ""   
#> 12 tile_size               <NULL> qupath tileSize      <NULL>       mapped "nul…
#> 13 include_probability     <lgl>  qupath includeProba… <lgl [1]>    mapped ""   
#> 14 cell_expansion_um       <NULL> qupath cellExpansion <NULL>       mapped ""   
#> 15 create_annotations      <lgl>  qupath createAnnota… <lgl [1]>    mapped ""   
#> 16 classification          <NULL> qupath classify      <NULL>       mapped ""   
```
