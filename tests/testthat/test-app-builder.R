test_that("sg_app returns a shiny app object without global options", {
  withr::local_options(segmantR.app_env = NULL)
  app <- sg_app(list(image = sg_example_image("fluorescence_nuclei")))
  expect_s3_class(app, "shiny.appobj")
  expect_null(getOption("segmantR.app_env"))
  err <- expect_error(sg_app(control = "loopback"),
                      class = "sg_capability_error")
  expect_equal(err$code, "CAPABILITY_UNAVAILABLE")
  expect_error(sg_app(foo = 1), class = "sg_validation_error")
  expect_error(sg_app(state = list(protocol = "nope.v1")),
               class = "sg_protocol_error")
})

test_that("app flow: run, stage, review, protected overwrite, export", {
  img <- sg_example_image("fluorescence_nuclei")
  app <- sg_app(list(image = img))
  shiny::testServer(app, {
    session$setInputs(protocol = "threshold.otsu.v1", channel = "1",
                      param_min_area = 5, param_max_area = 5000,
                      param_open_size = 5, param_fill_holes = TRUE)
    session$setInputs(run = 1)
    expect_equal(sg_mask_status(rv$candidate)$status, "staged")
    expect_match(rv$message, "staged for review")
    session$setInputs(accept = 1)
    expect_equal(sg_mask_status(rv$reviewed)$status, "reviewed")
    first <- sg_mask_revision(rv$reviewed)

    session$setInputs(param_min_area = 100, run = 2)
    expect_false(identical(sg_mask_revision(rv$candidate), first))
    session$setInputs(confirm_overwrite = FALSE, accept = 2)
    expect_match(rv$message, "REVIEWED_OVERWRITE_DENIED")
    expect_identical(sg_mask_revision(rv$reviewed), first)

    session$setInputs(confirm_overwrite = TRUE, accept = 3)
    expect_false(identical(sg_mask_revision(rv$reviewed), first))
    expect_equal(sg_mask_status(rv$reviewed)$parent_revision, first)

    session$setInputs(param_min_area = -3, run = 3)
    expect_match(rv$message, "PARAMETER_OUT_OF_RANGE")

    zip_file <- output$export
    expect_true(file.exists(zip_file))
    expect_true("manifest.json" %in% utils::unzip(zip_file, list = TRUE)$Name)
  })
})

test_that("app reports unavailable DNN backends instead of falling back", {
  local_mocked_bindings(.check_stardist = function() stop("no stardist"))
  app <- sg_app(list(image = sg_example_image("fluorescence_nuclei")))
  shiny::testServer(app, {
    session$setInputs(protocol = "stardist.2d.v1", channel = "1")
    expect_match(output$backend_status, "checked when the protocol runs")
    session$setInputs(run = 1)
    expect_match(rv$message, "unavailable")
    expect_null(rv$candidate)
  })
})

test_that("read-only apps and bundle inputs keep reviewed data untouched", {
  img <- sg_example_image("fluorescence_nuclei")
  reviewed <- sg_review_mask(sg_example_mask("fluorescence_nuclei"))
  app <- sg_app(list(image = img, mask = reviewed), read_only = TRUE)
  shiny::testServer(app, {
    session$setInputs(protocol = "threshold.otsu.v1", run = 1)
    expect_match(rv$message, "read-only")
    expect_identical(rv$reviewed, reviewed)
  })
  d <- file.path(withr::local_tempdir(), "b")
  sg_export_interchange(list(image = img,
                             mask = sg_example_mask("fluorescence_nuclei")),
                        d, formats = c("manifest", "mask_tiff", "image_tiff"))
  app2 <- sg_app(d)
  shiny::testServer(app2, {
    expect_equal(sg_mask_status(rv$candidate)$status, "staged")
    expect_identical(rv$image$pixels, img$pixels)
  })
})

test_that("control capability stays planned", {
  cc <- sg_control_capabilities()
  expect_equal(cc$status, "planned")
  expect_false(cc$implemented)
  expect_equal(cc$default, "off")
  expect_true(any(grepl("no eval", cc$security_requirements)))
})

test_that("the bundled app directory is a thin wrapper around sg_app()", {
  src <- readLines(system.file("shiny", "segmantR", "app.R",
                               package = "segmantR"))
  expect_true(any(grepl("segmantR::sg_app", src, fixed = TRUE)))
})
