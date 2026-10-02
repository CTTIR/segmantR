decode_binary64_hex <- function(hex) {
  bytes <- as.raw(strtoi(substring(hex, seq(1L, 16L, 2L),
                                   seq(2L, 16L, 2L)), 16L))
  readBin(bytes, double(), n = 1L, size = 8L, endian = "little")
}

test_that("canonical numbers match independent exact binary64 Node vectors", {
  corpus <- jsonlite::read_json(test_path(
    "fixtures", "canonical-numbers", "ieee754.json"
  ))
  values <- vapply(corpus$vectors, function(x) decode_binary64_hex(x$hex),
                   numeric(1))
  expected <- vapply(corpus$vectors, `[[`, character(1), "expected")
  actual <- vapply(values, segmantR:::.sg_json_number, character(1))
  expect_identical(actual, expected)
})

test_that("canonical numbers and ties ignore the display decimal separator", {
  # Exact inputs avoid conflating the host R literal parser with serialization.
  values <- vapply(c("9a9999999999b93f", "039300aa4bdd4d7e",
                     "5709cbc1f33f1443"), decode_binary64_hex, numeric(1))
  expected <- c("0.1", "2.5e+300", "1424953923781205.8")
  for (separator in c(".", ",")) {
    actual <- withr::with_options(
      list(OutDec = separator),
      vapply(values, segmantR:::.sg_json_number, character(1))
    )
    expect_identical(unname(actual), expected)
  }
})
