# Internal JSON Schema (draft-07 subset) validator driven by the schemas
# shipped under inst/schema/. References resolve only to local files inside
# that directory; no network access is ever attempted.
#
# Supported keywords: $ref, type, enum, const, required, properties,
# additionalProperties, patternProperties, items, minItems, maxItems,
# uniqueItems, minLength, maxLength, pattern, minimum, maximum,
# exclusiveMinimum, exclusiveMaximum, allOf, anyOf, oneOf, not,
# if/then/else. Annotation keywords ($schema, $id, title, description,
# default, examples, format, $comment) are ignored.

.sg_schema_cache <- new.env(parent = emptyenv())

#' Directory of an installed schema family
#' @noRd
.sg_schema_dir <- function(family = .sg_interchange_schema) {
  d <- system.file("schema", family, package = "segmantR")
  if (!nzchar(d)) {
    .sg_abort("Schema family {.val {family}} is not installed.",
              class = "sg_protocol_error", code = "SCHEMA_MISMATCH",
              details = list(family = family))
  }
  d
}

#' Load (and cache) one schema file of a family
#' @noRd
.sg_load_schema <- function(name, family = .sg_interchange_schema) {
  key <- paste(family, name, sep = "/")
  if (!is.null(.sg_schema_cache[[key]])) return(.sg_schema_cache[[key]])
  if (!grepl("^[a-z0-9-]+\\.schema\\.json$", name)) {
    .sg_abort("Invalid schema reference {.val {name}}.",
              class = "sg_security_error", code = "PATH_OUTSIDE_ROOT")
  }
  path <- file.path(.sg_schema_dir(family), name)
  if (!file.exists(path)) {
    .sg_abort("Schema {.val {name}} is not part of {.val {family}}.",
              class = "sg_protocol_error", code = "SCHEMA_MISMATCH",
              details = list(family = family, schema = name))
  }
  schema <- jsonlite::read_json(path, simplifyVector = FALSE)
  .sg_schema_cache[[key]] <- schema
  schema
}

#' Normalise an R value to the parsed-JSON representation
#' @noRd
.sg_as_json_value <- function(x) {
  jsonlite::parse_json(.sg_canonical_json(x), simplifyVector = FALSE)
}

#' Validate a value against a named schema; returns error strings
#' @param x Parsed JSON value or R value (normalised first).
#' @param name Schema file name, e.g. `"manifest.schema.json"`.
#' @noRd
.sg_schema_errors <- function(x, name, family = .sg_interchange_schema,
                              normalise = TRUE) {
  schema <- .sg_load_schema(name, family)
  if (normalise) x <- .sg_as_json_value(x)
  ctx <- list(family = family, file = name, depth = 0L)
  .sg_validate_node(x, schema, schema, ctx, "$")
}

#' Validate and abort with a classified error on failure
#' @noRd
.sg_schema_assert <- function(x, name, what = "document",
                              family = .sg_interchange_schema) {
  errs <- .sg_schema_errors(x, name, family)
  if (length(errs) > 0L) {
    shown <- utils::head(errs, 8L)
    .sg_abort(
      c("The {what} does not conform to {.file {name}}.",
        stats::setNames(.sg_cli_escape(shown), rep("x", length(shown)))),
      code = "VALIDATION_FAILED",
      details = list(schema = name, errors = errs)
    )
  }
  invisible(TRUE)
}

#' @noRd
.sg_json_type <- function(x) {
  if (is.null(x)) return("null")
  if (is.list(x)) {
    return(if (is.null(names(x))) "array" else "object")
  }
  if (length(x) != 1L) return("invalid")
  if (is.logical(x)) return(if (is.na(x)) "null" else "boolean")
  if (is.numeric(x)) return(if (is.na(x)) "null" else "number")
  if (is.character(x)) return(if (is.na(x)) "null" else "string")
  "invalid"
}

#' @noRd
.sg_type_matches <- function(x, type) {
  actual <- .sg_json_type(x)
  if (type == "integer") {
    return(actual == "number" && is.finite(x) && x == trunc(x))
  }
  actual == type
}

#' Resolve a local $ref to (schema, root, ctx)
#' @noRd
.sg_resolve_ref <- function(ref, root, ctx) {
  parts <- strsplit(ref, "#", fixed = TRUE)[[1]]
  file_part <- parts[1]
  pointer <- if (length(parts) > 1L) parts[2] else ""
  if (nzchar(file_part)) {
    if (grepl("://", file_part, fixed = TRUE) || grepl("/", file_part)) {
      .sg_abort("Remote or nested schema references are not allowed.",
                class = "sg_security_error", code = "PATH_OUTSIDE_ROOT",
                details = list(ref = ref))
    }
    root <- .sg_load_schema(file_part, ctx$family)
    ctx$file <- file_part
  }
  node <- root
  if (nzchar(pointer)) {
    tokens <- strsplit(sub("^/", "", pointer), "/", fixed = TRUE)[[1]]
    for (tok in tokens) {
      tok <- gsub("~1", "/", gsub("~0", "~", tok, fixed = TRUE), fixed = TRUE)
      node <- node[[tok]]
      if (is.null(node)) {
        .sg_abort("Unresolvable schema reference {.val {ref}}.",
                  class = "sg_protocol_error", code = "SCHEMA_MISMATCH",
                  details = list(ref = ref))
      }
    }
  }
  list(schema = node, root = root, ctx = ctx)
}

#' Recursive validation of one node
#' @noRd
.sg_validate_node <- function(x, schema, root, ctx, path) {
  if (isTRUE(schema)) return(character(0))
  if (isFALSE(schema)) return(paste0(path, ": no value is allowed here"))
  ctx$depth <- ctx$depth + 1L
  if (ctx$depth > 64L) {
    return(paste0(path, ": schema nesting too deep"))
  }
  errs <- character(0)

  if (!is.null(schema[["$ref"]])) {
    r <- .sg_resolve_ref(schema[["$ref"]], root, ctx)
    return(.sg_validate_node(x, r$schema, r$root, r$ctx, path))
  }

  if (!is.null(schema$type)) {
    types <- unlist(schema$type)
    if (!any(vapply(types, function(t) .sg_type_matches(x, t), logical(1)))) {
      return(paste0(path, ": expected ", paste(types, collapse = " or "),
                    ", got ", .sg_json_type(x)))
    }
  }

  if (!is.null(schema$enum)) {
    hit <- any(vapply(schema$enum, function(e) identical(
      .sg_canonical_json(e), .sg_canonical_json(x)
    ), logical(1)))
    if (!hit) {
      allowed <- paste(vapply(schema$enum, .sg_canonical_json, ""),
                       collapse = ", ")
      errs <- c(errs, paste0(path, ": value must be one of ", allowed))
    }
  }
  if ("const" %in% names(schema)) {
    if (!identical(.sg_canonical_json(schema$const), .sg_canonical_json(x))) {
      errs <- c(errs, paste0(path, ": value must equal ",
                             .sg_canonical_json(schema$const)))
    }
  }

  type <- .sg_json_type(x)
  if (type == "string") {
    n <- nchar(x, type = "chars")
    if (!is.null(schema$minLength) && n < schema$minLength) {
      errs <- c(errs, paste0(path, ": string shorter than ", schema$minLength))
    }
    if (!is.null(schema$maxLength) && n > schema$maxLength) {
      errs <- c(errs, paste0(path, ": string longer than ", schema$maxLength))
    }
    if (!is.null(schema$pattern) && !grepl(schema$pattern, x, perl = TRUE)) {
      errs <- c(errs, paste0(path, ": string does not match pattern ",
                             schema$pattern))
    }
  }
  if (type == "number") {
    if (!is.null(schema$minimum) && x < schema$minimum) {
      errs <- c(errs, paste0(path, ": must be >= ", schema$minimum))
    }
    if (!is.null(schema$maximum) && x > schema$maximum) {
      errs <- c(errs, paste0(path, ": must be <= ", schema$maximum))
    }
    if (!is.null(schema$exclusiveMinimum) && x <= schema$exclusiveMinimum) {
      errs <- c(errs, paste0(path, ": must be > ", schema$exclusiveMinimum))
    }
    if (!is.null(schema$exclusiveMaximum) && x >= schema$exclusiveMaximum) {
      errs <- c(errs, paste0(path, ": must be < ", schema$exclusiveMaximum))
    }
  }
  if (type == "array") {
    n <- length(x)
    if (!is.null(schema$minItems) && n < schema$minItems) {
      errs <- c(errs, paste0(path, ": needs at least ", schema$minItems,
                             " item(s)"))
    }
    if (!is.null(schema$maxItems) && n > schema$maxItems) {
      errs <- c(errs, paste0(path, ": allows at most ", schema$maxItems,
                             " item(s)"))
    }
    if (isTRUE(schema$uniqueItems) && n > 1L) {
      enc <- vapply(x, .sg_canonical_json, character(1))
      if (anyDuplicated(enc)) {
        errs <- c(errs, paste0(path, ": items must be unique"))
      }
    }
    if (!is.null(schema$items)) {
      for (i in seq_along(x)) {
        errs <- c(errs, .sg_validate_node(x[[i]], schema$items, root, ctx,
                                          paste0(path, "[", i - 1L, "]")))
      }
    }
  }
  if (type == "object") {
    keys <- names(x)
    for (req in unlist(schema$required)) {
      if (!req %in% keys) {
        errs <- c(errs, paste0(path, ": missing required field '", req, "'"))
      }
    }
    props <- schema$properties
    pat_props <- schema$patternProperties
    for (k in keys) {
      sub_path <- paste0(path, ".", k)
      matched <- FALSE
      if (!is.null(props) && k %in% names(props)) {
        matched <- TRUE
        errs <- c(errs, .sg_validate_node(x[[k]], props[[k]], root, ctx,
                                          sub_path))
      }
      if (!is.null(pat_props)) {
        for (p in names(pat_props)) {
          if (grepl(p, k, perl = TRUE)) {
            matched <- TRUE
            errs <- c(errs, .sg_validate_node(x[[k]], pat_props[[p]], root,
                                              ctx, sub_path))
          }
        }
      }
      if (!matched && !is.null(schema$additionalProperties)) {
        ap <- schema$additionalProperties
        if (isFALSE(ap)) {
          errs <- c(errs, paste0(path, ": unknown field '", k,
                                 "' (use 'extensions')"))
        } else if (is.list(ap)) {
          errs <- c(errs, .sg_validate_node(x[[k]], ap, root, ctx, sub_path))
        }
      }
    }
  }

  for (s in schema$allOf) {
    errs <- c(errs, .sg_validate_node(x, s, root, ctx, path))
  }
  if (!is.null(schema$anyOf)) {
    ok <- any(vapply(schema$anyOf, function(s) {
      length(.sg_validate_node(x, s, root, ctx, path)) == 0L
    }, logical(1)))
    if (!ok) errs <- c(errs, paste0(path, ": does not match any allowed form"))
  }
  if (!is.null(schema$oneOf)) {
    n_ok <- sum(vapply(schema$oneOf, function(s) {
      length(.sg_validate_node(x, s, root, ctx, path)) == 0L
    }, logical(1)))
    if (n_ok != 1L) {
      errs <- c(errs, paste0(path, ": must match exactly one allowed form"))
    }
  }
  if (!is.null(schema[["not"]])) {
    if (length(.sg_validate_node(x, schema[["not"]], root, ctx, path)) == 0L) {
      errs <- c(errs, paste0(path, ": matches a forbidden form"))
    }
  }
  if (!is.null(schema[["if"]])) {
    cond <- length(.sg_validate_node(x, schema[["if"]], root, ctx, path)) == 0L
    branch <- if (cond) schema[["then"]] else schema[["else"]]
    if (!is.null(branch)) {
      errs <- c(errs, .sg_validate_node(x, branch, root, ctx, path))
    }
  }
  errs
}
