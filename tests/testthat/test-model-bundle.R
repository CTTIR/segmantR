savedmodel_dir <- function() {
  d <- file.path(withr::local_tempdir(.local_envir = parent.frame()), "sd")
  dir.create(file.path(d, "variables"), recursive = TRUE)
  writeBin(as.raw(1:64), file.path(d, "saved_model.pb"))
  writeBin(as.raw(64:1), file.path(d, "variables", "variables.index"))
  d
}

make_bundle_model <- function(weights) {
  new_sg_trained_model(
    weights, backend = "stardist", base_model = "none",
    training_metrics = list(n_epochs = 2L, loss = c(1, 0.5)),
    model_card = list(purpose = "nuclei", data_domain = "synthetic",
                      channels = "DAPI", target_pixel_size_um = 0.5,
                      limitations = c("synthetic data only"),
                      evaluation = list(f1 = 0.9)),
    license = list(id = "BSD-3-Clause", source = "test")
  )
}

test_that("bundles contain card, runtime, license and checksums", {
  w <- savedmodel_dir()
  arch <- withr::local_tempfile(fileext = ".segmantR")
  suppressMessages(sg_package_model(make_bundle_model(w), arch))
  names <- utils::unzip(arch, list = TRUE)$Name
  expect_true(all(c("model_card.json", "runtime.json", "license.json",
                    "checksums.sha256", "weights/saved_model.pb",
                    "weights/variables/variables.index") %in% names))
  m <- suppressMessages(sg_load_model(arch))
  expect_equal(m$integrity, "verified")
  expect_match(m$bundle_digest, "^sha256:")
  expect_equal(m$representation, "savedmodel")
  expect_equal(m$license$id, "BSD-3-Clause")
  expect_equal(m$card$limitations[[1]], "synthetic data only")
  expect_equal(m$card$evaluation$metrics$f1, 0.9)
  expect_true(file.exists(file.path(m$model_path, "variables",
                                    "variables.index")))
  expect_null(m$runtime$python)
  expect_identical(
    suppressMessages(sg_load_model(arch, expected_digest = m$bundle_digest))$bundle_digest,
    m$bundle_digest)
  expect_error(suppressMessages(sg_load_model(arch, expected_digest = "sha256:0")),
               class = "sg_integrity_error")
})

test_that("tampered, traversing and corrupt archives are refused", {
  skip_if_not_installed("zip")
  w <- savedmodel_dir()
  arch <- withr::local_tempfile(fileext = ".segmantR")
  suppressMessages(sg_package_model(make_bundle_model(w), arch))
  d <- withr::local_tempdir()
  utils::unzip(arch, exdir = d)
  writeBin(as.raw(0:9), file.path(d, "weights", "saved_model.pb"))
  tampered <- withr::local_tempfile(fileext = ".segmantR")
  segmantR:::.sg_zip_dir(d, tampered)
  expect_error(suppressMessages(sg_load_model(tampered)),
               class = "sg_integrity_error")

  e <- withr::local_tempdir()
  dir.create(file.path(e, "inner"))
  writeLines("{}", file.path(e, "model_card.json"))
  evil <- withr::local_tempfile(fileext = ".zip")
  suppressWarnings(zip::zip(evil, files = c("../model_card.json"),
                            root = file.path(e, "inner"), mode = "mirror"))
  err <- expect_error(suppressMessages(sg_load_model(evil)),
                      class = "sg_security_error")
  expect_equal(err$code, "ARCHIVE_UNSAFE")

  dir.create(file.path(e, "evildir"))
  evil_dir <- withr::local_tempfile(fileext = ".zip")
  suppressWarnings(zip::zip(evil_dir, files = "../evildir",
                            root = file.path(e, "inner"), mode = "mirror",
                            include_directories = TRUE))
  expect_true(any(grepl("^\\.\\./evildir/?$",
                        utils::unzip(evil_dir, list = TRUE)$Name)))
  err <- expect_error(suppressMessages(sg_load_model(evil_dir)),
                      class = "sg_security_error")
  expect_equal(err$code, "ARCHIVE_UNSAFE")

  corrupt <- withr::local_tempfile(fileext = ".segmantR")
  writeBin(as.raw(c(0x50, 0x4b, 1:30)), corrupt)
  expect_error(suppressMessages(sg_load_model(corrupt)),
               class = "sg_integrity_error")
})

test_that("legacy archives load unverified unless legacy is disallowed", {
  d <- withr::local_tempdir()
  writeLines('{"backend": "cellpose", "base_model": "cyto3"}',
             file.path(d, "model_card.json"))
  writeLines("w", file.path(d, "model.bin"))
  arch <- withr::local_tempfile(fileext = ".segmantR")
  segmantR:::.sg_zip_dir(d, arch)
  expect_message(m <- sg_load_model(arch), "Legacy")
  expect_equal(m$integrity, "unverified")
  expect_equal(m$backend, "cellpose")
  expect_error(suppressMessages(sg_load_model(arch, allow_legacy = FALSE)),
               class = "sg_integrity_error")
  writeLines('{"backend": "stardist", "weights": {"embedded": false, "files": []}}',
             file.path(d, "model_card.json"))
  arch_w <- withr::local_tempfile(fileext = ".segmantR")
  segmantR:::.sg_zip_dir(d, arch_w)
  expect_error(suppressMessages(sg_load_model(arch_w)),
               class = "sg_integrity_error")
  writeLines('{"backend": "tensorflow-magic"}', file.path(d, "model_card.json"))
  arch2 <- withr::local_tempfile(fileext = ".segmantR")
  segmantR:::.sg_zip_dir(d, arch2)
  expect_error(suppressMessages(sg_load_model(arch2)),
               class = "sg_capability_error")
  writeLines('{"schema": "segmantR-model-card-v2", "schema_version": "2.0.0", "backend": "cellpose"}',
             file.path(d, "model_card.json"))
  arch3 <- withr::local_tempfile(fileext = ".segmantR")
  segmantR:::.sg_zip_dir(d, arch3)
  expect_error(suppressMessages(sg_load_model(arch3)),
               class = "sg_protocol_error")
})

test_that("weights can be referenced by relative hashed paths", {
  base <- withr::local_tempdir()
  w <- file.path(base, "weights_dir")
  dir.create(w)
  writeBin(as.raw(1:32), file.path(w, "model.pb"))
  arch <- file.path(base, "model.segmantR")
  suppressMessages(sg_package_model(make_bundle_model(w), arch,
                                    embed_weights = FALSE))
  expect_false(any(grepl("^weights/", utils::unzip(arch, list = TRUE)$Name)))
  m <- suppressMessages(sg_load_model(arch))
  expect_equal(normalizePath(m$model_path), normalizePath(w))
  writeBin(as.raw(0:31), file.path(w, "model.pb"))
  expect_error(suppressMessages(sg_load_model(arch)),
               class = "sg_integrity_error")
})

test_that("bundles embed the dataset manifest used for training", {
  img <- sg_example_image("fluorescence_nuclei")
  msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                           disconnected = "split")
  ts <- sg_prepare_training_data(list(list(image = img, mask = msk,
                                           subject_id = "A")),
                                 tile_size = 32L,
                                 split = c(train = 1, validation = 0, test = 0))
  mdl <- make_bundle_model(savedmodel_dir())
  mdl$dataset_manifest <- ts$manifest
  arch <- withr::local_tempfile(fileext = ".segmantR")
  suppressMessages(sg_package_model(mdl, arch))
  m <- suppressMessages(sg_load_model(arch))
  expect_equal(m$dataset_manifest$dataset_digest, ts$manifest$dataset_digest)
  expect_equal(m$card$evaluation$dataset_digest, ts$manifest$dataset_digest)
})

test_that("sg_train_stardist validates data before checking Python", {
  img <- sg_example_image("fluorescence_nuclei")
  msk <- sg_cleanup_labels(sg_example_mask("fluorescence_nuclei"),
                           disconnected = "split")
  pairs <- list(list(image = img, mask = msk, subject_id = "A"),
                list(image = img, mask = msk, subject_id = "B"))
  ts <- sg_prepare_training_data(pairs, tile_size = 32L,
                                 split = c(train = 0.5, validation = 0.5,
                                           test = 0))
  local_mocked_bindings(.check_stardist = function() stop("no stardist module"))
  err <- expect_error(sg_train_stardist(ts, n_epochs = 1L),
                      class = "sg_capability_error")
  expect_equal(err$code, "CAPABILITY_UNAVAILABLE")
  expect_match(conditionMessage(err), "stardist")
  expect_error(sg_train_stardist(list(1)), class = "sg_validation_error")
  none <- sg_prepare_training_data(pairs, tile_size = 32L,
                                   split = c(train = 0, validation = 1,
                                             test = 0))
  expect_error(sg_train_stardist(none), "training split")
  labelled <- ts
  labelled$manifest$mask_type <- "labelled"
  labelled$manifest <- structure(segmantR:::.sg_finalise_dataset_manifest(
    labelled$manifest), class = c("sg_dataset_manifest", "list"))
  expect_error(sg_train_stardist(labelled), class = "sg_validation_error")
})

test_that("sg_predict_model runs through the protocol and stages the result", {
  w <- savedmodel_dir()
  mdl <- make_bundle_model(w)
  img <- new_sg_image(matrix(stats::runif(64 * 64), 64, 64))
  local_mocked_bindings(
    .check_stardist = function() invisible(TRUE),
    .sg_stardist_predict = function(ch, model, custom_model_path, ...) {
      stopifnot(identical(model, "custom"), identical(custom_model_path, w))
      l <- matrix(0L, nrow(ch), ncol(ch))
      l[10:20, 10:20] <- 1L
      new_sg_mask(l)
    }
  )
  run <- sg_predict_model(mdl, img, prob_thresh = 0.6, output = "run")
  expect_equal(run$record$status, "succeeded")
  expect_equal(sg_mask_status(run$mask)$status, "staged")
  expect_match(run$mask$provenance$model_digest, "^sha256:")
  expect_equal(run$record$parameters$prob_thresh, 0.6)
  expect_equal(run$record$delegate$arguments$custom_model_path,
               "<input:trained_model>")
})
