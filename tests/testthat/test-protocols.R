test_that("the registry lists all required protocols with valid definitions", {
  lst <- sg_protocol_list()
  required <- c("threshold.otsu.v1", "threshold.adaptive.v1",
                "threshold.triangle.v1", "watershed.distance.v1",
                "watershed.h_minima.v1", "propagate.voronoi.v1",
                "postprocess.label-cleanup.v1", "stardist.2d.v1",
                "cellpose.2d.v1", "mesmer.2d.v1")
  expect_setequal(lst$id, required)
  expect_true(all(lst$status[lst$requires_python] == "optional"))
  expect_true(all(is.na(lst$available[lst$requires_python])))
  expect_true(all(lst$available[!lst$requires_python]))
  expect_true(all(grepl("^sha256:[0-9a-f]{64}$", lst$digest)))
  dir <- system.file("protocols", package = "segmantR")
  for (id in required) {
    doc <- jsonlite::read_json(file.path(dir, paste0(id, ".json")),
                               simplifyVector = FALSE)
    expect_length(segmantR:::.sg_schema_errors(doc, "protocol.schema.json",
                                               normalise = FALSE), 0L)
    for (key in c("input_contract", "preprocess", "method", "postprocess",
                  "tiling", "output_contract", "runtime_profile",
                  "seed_policy", "provenance_policy")) {
      expect_false(is.null(doc[[key]]), info = paste(id, key))
    }
  }
})

test_that("protocol defaults equal the direct function defaults", {
  # eval() only evaluates the package's own formal default expressions here.
  p <- sg_protocol_get("threshold.otsu.v1")
  f <- formals(sg_segment_threshold)
  expect_equal(p$parameters$min_area$default, eval(f$min_area))
  expect_equal(p$parameters$max_area$default, eval(f$max_area))
  expect_equal(p$parameters$open_size$default, eval(f$morphology)$open)
  w <- sg_protocol_get("watershed.distance.v1")
  fw <- formals(sg_segment_watershed)
  expect_equal(w$parameters$h$default, eval(fw$h))
  expect_equal(w$parameters$expand_pixels$default, eval(fw$expand_pixels))
  s <- sg_protocol_get("stardist.2d.v1")
  fs <- formals(sg_segment_stardist)
  expect_equal(s$parameters$prob_thresh$default, eval(fs$prob_thresh))
  expect_equal(s$parameters$nms_thresh$default, eval(fs$nms_thresh))
})

test_that("get, schema and digest are stable", {
  p <- sg_protocol_get("watershed.h_minima.v1")
  expect_s3_class(p, "sg_protocol")
  expect_identical(segmantR:::.sg_protocol_digest(p),
                   segmantR:::.sg_protocol_digest(
                     sg_protocol_get("watershed.h_minima.v1")))
  tab <- sg_protocol_schema("postprocess.label-cleanup.v1")
  expect_true(all(c("min_area_um2", "connectivity") %in% tab$name))
  expect_true(tab$requires_calibration[tab$name == "min_area_um2"])
  expect_equal(sg_protocol_schema()$properties$schema$const,
               "segmantR-protocol-v1")
  err <- expect_error(sg_protocol_get("nope.v1"), class = "sg_protocol_error")
  expect_equal(err$code, "PROTOCOL_NOT_FOUND")
  err <- expect_error(sg_protocol_get("threshold.otsu.v1", "2.0.0"),
                      class = "sg_protocol_error")
  expect_equal(err$code, "PROTOCOL_MISMATCH")
})

test_that("unknown majors, bad versions and invalid definitions are refused", {
  def <- unclass(sg_protocol_get("threshold.otsu.v1"))
  v2 <- def
  v2$schema <- "segmantR-protocol-v2"
  err <- expect_error(sg_protocol_validate(v2), class = "sg_protocol_error")
  expect_equal(err$code, "PROTOCOL_MISMATCH")
  bad_ver <- def
  bad_ver$version <- "2.0.0"
  expect_error(sg_protocol_validate(bad_ver), class = "sg_protocol_error")
  not_semver <- def
  not_semver$version <- "1.0"
  expect_error(sg_protocol_validate(not_semver), class = "sg_validation_error")
  missing <- def
  missing$tiling <- NULL
  err <- expect_error(sg_protocol_validate(missing),
                      class = "sg_validation_error")
  expect_true(any(grepl("tiling", err$details$errors)))
  code <- def
  code$method$delegate <- "system"
  expect_error(sg_protocol_validate(code), class = "sg_validation_error")
  unmapped <- def
  unmapped$parameters$extra <- list(type = "integer", default = 1L,
                                    unit = "px",
                                    requires_calibration = FALSE,
                                    description = "not mapped")
  expect_error(sg_protocol_validate(unmapped), "neither mapped")
  bad_default <- def
  bad_default$parameters$min_area$default <- -5L
  expect_error(sg_protocol_validate(bad_default), "Default of parameter")
})

test_that("protocols can be given as JSON text or JSON file", {
  def <- unclass(sg_protocol_get("threshold.triangle.v1"))
  json <- segmantR:::.sg_canonical_json(def)
  expect_true(sg_protocol_validate(json)$ok)
  f <- withr::local_tempfile(fileext = ".json")
  writeLines(json, f)
  expect_true(sg_protocol_validate(f)$ok)
})

test_that("parameter validation rejects unknown names and bad values", {
  img <- sg_example_image("fluorescence_nuclei")
  err <- expect_error(sg_protocol_validate("threshold.otsu.v1", img, foo = 1),
                      class = "sg_validation_error")
  expect_equal(err$code, "UNKNOWN_PARAMETER")
  bad <- list(min_area = -1L, open_size = 4L, fill_holes = "yes",
              block_size = 2L)
  expect_equal(sg_protocol_validate("threshold.otsu.v1", img, min_area = -1L,
                                    error = FALSE)$error$code,
               "PARAMETER_OUT_OF_RANGE")
  expect_equal(sg_protocol_validate("threshold.otsu.v1", img, open_size = 4L,
                                    error = FALSE)$error$code,
               "PARAMETER_OUT_OF_RANGE")
  expect_equal(sg_protocol_validate("threshold.otsu.v1", img,
                                    fill_holes = "yes",
                                    error = FALSE)$error$code,
               "PARAMETER_OUT_OF_RANGE")
  expect_equal(sg_protocol_validate("threshold.adaptive.v1", img,
                                    block_size = 2L,
                                    error = FALSE)$error$code,
               "PARAMETER_OUT_OF_RANGE")
  expect_equal(sg_protocol_validate("threshold.otsu.v1", img, min_area = 60L,
                                    max_area = 50L, error = FALSE)$error$code,
               "PARAMETER_OUT_OF_RANGE")
  expect_error(sg_protocol_validate("threshold.otsu.v1", img, channel = 1L,
                                    channel_name = "DAPI"),
               "Ambiguous")
  expect_error(sg_protocol_validate("threshold.otsu.v1", img,
                                    channel_name = "DAPI", wavelength_nm = 400),
               "either")
})

test_that("input contracts check shape, semantics, channels and calibration", {
  small <- new_sg_image(matrix(0, 2, 2))
  expect_error(sg_protocol_validate("threshold.otsu.v1", small),
               class = "sg_validation_error")
  prob <- new_sg_image(matrix(stats::runif(400), 20, 20),
                       value_semantics = "reflectance")
  expect_error(sg_protocol_validate("stardist.2d.v1", prob), "value semantics")
  one <- new_sg_image(matrix(stats::runif(400), 20, 20))
  expect_error(sg_protocol_validate("mesmer.2d.v1", one), "at least 2")
  two <- new_sg_image(array(stats::runif(800), c(20, 20, 2)))
  err <- expect_error(sg_protocol_validate("mesmer.2d.v1", two),
                      class = "sg_calibration_error")
  expect_equal(err$code, "CALIBRATION_MISSING")
  expect_true(sg_protocol_validate("mesmer.2d.v1", two, image_mpp = 0.5)$ok)
  m <- new_sg_mask(matrix(c(0L, 1L), 1))
  big <- new_sg_mask(matrix(1L, 4, 4))
  expect_error(sg_protocol_validate("postprocess.label-cleanup.v1", big,
                                    min_area_um2 = 2),
               class = "sg_calibration_error")
  ref <- new_sg_image(matrix(0, 4, 4), resolution = list(x_um = 1, y_um = 1))
  expect_true(sg_protocol_validate("postprocess.label-cleanup.v1", big,
                                   min_area_um2 = 2, reference = ref)$ok)
  expect_error(sg_protocol_validate("propagate.voronoi.v1", one),
               "requires input")
  expect_error(sg_protocol_validate("propagate.voronoi.v1", one, seeds = m),
               class = "sg_validation_error")
})
