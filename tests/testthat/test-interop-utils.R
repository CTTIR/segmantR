# Canonical JSON, hashing, paths and identifiers. Reference vectors in
# fixtures/digest/vectors.json come from Node's JSON.stringify and crypto
# (data-raw/interop-fixtures/make_digest_vectors.js) and were cross-checked
# with Python json/hashlib for the integrity rule.

vectors <- jsonlite::read_json(test_path("fixtures", "digest", "vectors.json"),
                               simplifyVector = FALSE)

test_that("canonical JSON matches independent Node reference vectors", {
  nums <- vapply(vectors$numbers$value, as.numeric, numeric(1))
  expect_identical(segmantR:::.sg_canonical_json(I(nums)),
                   vectors$numbers$canonical)
  strs <- vapply(vectors$strings$value, as.character, character(1))
  expect_identical(segmantR:::.sg_canonical_json(I(strs)),
                   vectors$strings$canonical)
  for (case in c("object", "integrity", "empty")) {
    v <- vectors[[case]]
    expect_identical(segmantR:::.sg_canonical_json(v$value), v$canonical,
                     info = case)
    expect_identical(segmantR:::.sg_sha256(v$canonical), v$sha256, info = case)
  }
})

test_that("SHA-256 agrees with the FIPS test vector", {
  expect_identical(
    segmantR:::.sg_sha256(charToRaw("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  f <- withr::local_tempfile()
  writeBin(charToRaw("abc"), f)
  expect_identical(segmantR:::.sg_sha256_file(f),
                   segmantR:::.sg_sha256(charToRaw("abc")))
})

test_that("canonical JSON refuses non-finite numbers and duplicate keys", {
  expect_error(segmantR:::.sg_canonical_json(list(a = NaN)), class = "sg_error")
  expect_error(segmantR:::.sg_canonical_json(Inf), class = "sg_validation_error")
  expect_error(segmantR:::.sg_canonical_json(stats::setNames(list(1, 2),
                                                             c("a", "a"))),
               class = "sg_validation_error")
  expect_identical(segmantR:::.sg_canonical_json(list(a = NA, b = NULL)),
                   "{\"a\":null,\"b\":null}")
})

test_that("array digests are row-major and dimension aware", {
  m <- matrix(1:6, nrow = 2)
  expected <- segmantR:::.sg_sha256(c(
    writeBin(c(2L, 3L), raw(), size = 4, endian = "little"),
    writeBin(c(1L, 3L, 5L, 2L, 4L, 6L), raw(), size = 4, endian = "little")
  ))
  expect_identical(segmantR:::.sg_array_digest(m), paste0("sha256:", expected))
  expect_false(identical(segmantR:::.sg_array_digest(m),
                         segmantR:::.sg_array_digest(t(m))))
})

test_that("relative path checks reject traversal and absolute paths", {
  ok <- c("a.txt", "dir/b.tif", "x/y/z.json")
  for (p in ok) expect_invisible(segmantR:::.sg_check_relpath(p))
  bad <- c("../a", "a/../b", "/etc/passwd", "~/x", "C:/x", "a\\b", "a//b",
           "./a", "a/", "")
  for (p in bad) {
    expect_error(segmantR:::.sg_check_relpath(p), class = "sg_security_error",
                 info = p)
  }
})

test_that("resolving inside a root rejects symbolic-link escapes", {
  skip_on_os("windows")
  root <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  writeLines("secret", file.path(outside, "s.txt"))
  file.symlink(file.path(outside, "s.txt"), file.path(root, "link.txt"))
  expect_error(segmantR:::.sg_resolve_in_root(root, "link.txt"),
               class = "sg_security_error")
})

test_that("deterministic UUID-shaped ids and run ids", {
  a <- segmantR:::.sg_uuid_from_key(c("img", 1))
  expect_identical(a, segmantR:::.sg_uuid_from_key(c("img", 1)))
  expect_match(a, "^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
  withr::local_seed(1)
  before <- stats::runif(1)
  withr::local_seed(1)
  r1 <- segmantR:::.sg_new_run_id()
  expect_identical(stats::runif(1), before)
  expect_false(identical(r1, segmantR:::.sg_new_run_id()))
})

test_that("semantic versions and schema family majors parse", {
  expect_equal(segmantR:::.sg_semver("1.2.3")$minor, 2L)
  expect_null(segmantR:::.sg_semver("1.2"))
  expect_equal(segmantR:::.sg_family_major("segmantR-protocol-v12"), 12L)
  expect_true(is.na(segmantR:::.sg_family_major("nope")))
})

test_that("runtime description never touches Python", {
  rt <- segmantR:::.sg_runtime()
  expect_equal(rt$language, "R")
  expect_true("reticulate" %in% names(rt$packages))
  expect_length(segmantR:::.sg_schema_errors(
    c(rt, list(schema = "segmantR-interchange-v1", kind = "runtime")),
    "runtime.schema.json"), 0L)
})
