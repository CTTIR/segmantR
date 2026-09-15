# Import QuPath results into segmantR

Reads the output of the segmantR QuPath templates (a directory with a
`qupath-export` manifest and `integrity.json`), a QuPath program
directory containing such an output (`out/` or `qupath_export/`), or a
plain QuPath GeoJSON export. All checks of
[`sg_import_interchange()`](https://cttir.github.io/segmantR/dev/reference/sg_import_interchange.md)
run (inventory, schema, dtype, shape/orientation, legend, content digest
and revision); in addition the QuPath GeoJSON is rasterised and compared
with the QuPath label TIFF, object ids are matched through the legend,
the run id and image binding can be checked, and measurements are
imported in the canonical long format (`namespace = "stored"`). The mask
is staged.

## Usage

``` r
sg_import_qupath(path, ..., image = NULL, expected_run_id = NULL, error = TRUE)
```

## Arguments

- path:

  Export directory, program directory or GeoJSON file.

- ...:

  Reserved; must be empty.

- image:

  Optional `sg_image` to check the binding (size, pixel size, plane) or
  to rasterise a plain GeoJSON.

- expected_run_id:

  Optional run id (`run.json` `run_id`) the export must belong to.

- error:

  Logical; signal failures instead of reporting them.

## Value

An `sg_import_report` with an extra `qupath` element (QuPath and
extension versions, template version, run id, GeoJSON/TIFF agreement).

## Examples

``` r
# \donttest{
# rep <- sg_import_qupath("path/to/out")
# }
```
