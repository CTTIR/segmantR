# List registered segmentation protocols

List registered segmentation protocols

## Usage

``` r
sg_protocol_list(check_available = FALSE)
```

## Arguments

- check_available:

  Logical; if `TRUE`, probe optional Python backends (this initialises
  Python through reticulate). Default `FALSE` reports `NA` availability
  for optional backends.

## Value

A tibble with one row per protocol: `id`, `version`, `title`, `family`,
`backend`, `delegate`, `requires_python`, `status` (`"core"` or
`"optional"`), `available`, `qupath_mapping` and `digest`.

## Examples

``` r
sg_protocol_list()
#> # A tibble: 10 × 11
#>    id     version title family backend delegate requires_python status available
#>    <chr>  <chr>   <chr> <chr>  <chr>   <chr>    <lgl>           <chr>  <lgl>    
#>  1 cellp… 1.0.0   Cell… dnn    python… sg_segm… TRUE            optio… NA       
#>  2 mesme… 1.0.0   Mesm… dnn    python… sg_segm… TRUE            optio… NA       
#>  3 postp… 1.0.0   Labe… postp… segman… sg_clea… FALSE           core   TRUE     
#>  4 propa… 1.0.0   Voro… propa… segman… sg_segm… FALSE           core   TRUE     
#>  5 stard… 1.0.0   Star… dnn    python… sg_segm… TRUE            optio… NA       
#>  6 thres… 1.0.0   Adap… thres… segman… sg_segm… FALSE           core   TRUE     
#>  7 thres… 1.0.0   Glob… thres… segman… sg_segm… FALSE           core   TRUE     
#>  8 thres… 1.0.0   Tria… thres… segman… sg_segm… FALSE           core   TRUE     
#>  9 water… 1.0.0   Mark… water… segman… sg_segm… FALSE           core   TRUE     
#> 10 water… 1.0.0   Mark… water… segman… sg_segm… FALSE           core   TRUE     
#> # ℹ 2 more variables: qupath_mapping <lgl>, digest <chr>
```
