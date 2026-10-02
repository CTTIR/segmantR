# Internal helpers shared by the interchange, protocol, dataset and model
# contracts: canonical JSON, SHA-256, safe relative paths, identifiers,
# semantic versions and runtime description. None of these are exported.

.sg_interchange_schema <- "segmantR-interchange-v1"
.sg_interchange_version <- "1.0.0"
.sg_protocol_schema_id <- "segmantR-protocol-v1"
.sg_api_version <- "1.0.0"

#' Current time as an ISO 8601 UTC string
#' @noRd
.sg_utc_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# ---- canonical JSON ---------------------------------------------------------

#' Mark a value so it is serialised as a JSON object even when empty
#' @noRd
.sg_json_object <- function(x = list()) {
  if (length(x) == 0L) {
    return(structure(list(), names = character(0)))
  }
  x
}

#' Escape a character vector as JSON strings (raw UTF-8, short escapes)
#' @noRd
.sg_json_string <- function(x) {
  x <- enc2utf8(as.character(x))
  vapply(x, function(s) {
    if (is.na(s)) return("null")
    cp <- utf8ToInt(s)
    out <- character(length(cp))
    for (i in seq_along(cp)) {
      code <- cp[i]
      out[i] <- if (code == 34L) {
        "\\\""
      } else if (code == 92L) {
        "\\\\"
      } else if (code == 8L) {
        "\\b"
      } else if (code == 12L) {
        "\\f"
      } else if (code == 10L) {
        "\\n"
      } else if (code == 13L) {
        "\\r"
      } else if (code == 9L) {
        "\\t"
      } else if (code < 32L) {
        sprintf("\\u%04x", code)
      } else {
        intToUtf8(code)
      }
    }
    paste0("\"", paste(out, collapse = ""), "\"")
  }, character(1), USE.NAMES = FALSE)
}

#' Format a finite double like ECMAScript Number.prototype.toString
#' @noRd
.sg_json_number <- function(x) {
  if (!is.finite(x)) {
    .sg_abort(
      "Non-finite numbers cannot be written as canonical JSON.",
      code = "VALIDATION_FAILED",
      details = list(reason = "non_finite_number")
    )
  }
  if (x == 0) return("0")
  sgn <- if (x < 0) "-" else ""
  ax <- abs(x)
  s <- NULL
  for (d in 1:17) {
    s <- formatC(ax, digits = d - 1L, format = "e", decimal.mark = ".")
    # Compare binary64 values using the JSON parser, not display conversion.
    if (jsonlite::parse_json(s) == ax) break
  }
  parts <- strsplit(s, "e", fixed = TRUE)[[1]]
  digits <- gsub(".", "", parts[1], fixed = TRUE)
  digits <- sub("0+$", "", digits)
  if (!nzchar(digits)) digits <- "0"
  k <- nchar(digits)
  n <- as.integer(parts[2]) + 1L
  body <- if (k <= n && n <= 21L) {
    paste0(digits, strrep("0", n - k))
  } else if (n > 0L && n <= 21L) {
    paste0(substr(digits, 1L, n), ".", substr(digits, n + 1L, k))
  } else if (n > -6L && n <= 0L) {
    paste0("0.", strrep("0", -n), digits)
  } else {
    e <- n - 1L
    esign <- if (e < 0L) "-" else "+"
    mant <- if (k == 1L) digits else {
      paste0(substr(digits, 1L, 1L), ".", substr(digits, 2L, k))
    }
    paste0(mant, "e", esign, abs(e))
  }
  paste0(sgn, body)
}

#' Serialise an R value as canonical JSON
#'
#' Named lists become objects with keys sorted by code point, unnamed lists
#' and atomic vectors of length != 1 (or wrapped in `I()`) become arrays,
#' length-one atomics become scalars, `NULL`/`NA` become `null`.
#' @noRd
.sg_canonical_json <- function(x) {
  if (is.null(x)) return("null")
  if (is.factor(x)) x <- as.character(x)
  if (inherits(x, "POSIXt")) {
    x <- format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  if (is.data.frame(x)) {
    rows <- lapply(seq_len(nrow(x)), function(i) {
      as.list(x[i, , drop = FALSE])
    })
    rows <- lapply(rows, function(r) lapply(r, function(v) {
      if (is.list(v)) v[[1]] else v
    }))
    return(paste0("[", paste(vapply(rows, .sg_canonical_json, ""),
                             collapse = ","), "]"))
  }
  if (is.list(x)) {
    nms <- names(x)
    if (!is.null(nms)) {
      if (length(x) == 0L) return("{}")
      if (any(!nzchar(nms)) || anyNA(nms)) {
        .sg_abort("Canonical JSON objects need non-empty keys.",
                  details = list(reason = "empty_key"))
      }
      keys <- enc2utf8(nms)
      if (anyDuplicated(keys)) {
        .sg_abort("Canonical JSON objects need unique keys.",
                  details = list(reason = "duplicate_key"))
      }
      ord <- order(keys, method = "radix")
      vals <- vapply(x[ord], .sg_canonical_json, character(1))
      return(paste0("{", paste0(.sg_json_string(keys[ord]), ":", vals,
                                collapse = ","), "}"))
    }
    vals <- vapply(x, .sg_canonical_json, character(1))
    return(paste0("[", paste(vals, collapse = ","), "]"))
  }
  as_array <- inherits(x, "AsIs") || length(x) != 1L
  x <- unclass(x)
  enc <- if (is.logical(x)) {
    ifelse(is.na(x), "null", ifelse(x, "true", "false"))
  } else if (is.integer(x)) {
    ifelse(is.na(x), "null", as.character(x))
  } else if (is.double(x)) {
    vapply(x, function(v) {
      if (is.na(v) && !is.nan(v)) "null" else .sg_json_number(v)
    }, character(1))
  } else if (is.character(x)) {
    .sg_json_string(x)
  } else {
    .sg_abort("Unsupported value type {.cls {class(x)}} for canonical JSON.",
              details = list(reason = "unsupported_type"))
  }
  if (as_array) paste0("[", paste(enc, collapse = ","), "]") else enc
}

#' Pretty JSON for human-readable files (not used for digests)
#' @noRd
.sg_write_json <- function(x, path, overwrite = TRUE) {
  if (file.exists(path) && !overwrite) {
    .sg_abort("Refusing to overwrite an existing file.",
              class = "sg_conflict_error", code = "DESTINATION_EXISTS",
              details = list(file = basename(path)))
  }
  txt <- jsonlite::prettify(.sg_canonical_json(x), indent = 2)
  tmp <- paste0(path, ".tmp-", Sys.getpid())
  con <- file(tmp, open = "wb")
  writeLines(enc2utf8(as.character(txt)), con, sep = "\n", useBytes = TRUE)
  close(con)
  if (!file.rename(tmp, path)) {
    unlink(tmp)
    .sg_abort("Could not write {.file {basename(path)}}.",
              class = "sg_integrity_error", code = "IO_ERROR")
  }
  invisible(path)
}

#' Read JSON keeping arrays as lists (no simplification)
#' @noRd
.sg_read_json <- function(path) {
  tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) {
      .sg_abort(
        c("Could not parse JSON file {.file {basename(path)}}.",
          "x" = "{conditionMessage(e)}"),
        code = "VALIDATION_FAILED",
        details = list(file = basename(path), reason = "invalid_json")
      )
    }
  )
}

# ---- hashing ----------------------------------------------------------------

#' SHA-256 of a raw vector or a single string (UTF-8 bytes)
#' @noRd
.sg_sha256 <- function(x) {
  if (is.character(x)) x <- charToRaw(enc2utf8(paste(x, collapse = "")))
  stopifnot(is.raw(x))
  if (.sg_has_tools_sha256()) {
    return(unname(tools::sha256sum(bytes = x)))
  }
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(as.character(openssl::sha256(x)))
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(x, algo = "sha256", serialize = FALSE))
  }
  .sg_abort_unavailable(
    "SHA-256 hashing",
    "Use R >= 4.5 or install the {.pkg openssl} or {.pkg digest} package."
  )
}

#' SHA-256 of files (hex, named by input)
#' @noRd
.sg_sha256_file <- function(paths) {
  if (length(paths) == 0L) return(character(0))
  if (.sg_has_tools_sha256()) {
    return(unname(tools::sha256sum(files = paths)))
  }
  vapply(paths, function(p) {
    con <- file(p, open = "rb")
    on.exit(close(con))
    .sg_sha256(readBin(con, "raw", n = file.info(p)$size))
  }, character(1), USE.NAMES = FALSE)
}

#' @noRd
.sg_has_tools_sha256 <- function() {
  getRversion() >= "4.5.0" &&
    "sha256sum" %in% getNamespaceExports("tools")
}

#' Prefixed digest of canonical JSON
#' @noRd
.sg_digest_json <- function(x) {
  paste0("sha256:", .sg_sha256(.sg_canonical_json(x)))
}

#' Deterministic UUID-shaped identifier (RFC 9562 version 8) from a key
#' @noRd
.sg_uuid_from_key <- function(key) {
  h <- .sg_sha256(paste(key, collapse = ""))
  chars <- strsplit(h, "")[[1]][1:32]
  chars[13] <- "8"
  variant <- c("8", "9", "a", "b")
  chars[17] <- variant[(strtoi(chars[17], 16L) %% 4L) + 1L]
  s <- paste(chars, collapse = "")
  paste(substr(s, 1, 8), substr(s, 9, 12), substr(s, 13, 16),
        substr(s, 17, 20), substr(s, 21, 32), sep = "-")
}

#' Unique run identifier without touching the R random number generator
#' @noRd
.sg_new_run_id <- function(prefix = "run") {
  .sg_counter$n <- .sg_counter$n + 1L
  key <- c(prefix, format(Sys.time(), "%Y%m%d%H%M%OS6"),
           Sys.getpid(), .sg_counter$n, tempfile())
  .sg_uuid_from_key(key)
}

.sg_counter <- new.env(parent = emptyenv())
.sg_counter$n <- 0L

#' Content digest of a numeric array in row-major order
#'
#' Bytes: dims as little-endian int32, then values. Integer arrays as int32,
#' doubles as float64, both little-endian, iterated y, x, channel (C order).
#' @noRd
.sg_array_digest <- function(x) {
  d <- dim(x)
  if (is.null(d)) d <- length(x)
  if (length(d) == 2L) {
    v <- as.vector(t(x))
  } else if (length(d) == 3L) {
    v <- as.vector(aperm(x, c(3L, 2L, 1L)))
  } else {
    v <- as.vector(x)
  }
  con <- rawConnection(raw(0), open = "wb")
  on.exit(close(con))
  writeBin(as.integer(d), con, size = 4L, endian = "little")
  if (is.integer(x) || is.logical(x)) {
    writeBin(as.integer(v), con, size = 4L, endian = "little")
  } else {
    writeBin(as.double(v), con, size = 8L, endian = "little")
  }
  paste0("sha256:", .sg_sha256(rawConnectionValue(con)))
}

# ---- paths ------------------------------------------------------------------

#' Validate a bundle-relative path
#'
#' Accepts forward-slash relative paths without `.`/`..`/empty segments,
#' drive letters, backslashes, NUL or leading `/` or `~`.
#' @noRd
.sg_check_relpath <- function(path, what = "path") {
  ok <- is.character(path) && length(path) == 1L && !is.na(path) &&
    nzchar(path)
  if (ok) {
    segs <- strsplit(path, "/", fixed = TRUE)[[1]]
    ok <- !grepl("^[/~]", path) &&
      !grepl("^[A-Za-z]:", path) &&
      !grepl("\\", path, fixed = TRUE) &&
      !grepl("[[:cntrl:]]", path) &&
      !grepl("/$", path) &&
      length(segs) > 0L &&
      all(nzchar(segs)) &&
      !any(segs %in% c(".", ".."))
  }
  if (!ok) {
    .sg_abort(
      "Unsafe {what}: only relative paths inside the bundle are allowed.",
      class = "sg_security_error", code = "PATH_OUTSIDE_ROOT",
      details = list(what = what)
    )
  }
  invisible(path)
}

#' Resolve a relative path inside a root directory, rejecting escapes
#' @noRd
.sg_resolve_in_root <- function(root, rel, must_exist = TRUE) {
  .sg_check_relpath(rel)
  root_n <- normalizePath(root, winslash = "/", mustWork = TRUE)
  full <- file.path(root_n, rel)
  if (file.exists(full)) {
    full_n <- normalizePath(full, winslash = "/", mustWork = TRUE)
    if (!startsWith(full_n, paste0(root_n, "/"))) {
      .sg_abort(
        "Resolved path leaves the bundle root (symbolic link escape).",
        class = "sg_security_error", code = "PATH_OUTSIDE_ROOT",
        details = list(path = rel)
      )
    }
    return(full_n)
  }
  if (must_exist) {
    .sg_abort("Declared file {.file {rel}} is missing.",
              class = "sg_integrity_error", code = "INTEGRITY_MISMATCH",
              details = list(path = rel, reason = "missing"))
  }
  full
}

#' List regular files below a root as sorted relative paths
#' @noRd
.sg_list_rel_files <- function(root) {
  # Manual walk: symbolic links are listed as entries (and rejected by the
  # callers that verify files) but never followed, so linked directories
  # cannot cause recursion loops or scans outside the root.
  out <- character(0)
  stack <- ""
  while (length(stack)) {
    rel <- stack[1]
    stack <- stack[-1]
    dir <- if (nzchar(rel)) file.path(root, rel) else root
    entries <- list.files(dir, all.files = TRUE, no.. = TRUE)
    for (e in entries) {
      r <- if (nzchar(rel)) paste(rel, e, sep = "/") else e
      full <- file.path(root, r)
      if (nzchar(Sys.readlink(full)) || !dir.exists(full)) {
        out <- c(out, r)
      } else {
        stack <- c(stack, r)
      }
    }
  }
  out[order(enc2utf8(out), method = "radix")]
}

# ---- versions ---------------------------------------------------------------

#' Parse a semantic version string
#' @noRd
.sg_semver <- function(x) {
  m <- regmatches(x, regexec(
    "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$",
    x
  ))[[1]]
  if (length(m) == 0L) {
    return(NULL)
  }
  list(major = as.integer(m[2]), minor = as.integer(m[3]),
       patch = as.integer(m[4]), prerelease = sub("^-", "", m[5]))
}

#' Major version of a schema family identifier such as "name-v1"
#' @noRd
.sg_family_major <- function(x) {
  m <- regmatches(x, regexec("-v([0-9]+)$", x))[[1]]
  if (length(m) == 0L) return(NA_integer_)
  as.integer(m[2])
}

# ---- runtime ----------------------------------------------------------------

#' Installed version of a package without attaching it, or NA
#' @noRd
.sg_pkg_version <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) return(NA_character_)
  as.character(utils::packageVersion(pkg))
}

#' Best-effort source revision of the installed segmantR
#'
#' Uses RemoteSha from remotes/pak installs, or the git HEAD of a source
#' tree loaded with pkgload. Never runs external programs.
#' @noRd
.sg_source_revision <- function() {
  desc <- tryCatch(utils::packageDescription("segmantR"),
                   error = function(e) NULL)
  sha <- desc$RemoteSha %||% desc$GithubSHA1
  if (!is.null(sha) && grepl("^[0-9a-f]{40}$", sha)) {
    return(list(revision = sha, dirty = "unknown", source = "RemoteSha"))
  }
  root <- system.file(package = "segmantR")
  if (nzchar(root) && basename(root) == "inst" &&
      !file.exists(file.path(root, ".git", "HEAD"))) {
    root <- dirname(root)
  }
  head_file <- file.path(root, ".git", "HEAD")
  if (nzchar(root) && file.exists(head_file)) {
    head <- trimws(readLines(head_file, n = 1L, warn = FALSE))
    rev <- head
    if (startsWith(head, "ref: ")) {
      ref <- sub("^ref: ", "", head)
      ref_file <- file.path(root, ".git", ref)
      rev <- if (file.exists(ref_file)) {
        trimws(readLines(ref_file, n = 1L, warn = FALSE))
      } else {
        packed <- file.path(root, ".git", "packed-refs")
        hit <- if (file.exists(packed)) {
          grep(paste0(" ", ref, "$"), readLines(packed, warn = FALSE),
               value = TRUE)
        } else {
          character(0)
        }
        if (length(hit)) sub(" .*$", "", hit[1]) else NA_character_
      }
    }
    if (!is.na(rev) && grepl("^[0-9a-f]{40}$", rev)) {
      return(list(revision = rev, dirty = "unknown", source = "git-head"))
    }
  }
  list(revision = NA_character_, dirty = "unknown", source = "unavailable")
}

#' Runtime description recorded in run envelopes and bundles
#'
#' Only reads package versions; never initialises Python.
#' @noRd
.sg_runtime <- function() {
  optional <- c("tiff", "sf", "EBImage", "reticulate", "nanoparquet",
                "openssl", "digest")
  list(
    language = "R",
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform = R.version$platform,
    segmantR_version = as.character(utils::packageVersion("segmantR")),
    segmantR_api_version = .sg_api_version,
    source_revision = .sg_source_revision(),
    packages = lapply(stats::setNames(optional, optional), .sg_pkg_version)
  )
}
