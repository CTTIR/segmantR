# Independent fixtures: a hand-computed GeoJSON and real QuPath 0.7.0 /
# StarDist extension 0.6.0 exports (data-raw/qupath-evidence/run_evidence.R).

test_that("hand-written GeoJSON rasterises to the hand-computed labels", {
  exp <- jsonlite::read_json(test_path("fixtures", "geojson",
                                       "hand_expected.json"))
  rep <- sg_import_interchange(test_path("fixtures", "geojson",
                                         "hand_features.geojson"),
                               shape_yx = unlist(exp$shape_yx))
  expected <- matrix(unlist(exp$labels_row_major), nrow = 8, byrow = TRUE)
  storage.mode(expected) <- "integer"
  expect_identical(rep$mask$labels, expected)
  leg <- sg_mask_legend(rep$mask)
  expect_equal(leg$object_id, unlist(exp$object_ids))
  expect_equal(leg$class, c("Tumor", "Stroma", NA, NA))
  conv <- rep$conversions[[1]]
  expect_equal(conv$fidelity, "unsupported")
  expect_match(conv$notes, "2 unsupported")
  qp <- sg_import_qupath(test_path("fixtures", "geojson",
                                   "hand_features.geojson"),
                         image = new_sg_image(matrix(0, 8, 8)))
  m <- qp$measurements
  expect_equal(m$value[m$object_id == "a-0001" & m$name == "Area px"], 4)
  expect_equal(m$value[m$object_id == "b-0002" & m$name == "Area px"], 7)
  expect_equal(unique(m$namespace), "stored")
})

qupath_fixture <- function(...) test_path("fixtures", "qupath-0.7.0", ...)

test_that("QuPath StarDist export passes all interchange checks", {
  skip_if_not(dir.exists(qupath_fixture("stardist_out")),
              "prerequisite: QuPath fixture directory")
  ev <- jsonlite::read_json(qupath_fixture("evidence.json"))
  rep <- sg_import_qupath(qupath_fixture("stardist_out"))
  expect_true(rep$ok)
  ok <- rep$checks$check[rep$checks$status == "ok"]
  expect_true(all(c("integrity", "manifest", "mask_content_digest",
                    "mask_revision", "measurements") %in% ok))
  expect_equal(rep$qupath$version, "0.7.0")
  expect_equal(rep$qupath$stardist_extension_version, "0.6.0")
  expect_equal(rep$mask$n_cells, ev$comparisons$stardist_objects)
  expect_lte(rep$qupath$agreement$differing_pixels, 5L)
  expect_equal(sg_mask_status(rep$mask)$status, "staged")
  man <- jsonlite::read_json(qupath_fixture("stardist_out", "manifest.json"))
  expect_equal(man$mask$model_digest, ev$model$inventory_digest)
  run <- jsonlite::read_json(qupath_fixture("run_stardist.json"))
  expect_equal(man$id, run$run_id)
  expect_length(segmantR:::.sg_schema_errors(run, "qupath-run.schema.json",
                                             normalise = FALSE), 0L)
})

test_that("QuPath canonical measurements agree with QuPath's native table", {
  skip_if_not(dir.exists(qupath_fixture("stardist_out")),
              "prerequisite: QuPath fixture directory")
  rep <- sg_import_qupath(qupath_fixture("stardist_out"))
  native <- utils::read.delim(qupath_fixture("stardist_out",
                                             "qupath_detections.tsv"),
                              check.names = FALSE)
  long <- rep$measurements
  area_name <- grep("^Area", unique(long$name), value = TRUE)[1]
  ours <- long[long$name == area_name, ]
  idx <- match(ours$object_id, native[["Object ID"]])
  expect_false(anyNA(idx))
  expect_equal(ours$value, native[[area_name]][idx], tolerance = 1e-3)
  px_area <- tapply(rep$mask$labels[rep$mask$labels > 0],
                    rep$mask$labels[rep$mask$labels > 0], length)
  leg <- sg_mask_legend(rep$mask)
  um2 <- ours$value[match(leg$object_id, ours$object_id)]
  expect_equal(as.numeric(px_area) * 0.25, um2, tolerance = 0.15)
})

test_that("segmantR -> QuPath -> segmantR preserves ids and pixels exactly", {
  skip_if_not(dir.exists(qupath_fixture("import_roundtrip_export")),
              "prerequisite: QuPath fixture directory")
  src <- sg_import_interchange(qupath_fixture("segmantR_bundle"))
  back <- sg_import_qupath(qupath_fixture("import_roundtrip_export"))
  expect_true(back$ok)
  expect_equal(back$qupath$agreement$differing_pixels, 0L)
  orig <- sg_mask_legend(src$mask)
  got <- sg_mask_legend(back$mask)
  expect_setequal(got$object_id, orig$object_id)
  map <- orig$label[match(got$object_id, orig$object_id)]
  relabelled <- back$mask$labels
  pos <- relabelled > 0L
  relabelled[pos] <- map[match(relabelled[pos], got$label)]
  expect_identical(relabelled, src$mask$labels)
  img <- segmantR:::.sg_read_tiff(qupath_fixture("nuclei.ome.tif"))
  expect_equal(dim(img$data), dim(src$mask$labels))
  expect_match(img$description, "PhysicalSizeX=\"0.5\"", fixed = TRUE)
})

test_that("QuPath reads the segmantR OME-TIFF with its calibration", {
  skip_if_not(dir.exists(qupath_fixture("stardist_out")),
              "prerequisite: QuPath fixture directory")
  man <- jsonlite::read_json(qupath_fixture("stardist_out", "manifest.json"))
  expect_equal(man$image$pixel_size$x, 0.5)
  expect_equal(unlist(man$image$shape_yx), c(96L, 128L))
  expect_equal(unlist(man$image$channels), "DAPI")
  expect_equal(man$image$dtype, "uint16")
})
