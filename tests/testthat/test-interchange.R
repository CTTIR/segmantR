bundle_fixture <- function() {
  l <- matrix(0L, 12, 16)
  l[2:5, 2:6] <- 1L
  l[7:11, 9:14] <- 2L
  l[8:9, 11:12] <- 0L       # hole in object 2
  l[1, 16] <- 3L            # corner pixel
  img <- new_sg_image(array(seq_len(12 * 16 * 2) / 10, c(12, 16, 2)),
                      channels = c("DAPI", "CD3"), id = "slide-7",
                      resolution = list(x_um = 0.5, y_um = 0.5),
                      plane = list(z = 1L, t = 2L),
                      value_semantics = "intensity")
  legend <- data.frame(label = 1:3, object_id = c("o-1", "o-2", "o-3"),
                       class = c("Tumor", NA, "Stroma"), name = NA)
  mask <- new_sg_mask(l, image_id = "slide-7", legend = legend,
                      plane = list(z = 1L, t = 2L))
  list(image = img, mask = mask)
}

test_that("capabilities are schema-valid and conservative", {
  caps <- sg_interchange_capabilities()
  expect_s3_class(caps, "sg_capabilities")
  expect_equal(caps$profiles$I0$status, "supported")
  expect_equal(caps$profiles$I1$status, "supported")
  for (p in c("control", "partner_qupflowR", "partner_annotatR",
              "qupath_programs")) {
    expect_equal(caps$profiles[[p]]$status, "planned")
  }
  stardist <- Filter(function(b) b$name == "python-stardist", caps$backends)[[1]]
  expect_false(stardist$checked)
  d <- caps$digest
  caps2 <- unclass(caps)
  caps2$digest <- NULL
  expect_identical(segmantR:::.sg_digest_json(caps2), d)
})

test_that("manifests describe image, mask, plane, legend and conventions", {
  fx <- bundle_fixture()
  man <- sg_interchange_manifest(fx$mask, image = fx$image)
  expect_equal(man$kind, "mask")
  expect_equal(man$coordinate_convention$array_order, "y,x,channel")
  expect_equal(man$mask$plane$z, 1L)
  expect_null(man$mask$plane$c)
  expect_equal(man$mask$dtype, "uint8")
  expect_equal(man$mask$legend[[1]]$object_id, "o-1")
  expect_equal(man$image$pixel_size$x, 0.5)
  expect_length(segmantR:::.sg_schema_errors(man, "manifest.schema.json",
                                             normalise = FALSE), 0L)
  expect_error(sg_interchange_manifest(fx$mask, foo = 1),
               class = "sg_validation_error")
  other <- fx$image
  other$plane$t <- 0L
  expect_error(sg_interchange_manifest(fx$mask, image = other),
               class = "sg_validation_error")
})

test_that("export and import round-trip exactly through every representation", {
  fx <- bundle_fixture()
  dest <- file.path(withr::local_tempdir(), "bundle")
  b <- sg_export_interchange(
    fx, dest,
    formats = c("manifest", "mask_tiff", "geojson", "measurements",
                "legend", "image_tiff", "rds")
  )
  files <- sort(list.files(dest))
  expect_equal(files, sort(c("bundle.rds", "image.ome.tif", "integrity.json",
                             "manifest.json", "mask.legend.json", "mask.tif",
                             "measurements.csv", "objects.geojson")))
  rep <- sg_import_interchange(dest, expected_digest = b$bundle_digest,
                               trust_rds = TRUE)
  expect_true(rep$ok)
  expect_identical(rep$mask$labels, fx$mask$labels)
  expect_identical(sg_mask_legend(rep$mask)$object_id, c("o-1", "o-2", "o-3"))
  expect_identical(sg_mask_revision(rep$mask), sg_mask_revision(fx$mask))
  expect_equal(sg_mask_status(rep$mask)$status, "staged")
  expect_equal(rep$mask$plane$t, 2L)
  expect_identical(rep$image$pixels, fx$image$pixels)
  expect_true(all(rep$checks$status %in% c("ok")))
  gj <- jsonlite::read_json(file.path(dest, "objects.geojson"))
  expect_null(gj$crs)
  expect_equal(gj$features[[2]]$id, "o-2")
  expect_equal(gj$features[[2]]$geometry$plane$t, 2L)
  expect_length(gj$features[[2]]$geometry$coordinates, 2L)
  meas <- rep$measurements
  expect_equal(meas$value[meas$object_id == "o-1" & meas$name == "area_px"], 20)
})

test_that("integrity violations and digest mismatches are refused", {
  fx <- bundle_fixture()
  base <- withr::local_tempdir()
  mk <- function(name) {
    d <- file.path(base, name)
    sg_export_interchange(fx$mask, d)
    d
  }
  d1 <- mk("extra")
  writeLines("x", file.path(d1, "extra.txt"))
  expect_error(sg_import_interchange(d1), class = "sg_integrity_error")
  d2 <- mk("missing")
  unlink(file.path(d2, "objects.geojson"))
  expect_error(sg_import_interchange(d2), class = "sg_integrity_error")
  d3 <- mk("modified")
  con <- file(file.path(d3, "measurements.csv"), "ab")
  writeBin(charToRaw("\n"), con)
  close(con)
  expect_error(sg_import_interchange(d3), class = "sg_integrity_error")
  d4 <- mk("digest")
  expect_error(sg_import_interchange(d4, expected_digest = paste0(
    "sha256:", strrep("0", 64))), class = "sg_integrity_error")
  d5 <- mk("traversal")
  int <- jsonlite::read_json(file.path(d5, "integrity.json"))
  int$files[[1]]$path <- "../escape.json"
  writeLines(jsonlite::toJSON(int, auto_unbox = TRUE),
             file.path(d5, "integrity.json"))
  expect_error(sg_import_interchange(d5), class = "sg_integrity_error")
  rep <- sg_import_interchange(d5, error = FALSE)
  expect_false(rep$ok)
  expect_match(rep$checks$detail[rep$checks$status == "failed"][1],
               "unsafe path|does not match pattern")
})

test_that("an approximated feature cannot mask a wrong exact feature", {
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d)
  gj <- jsonlite::read_json(file.path(d, "objects.geojson"))
  ring <- gj$features[[1]]$geometry$coordinates[[1]]
  gj$features[[1]]$geometry$coordinates[[1]] <- lapply(ring, function(p) {
    list(p[[1]] + 1, p[[2]])
  })
  gj$features[[3]]$geometry$coordinates[[1]][[1]][[1]] <- 15.25
  gj$features[[3]]$geometry$coordinates[[1]][[5]][[1]] <- 15.25
  writeLines(jsonlite::toJSON(gj, auto_unbox = TRUE, digits = NA),
             file.path(d, "objects.geojson"))
  man <- jsonlite::read_json(file.path(d, "manifest.json"))
  for (i in seq_along(man$assets)) {
    if (man$assets[[i]]$role == "geojson") {
      man$assets[[i]]$sha256 <-
        segmantR:::.sg_sha256_file(file.path(d, "objects.geojson"))
      man$assets[[i]]$size_bytes <- file.info(file.path(d,
                                                        "objects.geojson"))$size
    }
  }
  segmantR:::.sg_write_json(man, file.path(d, "manifest.json"))
  sg_hash_assets(d, write = "integrity")
  err <- expect_error(sg_import_interchange(d), class = "sg_validation_error")
  expect_match(conditionMessage(err), "exact GeoJSON feature")
  gj$features[[1]] <- NULL
  writeLines(jsonlite::toJSON(gj, auto_unbox = TRUE, digits = NA),
             file.path(d, "objects.geojson"))
  for (i in seq_along(man$assets)) {
    if (man$assets[[i]]$role == "geojson") {
      man$assets[[i]]$sha256 <-
        segmantR:::.sg_sha256_file(file.path(d, "objects.geojson"))
      man$assets[[i]]$size_bytes <- file.info(file.path(d,
                                                        "objects.geojson"))$size
    }
  }
  segmantR:::.sg_write_json(man, file.path(d, "manifest.json"))
  sg_hash_assets(d, write = "integrity")
  expect_error(sg_import_interchange(d), "no GeoJSON feature")
})

test_that("symbolic links to directories are listed, not followed", {
  skip_on_os("windows")
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d)
  file.symlink(".", file.path(d, "loop"))
  expect_true("loop" %in% segmantR:::.sg_list_rel_files(d))
  expect_error(sg_import_interchange(d), class = "sg_integrity_error")
  expect_error(sg_hash_assets(d), class = "sg_error")
})

test_that("symbolic links inside bundles are refused", {
  skip_on_os("windows")
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d)
  outside <- withr::local_tempfile()
  writeLines("secret", outside)
  file.rename(file.path(d, "objects.geojson"), file.path(d, "real.geojson"))
  file.symlink(outside, file.path(d, "objects.geojson"))
  expect_error(sg_import_interchange(d), class = "sg_error")
})

test_that("unknown major versions and schema violations are refused", {
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d)
  man <- jsonlite::read_json(file.path(d, "manifest.json"))
  man$schema_version <- "2.0.0"
  segmantR:::.sg_write_json(man, file.path(d, "manifest.json"))
  sg_hash_assets(d, write = "integrity")
  err <- expect_error(sg_import_interchange(d), class = "sg_protocol_error")
  expect_equal(err$code, "PROTOCOL_MISMATCH")
  man$schema_version <- "1.0.0"
  man$unexpected <- TRUE
  segmantR:::.sg_write_json(man, file.path(d, "manifest.json"))
  sg_hash_assets(d, write = "integrity")
  expect_error(sg_import_interchange(d), "unknown field")
})

test_that("wrong dtype, transposed TIFF and incomplete legends are detected", {
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d)
  segmantR:::.sg_write_tiff(t(fx$mask$labels), file.path(d, "mask.tif"),
                            dtype = "uint8")
  man <- jsonlite::read_json(file.path(d, "manifest.json"))
  sha <- segmantR:::.sg_sha256_file(file.path(d, "mask.tif"))
  for (i in seq_along(man$assets)) {
    if (man$assets[[i]]$role == "mask_tiff") {
      man$assets[[i]]$sha256 <- sha
      man$assets[[i]]$size_bytes <- file.info(file.path(d, "mask.tif"))$size
    }
  }
  segmantR:::.sg_write_json(man, file.path(d, "manifest.json"))
  sg_hash_assets(d, write = "integrity")
  err <- expect_error(sg_import_interchange(d), class = "sg_validation_error")
  expect_match(err$details$reason, "orientation")

  f <- withr::local_tempfile(fileext = ".tif")
  segmantR:::.sg_write_tiff(fx$mask$labels + 0.5, f, dtype = "float32")
  expect_error(sg_import_interchange(f), class = "sg_validation_error")

  f2 <- file.path(withr::local_tempdir(), "labels.tif")
  segmantR:::.sg_write_tiff(fx$mask$labels, f2, dtype = "uint16")
  writeLines(segmantR:::.sg_canonical_json(list(
    schema = "segmantR-interchange-v1", schema_version = "1.0.0",
    kind = "legend", mask_type = "instance", background = 0L,
    entries = list(list(label = 1L, object_id = "o-1", class = NULL,
                        name = NULL))
  )), sub("\\.tif$", ".legend.json", f2))
  err <- expect_error(sg_import_interchange(f2), class = "sg_validation_error")
  expect_equal(err$code, "LEGEND_INCOMPLETE")
})

test_that("standalone TIFF and GeoJSON imports are staged and need a shape", {
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d)
  t1 <- sg_import_interchange(file.path(d, "mask.tif"))
  expect_identical(t1$mask$labels, fx$mask$labels)
  expect_equal(sg_mask_legend(t1$mask)$object_id, c("o-1", "o-2", "o-3"))
  expect_error(sg_import_interchange(file.path(d, "objects.geojson")),
               "shape")
  g <- sg_import_interchange(file.path(d, "objects.geojson"),
                             image = fx$image)
  expect_identical(g$mask$labels, fx$mask$labels)
  expect_equal(g$mask$plane$t, 2L)
  expect_equal(sg_mask_status(g$mask)$status, "staged")
  wrong_plane <- fx$image
  wrong_plane$plane$z <- 0L
  expect_error(sg_import_interchange(file.path(d, "objects.geojson"),
                                     image = wrong_plane),
               class = "sg_validation_error")
})

test_that("RDS is never read without explicit trust", {
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d, formats = c("manifest", "mask_tiff", "rds"))
  rep <- sg_import_interchange(d)
  expect_equal(rep$checks$status[rep$checks$check == "rds"], "skipped")
  err <- expect_error(sg_import_interchange(file.path(d, "bundle.rds")),
                      class = "sg_security_error")
  expect_equal(err$code, "UNTRUSTED_RDS")
  reviewed <- sg_review_mask(fx$mask)
  f <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(mask = reviewed), f)
  r <- sg_import_interchange(f, trust_rds = TRUE)
  expect_equal(sg_mask_status(r$mask)$status, "staged")
  expect_equal(r$mask$provenance$import$source_review, "reviewed")
})

test_that("measurement special values survive the CSV round trip", {
  wide <- tibble::tibble(label = 1:4, score = c(1.25, NaN, Inf, NA))
  long <- segmantR:::.sg_measurements_long(wide, image_id = "i",
                                           object_ids = paste0("o", 1:4))
  f <- withr::local_tempfile(fileext = ".csv")
  segmantR:::.sg_write_measurements_csv(long, f)
  back <- sg_import_interchange(f)$measurements
  expect_equal(back$value_state, c("finite", "nan", "pos_inf", "missing"))
  expect_equal(back$value[1], 1.25)
  expect_true(is.nan(back$value[2]))
  expect_equal(back$value[3], Inf)
  expect_true(is.na(back$value[4]) && !is.nan(back$value[4]))
  bad <- readLines(f)
  bad[2] <- sub("finite", "nan", bad[2])
  writeLines(bad, f)
  expect_error(sg_import_interchange(f), "value_state")
})

test_that("parquet measurements are written when nanoparquet is available", {
  skip_if_not_installed("nanoparquet")
  fx <- bundle_fixture()
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(fx$mask, d, formats = c("manifest",
                                                "measurements_parquet"))
  pq <- nanoparquet::read_parquet(file.path(d, "measurements.parquet"))
  expect_true(all(c("object_id", "value_state") %in% names(pq)))
})

test_that("destinations are protected and empty masks export", {
  fx <- bundle_fixture()
  base <- withr::local_tempdir()
  foreign <- file.path(base, "foreign")
  dir.create(foreign)
  writeLines("user file", file.path(foreign, "keep.txt"))
  err <- expect_error(sg_export_interchange(fx$mask, foreign, overwrite = TRUE),
                      class = "sg_conflict_error")
  expect_true(file.exists(file.path(foreign, "keep.txt")))
  d <- file.path(base, "b")
  sg_export_interchange(fx$mask, d)
  expect_error(sg_export_interchange(fx$mask, d), class = "sg_conflict_error")
  expect_silent(sg_export_interchange(fx$mask, d, overwrite = TRUE))
  empty <- new_sg_mask(matrix(0L, 4, 4))
  e <- file.path(base, "empty")
  sg_export_interchange(empty, e)
  rep <- sg_import_interchange(e)
  expect_equal(rep$mask$n_cells, 0L)
})

test_that("validation of objects reports contract problems", {
  fx <- bundle_fixture()
  expect_true(sg_validate_interchange(fx$mask)$ok)
  bad <- fx$mask
  bad$labels[1, 1] <- -1L
  expect_false(sg_validate_interchange(bad)$ok)
  reviewed <- sg_review_mask(fx$mask)
  reviewed$labels[2, 7] <- 1L
  v <- sg_validate_interchange(reviewed)
  expect_false(v$ok)
  expect_equal(v$error$code, "REVISION_CONFLICT")
  run <- suppressMessages(sg_protocol_run(sg_example_image("fluorescence_nuclei"),
                                          "threshold.otsu.v1", min_area = 5L,
                                          output = "run"))
  expect_true(sg_validate_interchange(run)$ok)
  expect_true(sg_validate_interchange(sg_protocol_get("threshold.otsu.v1"))$ok)
  d <- file.path(withr::local_tempdir(), "r")
  sg_export_interchange(run, d, formats = c("manifest", "mask_tiff", "run"))
  expect_true(sg_validate_interchange(d)$ok)
})

test_that("sg_hash_assets writes both inventory formats", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "sub"))
  writeLines("a", file.path(d, "a.txt"))
  writeLines("b", file.path(d, "sub", "b.txt"))
  inv <- sg_hash_assets(d, write = "both")
  expect_equal(inv$files$path, c("a.txt", "sub/b.txt"))
  expect_identical(readLines(file.path(d, "integrity.json"), warn = FALSE),
                   segmantR:::.sg_canonical_json(inv$integrity))
  expect_identical(inv$bundle_digest, paste0(
    "sha256:", segmantR:::.sg_sha256_file(file.path(d, "integrity.json"))))
  sums <- readLines(file.path(d, "checksums.sha256"))
  expect_match(sums[2], "  sub/b.txt$")
  expect_silent(sg_hash_assets(d, verify = TRUE))
  writeLines("changed", file.path(d, "a.txt"))
  expect_error(sg_hash_assets(d, verify = TRUE), class = "sg_integrity_error")
})
