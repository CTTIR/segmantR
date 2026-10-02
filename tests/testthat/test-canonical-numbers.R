test_that("canonical numbers match independent exact binary64 Node vectors", {
  corpus <- jsonlite::read_json(test_path(
    "fixtures", "canonical-numbers", "ieee754.json"
  ))
  decode <- function(hex) {
    bytes <- as.raw(strtoi(substring(hex, seq(1L, 16L, 2L),
                                     seq(2L, 16L, 2L)), 16L))
    readBin(bytes, double(), n = 1L, size = 8L, endian = "little")
  }
  values <- vapply(corpus$vectors, function(x) decode(x$hex), numeric(1))
  expected <- vapply(corpus$vectors, `[[`, character(1), "expected")
  actual <- vapply(values, segmantR:::.sg_json_number, character(1))
  expect_identical(actual, expected)
})

test_that("canonical numbers ignore the display decimal separator", {
  withr::local_options(OutDec = ",")
  expect_identical(segmantR:::.sg_json_number(0.1), "0.1")
  expect_identical(segmantR:::.sg_json_number(2.5e300), "2.5e+300")
})
