# Opt-in QuPath lane: fresh project, headless StarDist with save, reopen and
# export, import back into segmantR. Requires
#   SEGMANTR_QUPATH_EVIDENCE=true
#   a QuPath launcher (SEGMANTR_QUPATH or `qupath` on PATH) with the StarDist
#   extension, and a .pb model (SEGMANTR_STARDIST_PB or the QuPath default
#   model folder).
# Verified with QuPath 0.7.0, qupath-extension-stardist 0.6.0 and
# dsb2018_heavy_augment.pb (sha256 fc1f1148f221...cfe01b).

test_that("QuPath StarDist program runs headless, saves and round-trips", {
  skip_if(!qupath_lane_enabled(),
          "prerequisite: SEGMANTR_QUPATH_EVIDENCE=true (opt-in QuPath lane)")
  skip_if_not_installed("processx")
  skip_if(is.na(qupath_binary()), "prerequisite: QuPath launcher")
  skip_if(is.na(qupath_stardist_model()),
          "prerequisite: StarDist .pb model (SEGMANTR_STARDIST_PB)")
  caps <- sg_stardist_capabilities()
  skip_if(is.null(caps$extension$version),
          "prerequisite: QuPath StarDist extension jar in the user directory")

  ws <- withr::local_tempdir()
  fx <- make_nuclei_fixture(ws)
  proj <- file.path(ws, "project")
  expect_equal(qupath_create_project(proj, fx$path)$status, 0L)
  prog <- sg_export_qupath(
    "stardist.2d.v1", file.path(ws, "prog"), image = fx$image,
    image_name = basename(fx$path), model = qupath_stardist_model(),
    normalize_low = 1, normalize_high = 99, normalize_scope = "tile",
    pixel_size_um = 0.5, save_policy = "project"
  )
  p_arg <- paste0("--project=", file.path(proj, "project.qpproj"))
  i_arg <- paste0("--image=", basename(fx$path))
  r1 <- qupath_run(c("script", p_arg, i_arg, "--args=run.json", "--save",
                     "segmantR_stardist.groovy"), wd = prog$path)
  expect_equal(r1$status, 0L)
  r2 <- qupath_run(c("script", p_arg, i_arg, "--args=run_export.json",
                     "segmantR_export.groovy"), wd = prog$path)
  expect_equal(r2$status, 0L)
  a <- sg_import_qupath(file.path(prog$path, "out"), image = fx$image,
                        expected_run_id = prog$run$run_id)
  b <- sg_import_qupath(file.path(prog$path, "qupath_export"), image = fx$image)
  expect_identical(a$mask$labels, b$mask$labels)
  expect_identical(sg_mask_legend(a$mask)$object_id,
                   sg_mask_legend(b$mask)$object_id)
  ev <- suppressMessages(sg_evaluate_segmentation(a$mask, fx$mask,
                                                  metrics = "f1_detection"))
  expect_gte(ev$value, 0.9)
})

test_that("segmantR objects import into QuPath and export back exactly", {
  skip_if(!qupath_lane_enabled(),
          "prerequisite: SEGMANTR_QUPATH_EVIDENCE=true (opt-in QuPath lane)")
  skip_if_not_installed("processx")
  skip_if(is.na(qupath_binary()), "prerequisite: QuPath launcher")
  ws <- withr::local_tempdir()
  fx <- make_nuclei_fixture(ws)
  proj <- file.path(ws, "project")
  expect_equal(qupath_create_project(proj, fx$path)$status, 0L)
  prog <- sg_export_qupath(fx$mask, file.path(ws, "prog"), image = fx$image,
                           image_name = basename(fx$path),
                           save_policy = "project")
  p_arg <- paste0("--project=", file.path(proj, "project.qpproj"))
  i_arg <- paste0("--image=", basename(fx$path))
  expect_equal(qupath_run(c("script", p_arg, i_arg, "--args=run.json", "--save",
                            "segmantR_import.groovy"), wd = prog$path)$status, 0L)
  expect_equal(qupath_run(c("script", p_arg, i_arg, "--args=run_export.json",
                            "segmantR_export.groovy"), wd = prog$path)$status, 0L)
  again <- qupath_run(c("script", p_arg, i_arg, "--args=run.json", "--save",
                        "segmantR_import.groovy"), wd = prog$path)
  expect_false(identical(again$status, 0L))
  back <- sg_import_qupath(file.path(prog$path, "qupath_export"),
                           image = fx$image)
  orig <- sg_mask_legend(fx$mask)
  got <- sg_mask_legend(back$mask)
  expect_setequal(got$object_id, orig$object_id)
  map <- orig$label[match(got$object_id, orig$object_id)]
  lab <- back$mask$labels
  lab[lab > 0L] <- map[match(lab[lab > 0L], got$label)]
  expect_identical(lab, fx$mask$labels)
})
