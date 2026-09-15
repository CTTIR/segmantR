# TIFF IO against independent tifffile fixtures
# (data-raw/interop-fixtures/make_tiff_fixtures.py).

fixture_dir <- test_path("fixtures", "tiff")
expected <- jsonlite::read_json(file.path(fixture_dir, "expected.json"),
                                simplifyVector = FALSE)

as_matrix_row_major <- function(values, shape) {
  matrix(unlist(values), nrow = shape[[1]], ncol = shape[[2]], byrow = TRUE)
}

test_that("uncompressed integer TIFFs from tifffile read exactly", {
  for (name in c("labels_uint16_le.tif", "labels_uint16_be.tif",
                 "labels_uint32_le.tif", "labels_uint8_le.tif")) {
    e <- expected[[name]]
    tif <- segmantR:::.sg_read_tiff(file.path(fixture_dir, name))
    expect_equal(tif$dtype, e$dtype, info = name)
    expect_equal(tif$data, as_matrix_row_major(e$values_row_major, e$shape_yx),
                 info = name)
  }
})

test_that("compressed TIFF is decoded through the tiff package", {
  skip_if_not_installed("tiff")
  e <- expected[["labels_uint16_zlib.tif"]]
  tif <- segmantR:::.sg_read_tiff(file.path(fixture_dir,
                                            "labels_uint16_zlib.tif"))
  expect_equal(tif$dtype, "uint16")
  expect_equal(unname(tif$data), as_matrix_row_major(e$values_row_major,
                                                     e$shape_yx))
})

test_that("float TIFF is rejected as a label mask", {
  tif <- segmantR:::.sg_read_tiff(file.path(fixture_dir, "labels_float32.tif"))
  expect_equal(tif$dtype, "float32")
  err <- expect_error(segmantR:::.sg_labels_from_tiff(
    tif, NULL, segmantR:::.sg_checklist()), class = "sg_validation_error")
  expect_equal(err$code, "DTYPE_MISMATCH")
})

test_that("transposed shapes are reported as an orientation problem", {
  tif <- segmantR:::.sg_read_tiff(file.path(fixture_dir,
                                            "labels_uint16_le.tif"))
  err <- expect_error(segmantR:::.sg_labels_from_tiff(
    tif, c(9L, 6L), segmantR:::.sg_checklist()), class = "sg_validation_error")
  expect_equal(err$code, "DIMENSION_MISMATCH")
  expect_match(err$details$reason, "orientation")
})

test_that("multi-page float64 stack reads page by page", {
  e <- expected[["stack_float64_3d.tif"]]
  tif <- segmantR:::.sg_read_tiff(file.path(fixture_dir, "stack_float64_3d.tif"))
  shp <- unlist(e$shape_cyx)
  expect_equal(dim(tif$data), c(shp[2], shp[3], shp[1]))
  vals <- unlist(e$values_c_y_x)
  first_page <- matrix(vals[seq_len(shp[2] * shp[3])], shp[2], shp[3],
                       byrow = TRUE)
  expect_equal(tif$data[, , 1], first_page)
})

test_that("chunky multi-sample TIFF reads as [y, x, sample]", {
  e <- expected[["rgb_uint8_chunky.tif"]]
  tif <- segmantR:::.sg_read_tiff(file.path(fixture_dir, "rgb_uint8_chunky.tif"))
  shp <- unlist(e$shape_yxs)
  expect_equal(dim(tif$data), shp)
  expect_equal(tif$samples_per_pixel, 3)
  vals <- unlist(e$values_y_x_s)
  expect_equal(tif$data[1, 2, ], vals[4:6])
  expect_equal(tif$data[4, 5, 3], vals[length(vals)])
})

test_that("the writer produces TIFFs the tiff package reads identically", {
  skip_if_not_installed("tiff")
  lab <- matrix(c(0L, 1L, 70000L, 5L, 0L, 2L), 2, 3)
  f <- withr::local_tempfile(fileext = ".tif")
  segmantR:::.sg_write_tiff(lab, f, dtype = "uint32", description = "desc")
  expect_equal(unname(tiff::readTIFF(f, as.is = TRUE)), lab)
  back <- segmantR:::.sg_read_tiff(f)
  expect_equal(back$description, "desc")
  expect_equal(back$dtype, "uint32")
})

test_that("writer validates dtype ranges and integer values", {
  f <- withr::local_tempfile(fileext = ".tif")
  expect_error(segmantR:::.sg_write_tiff(matrix(300L, 1, 1), f, "uint8"),
               class = "sg_validation_error")
  expect_error(segmantR:::.sg_write_tiff(matrix(1.5, 1, 1), f, "uint16"),
               class = "sg_validation_error")
  expect_error(segmantR:::.sg_write_tiff(1:3, f), class = "sg_validation_error")
})

test_that("truncated and non-TIFF files are integrity errors", {
  src <- file.path(fixture_dir, "labels_uint16_le.tif")
  bytes <- readBin(src, "raw", file.info(src)$size)
  f <- withr::local_tempfile(fileext = ".tif")
  writeBin(bytes[1:40], f)
  expect_error(segmantR:::.sg_read_tiff(f), class = "sg_error")
  writeBin(charToRaw("not a tiff at all"), f)
  expect_error(segmantR:::.sg_read_tiff(f), class = "sg_integrity_error")
  writeBin(as.raw(c(0x49, 0x49, 0x2a, 0x00)), f)
  expect_error(segmantR:::.sg_read_tiff(f), class = "sg_integrity_error")
  writeBin(bytes[1:9], f)
  rep <- sg_import_interchange(f, error = FALSE)
  expect_false(rep$ok)
  expect_s3_class(rep$error, "sg_error")
})

test_that("OME-XML description carries shape, channels and pixel size", {
  xml <- segmantR:::.sg_ome_xml(c(4, 5), 2L, "uint16",
                                list(x = 0.5, y = 0.25), c("DAPI", "CD<3>"))
  expect_match(xml, "SizeX=\"5\" SizeY=\"4\" SizeC=\"2\"", fixed = TRUE)
  expect_match(xml, "PhysicalSizeX=\"0.5\"", fixed = TRUE)
  expect_match(xml, "CD&lt;3&gt;", fixed = TRUE)
})
