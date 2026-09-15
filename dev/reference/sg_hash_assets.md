# Hash, write or verify a bundle inventory

Computes SHA-256 digests and sizes for every regular file below `root`
(except the inventory files themselves), using bundle-relative
forward-slash paths. The `integrity.json` form is identical to the
qupflowR workflow-bundle rule:
`{"format_version": "1.0", "files": [{"path", "size_bytes", "sha256"}]}`
sorted by path, and the bundle digest is the SHA-256 of its canonical
JSON (keys sorted, no whitespace). `checksums.sha256` uses the
`sha256sum` text format.

## Usage

``` r
sg_hash_assets(
  root,
  files = NULL,
  write = c("none", "integrity", "sha256sum", "both"),
  verify = FALSE
)
```

## Arguments

- root:

  Bundle directory.

- files:

  Optional character vector of relative paths to inventory (default: all
  regular files).

- write:

  Which inventory files to write: `"none"`, `"integrity"`, `"sha256sum"`
  or `"both"`.

- verify:

  Logical; if `TRUE`, compare the directory with its existing
  `integrity.json` (or `checksums.sha256`) and signal an
  `sg_integrity_error` on any missing, extra, duplicate, resized or
  modified file.

## Value

An `sg_asset_inventory` list with `files` (tibble), `integrity` (list)
and `bundle_digest` (`"sha256:<hex>"`), invisibly when writing.

## Details

Symbolic links, absolute or parent-relative paths and special files are
rejected. Absolute paths are never written.

## Examples

``` r
d <- tempfile("bundle")
dir.create(d)
writeLines("a", file.path(d, "a.txt"))
inv <- sg_hash_assets(d, write = "integrity")
inv$bundle_digest
#> [1] "sha256:c839ed94cb4ee1f062133e64b224f5ab32ebfa6e7ebc1d4585c31c85ab876b14"
sg_hash_assets(d, verify = TRUE)$bundle_digest == inv$bundle_digest
#> [1] TRUE
```
