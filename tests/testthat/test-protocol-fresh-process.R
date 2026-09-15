# Reproduce a declarative run after serialisation in a second, fresh R
# process. Needs an installed segmantR of the same version (R CMD check
# installs it); under devtools::test() the lane is skipped with the reason.

test_that("a serialised protocol run is identical in a fresh R process", {
  skip_if_not_installed("callr")
  installed <- tryCatch(
    find.package("segmantR", lib.loc = .libPaths()[!grepl("pkgload|devtools",
                                                         .libPaths())],
                 quiet = TRUE),
    error = function(e) character(0)
  )
  has_version <- length(installed) == 1L && nzchar(installed) &&
    identical(read.dcf(file.path(installed, "DESCRIPTION"), "Version")[[1]],
              as.character(utils::packageVersion("segmantR")))
  skip_if(!has_version,
          "prerequisite: segmantR of this version installed in .libPaths() (R CMD check provides it)")

  dir <- withr::local_tempdir()
  px <- matrix(0.1, 20, 24)
  px[3:8, 3:8] <- 0.9
  px[12:18, 14:21] <- 0.8
  img <- new_sg_image(px, id = "fresh", resolution = list(x_um = 0.5,
                                                          y_um = 0.5))
  saveRDS(img, file.path(dir, "image.rds"))
  proto <- file.path(dir, "protocol.json")
  segmantR:::.sg_write_json(unclass(sg_protocol_get("threshold.otsu.v1")),
                            proto)
  local <- suppressMessages(sg_protocol_run(img, proto, min_area = 10L,
                                            output = "run"))
  remote <- callr::r(function(dir) {
    suppressPackageStartupMessages(library(segmantR))
    img <- readRDS(file.path(dir, "image.rds"))
    run <- suppressMessages(sg_protocol_run(
      img, file.path(dir, "protocol.json"), min_area = 10L, output = "run"))
    list(labels = run$mask$labels, revision = sg_mask_revision(run$mask),
         parameters_digest = run$record$parameters_digest,
         protocol_digest = run$record$protocol$digest,
         pid = Sys.getpid())
  }, args = list(dir = dir))
  expect_false(identical(remote$pid, Sys.getpid()))
  expect_identical(remote$labels, local$mask$labels)
  expect_identical(remote$revision, sg_mask_revision(local$mask))
  expect_identical(remote$parameters_digest, local$record$parameters_digest)
  expect_identical(remote$protocol_digest, local$record$protocol$digest)
})
