# Band selection and ENVI reading with values defined by formulas.

cube_value <- function(r, c, b) 100 * b + 10 * r + c  # 1-based r, c, b

write_envi <- function(dir, interleave = "bsq", byte_order = 0L,
                       data_type = 12L, lines = 3L, samples = 4L, bands = 2L,
                       header_extra = character(0), truncate = 0L,
                       wavelengths = c(500, 600)) {
  vals <- switch(
    interleave,
    bsq = unlist(lapply(seq_len(bands), function(b) {
      unlist(lapply(seq_len(lines), function(r) cube_value(r, seq_len(samples), b)))
    })),
    bil = unlist(lapply(seq_len(lines), function(r) {
      unlist(lapply(seq_len(bands), function(b) cube_value(r, seq_len(samples), b)))
    })),
    bip = unlist(lapply(seq_len(lines), function(r) {
      unlist(lapply(seq_len(samples), function(c) cube_value(r, c, seq_len(bands))))
    }))
  )
  size <- c(`12` = 2L, `4` = 4L, `2` = 2L)[[as.character(data_type)]]
  endian <- if (byte_order == 1L) "big" else "little"
  con <- rawConnection(raw(0), "wb")
  if (data_type == 4L) {
    writeBin(as.double(vals), con, size = 4L, endian = endian)
  } else {
    writeBin(as.integer(vals), con, size = size, endian = endian)
  }
  bytes <- rawConnectionValue(con)
  close(con)
  if (truncate > 0L) bytes <- bytes[seq_len(length(bytes) - truncate)]
  writeBin(bytes, file.path(dir, "cube"))
  writeLines(c("ENVI", sprintf("samples = %d", samples),
               sprintf("lines = %d", lines), sprintf("bands = %d", bands),
               "header offset = 0", sprintf("data type = %d", data_type),
               sprintf("interleave = %s", interleave),
               sprintf("byte order = %d", byte_order),
               sprintf("wavelength = {%s}", paste(wavelengths, collapse = ", ")),
               "wavelength units = Nanometers",
               header_extra),
             file.path(dir, "cube.hdr"))
  file.path(dir, "cube.hdr")
}

test_that("ENVI BSQ, BIL and BIP in both byte orders read exactly", {
  expected <- array(0, c(3, 4, 2))
  for (b in 1:2) for (r in 1:3) expected[r, , b] <- cube_value(r, 1:4, b)
  for (il in c("bsq", "bil", "bip")) {
    for (bo in 0:1) {
      d <- withr::local_tempdir()
      hdr <- write_envi(d, interleave = il, byte_order = bo)
      img <- sg_read_envi(hdr, value_semantics = "raw")
      expect_equal(img$pixels, expected, info = paste(il, bo))
      expect_equal(img$bands$wavelength_nm, c(500, 600))
      expect_equal(img$value_semantics, "raw")
    }
  }
})

test_that("windowed, band-subset reads account for the bytes read", {
  d <- withr::local_tempdir()
  hdr <- write_envi(d, interleave = "bil", lines = 5L, samples = 6L,
                    bands = 3L, wavelengths = c(450, 550, 650))
  img <- sg_read_envi(hdr, bands = c(3L, 1L), window = c(2L, 4L, 3L, 5L))
  expect_equal(dim(img$pixels), c(3L, 3L, 2L))
  expect_equal(img$pixels[1, 1, 1], cube_value(2, 3, 3))
  expect_equal(img$pixels[3, 3, 2], cube_value(4, 5, 1))
  expect_equal(img$origin$x, 2)
  expect_equal(img$origin$y, 1)
  acc <- img$metadata$read_accounting
  expect_equal(acc$bytes_read, 3L * 3L * 2L * 2L)
  expect_equal(acc$bands_read, c(2L, 0L))
  expect_equal(img$bands$wavelength_nm, c(650, 450))
  expect_match(img$metadata$calibration_digest, "^sha256:")
})

test_that("ENVI headers are validated before any pixel data is read", {
  d <- withr::local_tempdir()
  hdr <- write_envi(d, truncate = 3L)
  expect_error(sg_read_envi(hdr), class = "sg_integrity_error")
  d2 <- withr::local_tempdir()
  hdr2 <- write_envi(d2, wavelengths = c(500, 600, 700))
  expect_error(sg_envi_info(hdr2), "wavelength")
  d3 <- withr::local_tempdir()
  hdr3 <- write_envi(d3)
  lines <- readLines(hdr3)
  writeLines(sub("interleave = bsq", "interleave = xyz", lines), hdr3)
  expect_error(sg_envi_info(hdr3), "interleave")
  writeLines(sub("data type = 12", "data type = 6", lines), hdr3)
  expect_error(sg_envi_info(hdr3), class = "sg_capability_error")
  writeLines(c("NOT ENVI", lines[-1]), hdr3)
  expect_error(sg_envi_info(hdr3), "ENVI")
})

test_that("ENVI nodata, scale factors and micrometre wavelengths", {
  d <- withr::local_tempdir()
  hdr <- write_envi(d, header_extra = c(
    sprintf("data ignore value = %d", cube_value(1, 1, 1)),
    "reflectance scale factor = 10000"
  ), wavelengths = c(0.5, 0.6))
  writeLines(sub("Nanometers", "Micrometers", readLines(hdr)), hdr)
  img <- sg_read_envi(hdr, value_semantics = "reflectance")
  expect_true(is.na(img$pixels[1, 1, 1]))
  expect_equal(img$metadata$nodata_pixels, 1L)
  expect_equal(img$metadata$scale_factor, 10000)
  expect_equal(img$pixels[1, 2, 1], cube_value(1, 2, 1))
  expect_equal(img$bands$wavelength_nm, c(500, 600))
  info <- sg_envi_info(hdr)
  expect_s3_class(info, "sg_envi_info")
  expect_false(grepl("/", info$data_name))
})

test_that("registered band operations compute exact values", {
  arr <- array(c(rep(2, 4), rep(6, 4), rep(0, 4)), c(2, 2, 3))
  img <- new_sg_image(arr, channels = c("a", "b", "c"),
                      bands = data.frame(wavelength_nm = c(500, 600, 700)),
                      value_semantics = "reflectance")
  expect_equal(sg_select_channel(img, band_operation = "band_mean",
                                 band_min_nm = 450,
                                 band_max_nm = 650)$pixels,
               matrix(4, 2, 2))
  nd <- sg_select_channel(img, band_operation = "normalized_difference",
                          band_a_nm = 600, band_b_nm = 500)
  expect_equal(nd$pixels, matrix(0.5, 2, 2))
  expect_equal(nd$provenance$band_selection$c, c(1L, 0L))
  expect_equal(nd$value_semantics, "unknown")
  partial <- img
  partial$pixels[, , 3] <- matrix(c(0, 0, 1, 4), 2, 2)
  r <- sg_select_channel(partial, band_operation = "ratio", band_a_nm = 500,
                         band_b_nm = 700)
  expect_equal(r$provenance$band_selection$non_finite_replaced, 2L)
  expect_equal(r$pixels, matrix(c(0.5, 0.5, 2, 0.5), 2, 2))
  expect_error(sg_select_channel(img, band_operation = "ratio",
                                 band_a_nm = 500, band_b_nm = 700),
               "no finite")
  unknown <- img
  unknown$value_semantics <- "unknown"
  expect_error(sg_select_channel(unknown, band_operation = "ratio",
                                 band_a_nm = 500, band_b_nm = 600),
               "value semantics")
  expect_error(sg_select_channel(img, wavelength_nm = 540), "No band within")
  expect_error(sg_select_channel(img, wavelength_nm = 550), "ambiguous")
  expect_equal(sg_select_channel(img, channel_name = "c")$channels, "c")
  expect_error(sg_select_channel(img, channel = 4L), "out of range")
  plain <- new_sg_image(arr)
  expect_error(sg_select_channel(plain, wavelength_nm = 500), "wavelengths")
})
