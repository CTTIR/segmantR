test_that("every shipped schema is valid JSON and resolves its references", {
  dir <- system.file("schema", "segmantR-interchange-v1", package = "segmantR")
  files <- list.files(dir, pattern = "\\.schema\\.json$")
  expect_gte(length(files), 14L)
  for (f in files) {
    s <- jsonlite::read_json(file.path(dir, f), simplifyVector = FALSE)
    expect_true(is.list(s), info = f)
    refs <- unique(unlist(rapply(s, function(x) x, how = "unlist")[
      grepl("\\$ref$", names(rapply(s, function(x) x, how = "unlist")))]))
    for (r in refs) {
      expect_silent(segmantR:::.sg_resolve_ref(r, s, list(family =
        "segmantR-interchange-v1", file = f, depth = 0L)))
    }
  }
})

test_that("validator implements the draft-07 keywords used by the schemas", {
  v <- function(x, schema) {
    segmantR:::.sg_validate_node(x, schema, schema,
                                 list(family = "segmantR-interchange-v1",
                                      depth = 0L), "$")
  }
  expect_length(v(3L, list(type = "integer", minimum = 1)), 0L)
  expect_length(v(1.5, list(type = "integer")), 1L)
  expect_length(v("ab", list(type = "string", pattern = "^a", maxLength = 1)), 1L)
  expect_length(v(list(a = 1), list(type = "object", required = list("b"))), 1L)
  expect_length(v(list(a = 1), list(type = "object", properties = list(),
                                    additionalProperties = FALSE)), 1L)
  expect_length(v(list(1, 1), list(type = "array", uniqueItems = TRUE)), 1L)
  expect_length(v("x", list(enum = list("x", "y"))), 0L)
  expect_length(v(NULL, list(type = list("string", "null"))), 0L)
  expect_length(v(2, list(oneOf = list(list(type = "number"),
                                       list(type = "integer")))), 1L)
  expect_length(v(list(k = "finite", value = NULL), list(
    `if` = list(properties = list(k = list(const = "finite"))),
    then = list(properties = list(value = list(type = "number"))))), 1L)
})

test_that("remote references are refused", {
  expect_error(
    segmantR:::.sg_resolve_ref("https://example.org/x.schema.json#/a", list(),
                               list(family = "segmantR-interchange-v1")),
    class = "sg_security_error"
  )
  expect_error(segmantR:::.sg_load_schema("../evil.schema.json"),
               class = "sg_security_error")
})

test_that("schema assertion signals a classified validation error", {
  err <- expect_error(
    segmantR:::.sg_schema_assert(list(format_version = "2.0", files = list()),
                                 "integrity.schema.json"),
    class = "sg_validation_error"
  )
  expect_equal(err$code, "VALIDATION_FAILED")
  expect_true(any(grepl("format_version", err$details$errors)))
})
