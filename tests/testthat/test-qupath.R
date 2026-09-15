calibrated_image <- function() {
  new_sg_image(matrix(stats::runif(40 * 50), 40, 50), channels = "DAPI",
               id = "img-q", resolution = list(x_um = 0.5, y_um = 0.5),
               value_semantics = "intensity")
}

fake_pb <- function() {
  f <- file.path(withr::local_tempdir(.local_envir = parent.frame()),
                 "model.pb")
  writeBin(as.raw(1:100), f)
  f
}

test_that("StarDist parameter maps cover every protocol parameter", {
  p <- sg_protocol_get("stardist.2d.v1")
  for (target in c("python", "qupath")) {
    m <- sg_stardist_parameter_map(p, target)
    expect_setequal(m$parameter, names(p$parameters))
    expect_true(all(m$status %in% c("mapped", "approximated", "unsupported",
                                    "not_applicable", "runner")))
  }
  q <- sg_stardist_parameter_map("stardist.2d.v1", "qupath",
                                 nms_thresh = 0.3, normalize_scope = "global",
                                 image = calibrated_image())
  expect_equal(q$status[q$parameter == "nms_thresh"], "unsupported")
  expect_equal(q$status[q$parameter == "normalize_low"], "approximated")
  expect_equal(q$target_value[q$parameter == "channel"][[1]], "DAPI")
  expect_equal(q$target_option[q$parameter == "prob_thresh"], "threshold")
  py <- sg_stardist_parameter_map("stardist.2d.v1", "python",
                                  cell_expansion_um = 3)
  expect_equal(py$status[py$parameter == "cell_expansion_um"], "unsupported")
  expect_error(sg_stardist_parameter_map("stardist.2d.v1", "qupath",
                                         unknown = 1),
               class = "sg_validation_error")
  expect_error(sg_stardist_parameter_map("threshold.otsu.v1", "qupath"),
               "not a StarDist protocol")
  wl <- new_sg_image(array(0, c(8, 8, 2)), channels = c("b1", "b2"),
                     bands = data.frame(wavelength_nm = c(460, 520)))
  w <- sg_stardist_parameter_map("stardist.2d.v1", "qupath",
                                 wavelength_nm = 521, image = wl)
  expect_equal(w$target_value[w$parameter == "wavelength_nm"][[1]], "b2")
})

test_that("capabilities use declared versions and never overclaim", {
  new <- sg_stardist_capabilities("0.7.0", "0.6.0")
  expect_true(all(new$options$status == "supported"))
  expect_equal(new$extension$source, "declared")
  old <- sg_stardist_capabilities("0.4.3", "0.4.0")
  expect_true(all(old$options$status == "unknown"))
  expect_false(old$qupath$supported)
  expect_false(new$python$checked)
})

test_that("StarDist model manifests hash files and detect representations", {
  pb <- fake_pb()
  man <- sg_stardist_manifest(pb, n_channels_in = 1L, license_id = "BSD-3-Clause")
  expect_equal(man$representation, "pb")
  expect_true(man$compatibility$qupath_opencv)
  expected <- segmantR:::.sg_digest_json(list(
    format_version = "1.0",
    files = list(list(path = "model.pb", size_bytes = 100L,
                      sha256 = segmantR:::.sg_sha256_file(pb)))
  ))
  expect_identical(man$digest, expected)
  sm <- file.path(withr::local_tempdir(), "savedmodel")
  dir.create(file.path(sm, "variables"), recursive = TRUE)
  writeLines("x", file.path(sm, "saved_model.pb"))
  writeLines("y", file.path(sm, "variables", "v.index"))
  writeLines("hidden", file.path(sm, ".DS_Store"))
  writeLines("license", file.path(sm, "LICENSE.txt"))
  sman <- sg_stardist_manifest(sm)
  expect_equal(sman$representation, "savedmodel")
  expect_equal(sman$license$file, "LICENSE.txt")
  expect_false(any(vapply(sman$files, function(f) f$path, "") == ".DS_Store"))
  expect_error(sg_stardist_manifest(file.path(sm, "missing.pb")),
               class = "sg_integrity_error")
})

test_that("StarDist QuPath programs are schema-valid and self-describing", {
  img <- calibrated_image()
  dest <- file.path(withr::local_tempdir(), "prog")
  prog <- sg_export_qupath("stardist.2d.v1", dest, image = img,
                           image_name = "img.tif", model = fake_pb(),
                           normalize_scope = "tile", normalize_low = 1,
                           normalize_high = 99.8, pixel_size_um = 0.5,
                           classification = "Nucleus")
  files <- list.files(dest, recursive = TRUE)
  expect_true(all(c("run.json", "run_export.json", "segmantR_stardist.groovy",
                    "segmantR_export.groovy", "models/model.pb",
                    "models/stardist_model.json", "README.md",
                    "checksums.sha256") %in% files))
  run <- jsonlite::read_json(file.path(dest, "run.json"))
  expect_length(segmantR:::.sg_schema_errors(run, "qupath-run.schema.json",
                                             normalise = FALSE), 0L)
  expect_equal(run$stardist$threshold, 0.5)
  expect_equal(run$stardist$normalization$high, 99.8)
  expect_equal(unlist(run$stardist$channels), "DAPI")
  expect_equal(run$image_binding$width, 50L)
  expect_equal(run$image_binding$pixel_size_um$x, 0.5)
  expect_equal(run$save_policy, "none")
  expect_equal(run$stardist$model$digest,
               sg_stardist_manifest(file.path(dest, "models", "model.pb"))$digest)
  expect_equal(vapply(run$unsupported, function(u) u$parameter, ""),
               "nms_thresh")
  expect_false(grepl("--save", prog$commands$stardist))
  expect_true(sg_hash_assets(dest, verify = FALSE)$bundle_digest != "")
  sums <- readLines(file.path(dest, "checksums.sha256"))
  expect_true(any(grepl("segmantR_stardist.groovy$", sums)))
  tpl <- readLines(file.path(dest, "segmantR_stardist.groovy"))
  expect_false(any(grepl("evaluate\\(|Eval\\.|GroovyShell|execute\\(\\)", tpl)))
})

test_that("unsupported or uncalibrated StarDist programs are refused", {
  img <- calibrated_image()
  base <- withr::local_tempdir()
  expect_error(sg_export_qupath("stardist.2d.v1", file.path(base, "a"),
                                image = img, model = fake_pb(),
                                nms_thresh = 0.2),
               class = "sg_capability_error")
  expect_silent(sg_export_qupath("stardist.2d.v1", file.path(base, "b"),
                                 image = img, model = fake_pb(),
                                 nms_thresh = 0.2, allow_unsupported = TRUE))
  expect_error(sg_export_qupath("stardist.2d.v1", file.path(base, "c"),
                                image = img),
               "model file")
  expect_error(sg_export_qupath("threshold.otsu.v1", file.path(base, "d"),
                                image = img, model = fake_pb()),
               class = "sg_capability_error")
  uncal <- new_sg_image(matrix(0, 20, 20))
  expect_error(sg_export_qupath("stardist.2d.v1", file.path(base, "e"),
                                image = uncal, model = fake_pb()),
               class = "sg_calibration_error")
})

test_that("import programs bind a verified segmantR bundle", {
  img <- calibrated_image()
  l <- matrix(0L, 40, 50)
  l[5:12, 5:15] <- 1L
  mask <- new_sg_mask(l, image_id = "img-q")
  dest <- file.path(withr::local_tempdir(), "imp")
  prog <- sg_export_qupath(mask, dest, image = img, save_policy = "project")
  run <- jsonlite::read_json(file.path(dest, "run.json"))
  expect_equal(run$task, "import")
  expect_equal(run$import$geojson, "bundle/objects.geojson")
  expect_equal(run$import$geojson_sha256,
               segmantR:::.sg_sha256_file(file.path(dest, "bundle",
                                                    "objects.geojson")))
  expect_true(grepl("--save", prog$commands$import))
  expect_true(sg_import_interchange(file.path(dest, "bundle"))$ok)
  expect_error(sg_export_qupath(mask, file.path(dest, "x"), image = img,
                                min_area = 3),
               class = "sg_validation_error")
})

test_that("QuPath imports check run id, image binding and plane", {
  fx <- test_path("fixtures", "qupath-0.7.0", "stardist_out")
  skip_if_not(dir.exists(fx), "prerequisite: QuPath fixture directory")
  err <- expect_error(sg_import_qupath(fx, expected_run_id = "other"),
                      class = "sg_conflict_error")
  wrong <- new_sg_image(matrix(0, 10, 10))
  expect_error(sg_import_qupath(fx, image = wrong),
               class = "sg_validation_error")
  shifted <- new_sg_image(matrix(0, 96, 128),
                          resolution = list(x_um = 0.25, y_um = 0.25))
  expect_error(sg_import_qupath(fx, image = shifted),
               class = "sg_calibration_error")
  plane <- new_sg_image(matrix(0, 96, 128),
                        resolution = list(x_um = 0.5, y_um = 0.5),
                        plane = list(z = 1L))
  expect_error(sg_import_qupath(fx, image = plane),
               class = "sg_validation_error")
  parent <- dirname(fx)
  expect_error(sg_import_qupath(parent), "No QuPath export")
})

test_that("templates contain the declared safety checks", {
  dir <- system.file("qupath", package = "segmantR")
  for (f in list.files(dir, pattern = "\\.groovy$", full.names = TRUE)) {
    src <- paste(readLines(f), collapse = "\n")
    expect_match(src, "segmantR-qupath-run-v1", fixed = TRUE)
    expect_match(src, "path leaves the run directory", fixed = TRUE)
    expect_match(src, "image width", fixed = TRUE)
    expect_match(src, "pixel size", fixed = TRUE)
    expect_false(grepl("evaluate\\(|GroovyShell|Runtime\\.getRuntime|ProcessBuilder",
                       src))
  }
  st <- paste(readLines(file.path(dir, "segmantR_stardist.groovy")),
              collapse = "\n")
  expect_match(st, "VALUE_STROKE_PURE", fixed = TRUE)
  expect_match(st, "save_policy", fixed = TRUE)
})
