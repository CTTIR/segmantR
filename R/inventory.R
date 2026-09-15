# SHA-256 asset inventories (integrity.json and checksums.sha256)

.sg_inventory_files <- c("integrity.json", "checksums.sha256")

#' Hash, write or verify a bundle inventory
#'
#' Computes SHA-256 digests and sizes for every regular file below `root`
#' (except the inventory files themselves), using bundle-relative
#' forward-slash paths. The `integrity.json` form is identical to the
#' qupflowR workflow-bundle rule: `{"format_version": "1.0", "files":
#' [{"path", "size_bytes", "sha256"}]}` sorted by path, and the bundle digest
#' is the SHA-256 of its canonical JSON (keys sorted, no whitespace).
#' `checksums.sha256` uses the `sha256sum` text format.
#'
#' Symbolic links, absolute or parent-relative paths and special files are
#' rejected. Absolute paths are never written.
#'
#' @param root Bundle directory.
#' @param files Optional character vector of relative paths to inventory
#'   (default: all regular files).
#' @param write Which inventory files to write: `"none"`, `"integrity"`,
#'   `"sha256sum"` or `"both"`.
#' @param verify Logical; if `TRUE`, compare the directory with its existing
#'   `integrity.json` (or `checksums.sha256`) and signal an
#'   `sg_integrity_error` on any missing, extra, duplicate, resized or
#'   modified file.
#'
#' @return An `sg_asset_inventory` list with `files` (tibble), `integrity`
#'   (list) and `bundle_digest` (`"sha256:<hex>"`), invisibly when writing.
#' @export
#' @examples
#' d <- tempfile("bundle")
#' dir.create(d)
#' writeLines("a", file.path(d, "a.txt"))
#' inv <- sg_hash_assets(d, write = "integrity")
#' inv$bundle_digest
#' sg_hash_assets(d, verify = TRUE)$bundle_digest == inv$bundle_digest
sg_hash_assets <- function(root, files = NULL,
                           write = c("none", "integrity", "sha256sum", "both"),
                           verify = FALSE) {
  write <- match.arg(write)
  if (!is.character(root) || length(root) != 1L || !dir.exists(root)) {
    .sg_abort("{.arg root} must be an existing directory.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH")
  }
  if (verify) {
    report <- .sg_verify_inventory(root)
    if (!report$ok) {
      shown <- utils::head(report$problems, 8L)
      .sg_abort(
        c("Bundle inventory does not match the files.",
          stats::setNames(.sg_cli_escape(shown), rep("x", length(shown)))),
        class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
        details = list(problems = report$problems)
      )
    }
  }
  rel <- files %||% setdiff(.sg_list_rel_files(root), .sg_inventory_files)
  rel <- rel[order(enc2utf8(rel), method = "radix")]
  if (anyDuplicated(rel)) {
    .sg_abort("Duplicate inventory paths.", class = "sg_integrity_error",
              code = "INTEGRITY_MISMATCH")
  }
  full <- vapply(rel, function(r) {
    .sg_check_regular_file(root, r)
  }, character(1), USE.NAMES = FALSE)
  sizes <- file.info(full)$size
  hashes <- .sg_sha256_file(full)
  tbl <- tibble::tibble(path = rel, size_bytes = as.numeric(sizes),
                        sha256 = hashes)
  integrity <- list(
    format_version = "1.0",
    files = lapply(seq_along(rel), function(i) {
      list(path = rel[i], size_bytes = .sg_json_int(sizes[i]),
           sha256 = hashes[i])
    })
  )
  canonical <- .sg_canonical_json(integrity)
  digest <- paste0("sha256:", .sg_sha256(canonical))
  inv <- structure(list(files = tbl, integrity = integrity,
                        bundle_digest = digest),
                   class = "sg_asset_inventory")
  if (write %in% c("integrity", "both")) {
    .sg_write_text(canonical, file.path(root, "integrity.json"))
  }
  if (write %in% c("sha256sum", "both")) {
    lines <- paste0(hashes, "  ", rel)
    .sg_write_text(paste0(paste(lines, collapse = "\n"),
                          if (length(lines)) "\n" else ""),
                   file.path(root, "checksums.sha256"))
  }
  if (write != "none") invisible(inv) else inv
}

#' @export
print.sg_asset_inventory <- function(x, ...) {
  cli::cli_text("{.cls sg_asset_inventory}: {nrow(x$files)} file{?s}, {sum(x$files$size_bytes)} bytes")
  cli::cli_text("Bundle digest: {x$bundle_digest}")
  invisible(x)
}

#' Integer-valued number for JSON (integer when it fits)
#' @noRd
.sg_json_int <- function(x) {
  if (abs(x) < .Machine$integer.max) as.integer(x) else as.numeric(x)
}

#' Write text as UTF-8 bytes without a trailing newline conversion
#' @noRd
.sg_write_text <- function(text, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(text)), con)
  invisible(path)
}

#' Resolve a relative path to a regular, non-link file inside root
#' @noRd
.sg_check_regular_file <- function(root, rel) {
  full <- .sg_resolve_in_root(root, rel, must_exist = TRUE)
  segs <- strsplit(rel, "/", fixed = TRUE)[[1]]
  root_n <- normalizePath(root, winslash = "/", mustWork = TRUE)
  cur <- root_n
  for (s in segs) {
    cur <- file.path(cur, s)
    if (nzchar(Sys.readlink(cur))) {
      .sg_abort("Symbolic links are not allowed in bundles ({.file {rel}}).",
                class = "sg_security_error", code = "PATH_OUTSIDE_ROOT",
                details = list(path = rel))
    }
  }
  info <- file.info(full)
  if (isTRUE(info$isdir)) {
    .sg_abort("{.file {rel}} is a directory, not a file.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
              details = list(path = rel))
  }
  full
}

#' Compare a directory with its inventory
#' @return List with `ok`, `problems`, `expected` (parsed inventory) and
#'   `digest` of the recorded inventory.
#' @noRd
.sg_verify_inventory <- function(root) {
  problems <- character(0)
  int_path <- file.path(root, "integrity.json")
  sum_path <- file.path(root, "checksums.sha256")
  expected <- NULL
  if (file.exists(int_path)) {
    doc <- .sg_read_json(int_path)
    errs <- .sg_schema_errors(doc, "integrity.schema.json", normalise = FALSE)
    if (length(errs)) {
      return(list(ok = FALSE, problems = c("integrity.json is invalid", errs),
                  expected = NULL, digest = NA_character_))
    }
    expected <- tibble::tibble(
      path = vapply(doc$files, function(f) f$path, character(1)),
      size_bytes = vapply(doc$files, function(f) as.numeric(f$size_bytes),
                          numeric(1)),
      sha256 = vapply(doc$files, function(f) f$sha256, character(1))
    )
    digest <- paste0("sha256:", .sg_sha256(.sg_canonical_json(doc)))
  } else if (file.exists(sum_path)) {
    lines <- readLines(sum_path, warn = FALSE)
    lines <- lines[nzchar(lines)]
    m <- regmatches(lines, regexec("^([0-9a-f]{64}) [ *](.+)$", lines))
    bad <- vapply(m, length, integer(1)) != 3L
    if (any(bad)) {
      return(list(ok = FALSE, problems = "checksums.sha256 is malformed",
                  expected = NULL, digest = NA_character_))
    }
    expected <- tibble::tibble(
      path = vapply(m, `[`, character(1), 3L),
      size_bytes = NA_real_,
      sha256 = vapply(m, `[`, character(1), 2L)
    )
    digest <- paste0("sha256:", .sg_sha256_file(sum_path))
  } else {
    return(list(ok = FALSE, problems = "no integrity.json or checksums.sha256",
                expected = NULL, digest = NA_character_))
  }
  dup <- unique(expected$path[duplicated(expected$path)])
  if (length(dup)) problems <- c(problems, paste("duplicate entry:", dup))
  for (p in unique(expected$path)) {
    ok_path <- tryCatch({
      .sg_check_relpath(p)
      TRUE
    }, sg_error = function(e) FALSE)
    if (!ok_path) problems <- c(problems, paste("unsafe path:", p))
  }
  if (length(problems)) {
    return(list(ok = FALSE, problems = problems, expected = expected,
                digest = digest))
  }
  actual <- setdiff(.sg_list_rel_files(root), .sg_inventory_files)
  missing <- setdiff(expected$path, actual)
  extra <- setdiff(actual, expected$path)
  if (length(missing)) problems <- c(problems, paste("missing file:", missing))
  if (length(extra)) problems <- c(problems, paste("unlisted file:", extra))
  present <- intersect(expected$path, actual)
  for (p in present) {
    full <- tryCatch(.sg_check_regular_file(root, p),
                     sg_error = function(e) NULL)
    if (is.null(full)) {
      problems <- c(problems, paste("unsafe file:", p))
      next
    }
    row <- expected[expected$path == p, ][1, ]
    size <- file.info(full)$size
    if (!is.na(row$size_bytes) && size != row$size_bytes) {
      problems <- c(problems, paste0("size mismatch: ", p, " (", size,
                                     " != ", row$size_bytes, ")"))
      next
    }
    if (.sg_sha256_file(full) != row$sha256) {
      problems <- c(problems, paste("sha256 mismatch:", p))
    }
  }
  list(ok = length(problems) == 0L, problems = problems, expected = expected,
       digest = digest)
}
