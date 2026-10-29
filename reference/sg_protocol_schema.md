# Protocol schema and parameter specifications

Protocol schema and parameter specifications

## Usage

``` r
sg_protocol_schema(id = NULL)
```

## Arguments

- id:

  `NULL` for the JSON Schema of `segmantR-protocol-v1` (as a parsed
  list), or a protocol id for its parameter table.

## Value

For `id = NULL`, the parsed JSON Schema. Otherwise a tibble with `name`,
`type`, `default`, `nullable`, `minimum`, `maximum`, `enum`, `unit`,
`requires_calibration`, `maps_to` and `description`.

## Examples

``` r
names(sg_protocol_schema()$properties)
#>  [1] "schema"            "id"                "version"          
#>  [4] "title"             "description"       "family"           
#>  [7] "input_contract"    "preprocess"        "method"           
#> [10] "postprocess"       "tiling"            "output_contract"  
#> [13] "runtime_profile"   "seed_policy"       "provenance_policy"
#> [16] "parameters"        "extensions"       
sg_protocol_schema("threshold.otsu.v1")[, c("name", "default", "unit")]
#> # A tibble: 13 × 3
#>    name                    default   unit 
#>    <chr>                   <list>    <chr>
#>  1 band_a_nm               <NULL>    nm   
#>  2 band_b_nm               <NULL>    nm   
#>  3 band_max_nm             <NULL>    nm   
#>  4 band_min_nm             <NULL>    nm   
#>  5 band_operation          <chr [1]> none 
#>  6 channel                 <int [1]> index
#>  7 channel_name            <NULL>    name 
#>  8 fill_holes              <lgl [1]> none 
#>  9 max_area                <int [1]> px2  
#> 10 min_area                <int [1]> px2  
#> 11 open_size               <int [1]> px   
#> 12 wavelength_nm           <NULL>    nm   
#> 13 wavelength_tolerance_nm <int [1]> nm   
```
