# Load a packaged segmantR model

Reads a `.segmantR` archive created by
[`sg_package_model()`](https://cttir.github.io/segmantR/dev/reference/sg_package_model.md)
and returns an `sg_trained_model` object.

## Usage

``` r
sg_load_model(path, expected_digest = NULL, allow_legacy = TRUE)
```

## Arguments

- path:

  Character. Path to the `.segmantR` archive file.

- expected_digest:

  Optional `"sha256:<hex>"` digest of the archive's `checksums.sha256`
  content (reported as `bundle_digest`).

- allow_legacy:

  Logical; accept archives without checksums.

## Value

An `sg_trained_model` object.

## Details

Before extracting, entry names are checked (no absolute paths, parent
segments, backslashes or drive letters; entry count and total size
limits). After extraction, symbolic links are rejected,
`checksums.sha256` is verified (missing, extra or modified files are
errors), the model card schema and major version and the backend are
checked. Archives written by segmantR 0.1.0 have no checksums; they load
with `integrity = "unverified"` unless `allow_legacy = FALSE`.

## Examples

``` r
# \donttest{
# model <- sg_load_model("my_model.segmantR")
# }
```
