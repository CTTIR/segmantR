# Read and validate an ENVI header without reading pixel data

Read and validate an ENVI header without reading pixel data

## Usage

``` r
sg_envi_info(path, data_file = NULL)
```

## Arguments

- path:

  Path to the `.hdr` file or to the data file next to it.

- data_file:

  Optional explicit data file path.

## Value

A list of class `sg_envi_info` with `samples`, `lines`, `bands`,
`interleave`, `byte_order`, `data_type`, `dtype`, `header_offset`,
`wavelength_nm`, `fwhm_nm`, `band_names`, `nodata`, `scale_factor`,
`gain`, `offset`, `wavelength_units`, `data_bytes_expected`,
`data_bytes_present` and `header_digest`. Paths are not stored.

## Examples

``` r
d <- tempfile("envi")
dir.create(d)
hdr <- file.path(d, "cube.hdr")
writeLines(c("ENVI", "samples = 2", "lines = 2", "bands = 2",
             "header offset = 0", "data type = 12", "interleave = bsq",
             "byte order = 0", "wavelength = {500, 600}"), hdr)
writeBin(1:8, file.path(d, "cube"), size = 2L, endian = "little")
sg_envi_info(hdr)$wavelength_nm
#> [1] 500 600
```
