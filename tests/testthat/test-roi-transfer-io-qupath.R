test_that("QuPath colorRGB encodes as a signed 32-bit int (negative case)", {
  expect_identical(.sg_roi_hex_to_signed_int("#FFFFFF"), -1L)
  expect_true(.sg_roi_hex_to_signed_int("#E69F00") < 0L)
  # round-trips
  for (h in c("#E69F00", "#56B4E9", "#000000", "#FFFFFF", "#5E2C8E")) {
    expect_identical(toupper(.sg_roi_signed_int_to_hex(.sg_roi_hex_to_signed_int(h))), toupper(h))
  }
})

test_that("QuPath round-trip preserves classification names and colours", {
  proj <- demo_project()
  p <- withr::local_tempfile(fileext = ".geojson")
  sg_roi_write_qupath(proj, p)
  lyr <- sg_roi_read_qupath(p)
  expect_setequal(unique(vapply(lyr$rois, `[[`, character(1), "label")),
                  c("tissue", "tumour"))
  # A recovered colour maps back to a valid hex.
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", lyr$style$colour)))
})

test_that("QuPath reader handles null classification", {
  p <- withr::local_tempfile(fileext = ".geojson")
  fc <- list(type = "FeatureCollection", features = list(list(
    type = "Feature", id = "x",
    geometry = list(type = "Polygon",
                    coordinates = list(list(c(0, 0), c(5, 0), c(5, 5), c(0, 5), c(0, 0)))),
    properties = list(classification = NULL, object_type = "annotation")
  )))
  jsonlite::write_json(fc, p, auto_unbox = TRUE, null = "null")
  lyr <- sg_roi_read_qupath(p)
  expect_identical(lyr$rois[[1]]$label, "unclassified")
})

test_that("QuPath detections map object_type through", {
  lyr <- sg_roi_layer_add(sg_roi_layer("l"),
                      sg_roi_rect(0, 0, 5, 5, label = "cell", source = "mask"))
  proj <- sg_roi_project(small_image(), lyr)
  p <- withr::local_tempfile(fileext = ".geojson")
  sg_roi_write_qupath(proj, p)
  fc <- jsonlite::read_json(p, simplifyVector = FALSE)
  expect_identical(fc$features[[1]]$properties$objectType, "detection")
  p2 <- withr::local_tempfile(fileext = ".geojson")
  sg_roi_write_qupath(proj, p2, dialect = "legacy")
  fc2 <- jsonlite::read_json(p2, simplifyVector = FALSE)
  expect_identical(fc2$features[[1]]$properties$object_type, "detection")
})
