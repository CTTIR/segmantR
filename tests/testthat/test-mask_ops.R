two_cell_mask <- function() {
  labels <- matrix(0L, 20L, 20L)
  labels[3:5, 3:5] <- 1L     # area 9
  labels[10:18, 10:18] <- 2L # area 81
  new_sg_mask(labels)
}

test_that("sg_filter_cells removes cells outside size limits", {
  mask <- two_cell_mask()
  filt <- sg_filter_cells(mask, min_area = 50L, max_area = 5000L,
                          min_circularity = 0, max_eccentricity = 1)
  expect_lte(filt$n_cells, mask$n_cells)
  expect_true(all(filt$labels[3:5, 3:5] == 0L))
})

test_that("sg_filter_cells passes through empty masks", {
  mask <- new_sg_mask(matrix(0L, 5L, 5L))
  expect_equal(sg_filter_cells(mask)$n_cells, 0L)
})

test_that("sg_filter_cells removes border cells when requested", {
  labels <- matrix(0L, 20, 20)
  labels[1:5, 1:5] <- 1L      # touches the border
  labels[10:14, 10:14] <- 2L  # interior
  mask <- new_sg_mask(labels)
  filt <- sg_filter_cells(mask, min_area = 1L, min_circularity = 0,
                          border_cells = "remove")
  expect_true(all(filt$labels[1:5, 1:5] == 0L))
})

test_that("sg_filter_cells flags border cells", {
  labels <- matrix(0L, 20, 20)
  labels[1:5, 1:5] <- 1L
  labels[10:14, 10:14] <- 2L
  mask <- new_sg_mask(labels)
  filt <- sg_filter_cells(mask, min_area = 1L, min_circularity = 0,
                          border_cells = "flag")
  expect_true(!is.null(filt$border_cell_ids))
  expect_true(1L %in% filt$border_cell_ids)
})

test_that("sg_filter_cells validates its mask argument", {
  expect_error(sg_filter_cells("not a mask"), "sg_mask")
})

test_that("sg_merge_masks assigns nuclei to overlapping cells", {
  nuc <- matrix(0L, 20, 20); nuc[5:7, 5:7] <- 1L; nuc[14:16, 14:16] <- 2L
  cel <- matrix(0L, 20, 20); cel[3:9, 3:9] <- 1L; cel[12:18, 12:18] <- 2L
  merged <- sg_merge_masks(new_sg_mask(nuc), new_sg_mask(cel))
  expect_named(merged, c("nuclear", "cell"))
  expect_s3_class(merged$nuclear, "sg_mask")
})

test_that("sg_merge_masks expand method grows cells", {
  nuc <- matrix(0L, 20, 20); nuc[5:7, 5:7] <- 1L; nuc[14:16, 14:16] <- 2L
  cel <- matrix(0L, 20, 20); cel[3:9, 3:9] <- 1L; cel[12:18, 12:18] <- 2L
  merged <- sg_merge_masks(new_sg_mask(nuc), new_sg_mask(cel),
                           method = "expand")
  expect_gte(sum(merged$cell$labels > 0L), sum(nuc > 0L))
})

test_that("sg_merge_masks validates inputs and dims", {
  m <- new_sg_mask(matrix(0L, 4, 4))
  expect_error(sg_merge_masks("x", m), "nuclear_mask")
  expect_error(sg_merge_masks(m, "y"), "cell_mask")
  expect_error(
    sg_merge_masks(new_sg_mask(matrix(0L, 4, 4)), new_sg_mask(matrix(0L, 5, 5))),
    "same dimensions"
  )
})

test_that("sg_mask_to_polygons returns coordinates without sf", {
  # Force the no-sf fallback regardless of whether sf is installed.
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (pkg == "sf") FALSE else TRUE,
    .package = "base"
  )
  mask <- two_cell_mask()
  polys <- sg_mask_to_polygons(mask, simplify = FALSE)
  expect_s3_class(polys, "tbl_df")
  expect_true(all(c("cell_id", "row", "col") %in% names(polys)))
})

test_that("sg_mask_to_polygons returns sf when available", {
  skip_if_not_installed("sf")
  mask <- two_cell_mask()
  polys <- sg_mask_to_polygons(mask, simplify = TRUE, tolerance = 1)
  expect_s3_class(polys, "sf")
})

test_that("sg_mask_to_polygons handles empty masks", {
  polys <- sg_mask_to_polygons(new_sg_mask(matrix(0L, 5, 5)))
  expect_equal(nrow(polys), 0L)
})

test_that("sg_mask_to_polygons validates its mask argument", {
  expect_error(sg_mask_to_polygons("x"), "sg_mask")
})

test_that("sg_export_mask writes CSV", {
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".csv")
  out <- sg_export_mask(mask, tmp, format = "csv")
  expect_equal(out, tmp)
  expect_true(file.exists(tmp))
  df <- utils::read.csv(tmp)
  expect_true("cell_id" %in% names(df))
})

test_that("sg_export_mask writes a QuPath GeoJSON", {
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".json")
  sg_export_mask(mask, tmp, format = "qupath")
  parsed <- jsonlite::read_json(tmp)
  expect_equal(parsed$type, "FeatureCollection")
})

test_that("sg_export_mask writes GeoJSON via sf when available", {
  skip_if_not_installed("sf")
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".geojson")
  sg_export_mask(mask, tmp, format = "geojson")
  expect_true(file.exists(tmp))
})

test_that("sg_export_mask writes GeoJSON as JSON without sf", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (pkg == "sf") FALSE else TRUE,
    .package = "base"
  )
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".json")
  sg_export_mask(mask, tmp, format = "geojson")
  expect_true(file.exists(tmp))
})

test_that("sg_export_mask writes a PNG", {
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".png")
  sg_export_mask(mask, tmp, format = "png")
  expect_true(file.exists(tmp))
})

test_that("sg_export_mask writes a TIFF when tiff is available", {
  skip_if_not_installed("tiff")
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".tiff")
  sg_export_mask(mask, tmp, format = "tiff")
  expect_true(file.exists(tmp))
})

test_that("sg_export_mask errors without tiff for tiff format", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (pkg == "tiff") FALSE else TRUE,
    .package = "base"
  )
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".tiff")
  expect_error(sg_export_mask(mask, tmp, format = "tiff"), "tiff")
})

test_that("sg_export_mask creates the output directory if needed", {
  mask <- two_cell_mask()
  base <- withr::local_tempdir()
  tmp <- file.path(base, "nested", "dir", "mask.csv")
  sg_export_mask(mask, tmp, format = "csv")
  expect_true(file.exists(tmp))
})

test_that("sg_export_mask validates its mask argument", {
  expect_error(sg_export_mask("x", tempfile()), "sg_mask")
})

test_that("sg_export_mask CSV content is reproducible", {
  mask <- two_cell_mask()
  tmp <- withr::local_tempfile(fileext = ".csv")
  sg_export_mask(mask, tmp, format = "csv")
  expect_snapshot_value(utils::read.csv(tmp)$area, style = "serialize")
})
