test_that("example image and mask generators produce matching synthetic data", {
  for (type in c("he_breast", "fluorescence_nuclei", "multiplex_4ch")) {
    img <- sg_example_image(type)
    msk <- sg_example_mask(type)
    expect_s3_class(img, "sg_image")
    expect_s3_class(msk, "sg_mask")
    expect_equal(dim(img)[1:2], dim(msk))
    expect_gt(msk$n_cells, 0L)
  }
})

test_that("sg_example_image is deterministic across calls", {
  expect_identical(sg_example_image("he_breast")$pixels,
                   sg_example_image("he_breast")$pixels)
  expect_equal(dim(sg_example_image("multiplex_4ch")), c(64L, 64L, 4L))
  expect_equal(sg_example_image("multiplex_4ch")$channels,
               c("DAPI", "CD3", "CD8", "PanCK"))
})

test_that("sg_example_mask labels are deterministic", {
  expect_identical(sg_example_mask("fluorescence_nuclei")$labels,
                   sg_example_mask("fluorescence_nuclei")$labels)
})

test_that("example generators reject unknown types", {
  expect_error(sg_example_image("nope"))
  expect_error(sg_example_mask("nope"))
})

test_that("sg_example_image pixel content is reproducible", {
  expect_snapshot_value(round(sg_example_image("he_breast")$pixels[1:5, 1:5], 4),
                        style = "serialize")
})

test_that("sg_run_app stores image/mask in options and dispatches to runApp", {
  captured <- NULL
  local_mocked_bindings(
    runApp = function(...) {
      captured <<- list(...)
      invisible(NULL)
    },
    .package = "shiny"
  )
  img <- sg_example_image("he_breast")
  msk <- sg_example_mask("he_breast")
  expect_null(sg_run_app(image = img, mask = msk, port = 1234L,
                         launch.browser = FALSE))
  env <- getOption("segmantR.app_env")
  expect_s3_class(env$image, "sg_image")
  expect_s3_class(env$mask, "sg_mask")
})

test_that(".draw_ellipse and .draw_ellipse_int fill a region", {
  m <- matrix(0, 10, 10)
  m2 <- segmantR:::.draw_ellipse(m, 5, 5, rx = 2, ry = 2, value = 1)
  expect_gt(sum(m2 > 0), 0)
  l <- matrix(0L, 10, 10)
  l2 <- segmantR:::.draw_ellipse_int(l, 5, 5, rx = 2, ry = 2, value = 3L)
  expect_true(3L %in% l2)
})

test_that(".random_centres returns the requested number of centres", {
  set.seed(1)
  c4 <- segmantR:::.random_centres(n = 4L, nr = 64L, nc = 64L)
  expect_equal(nrow(c4), 4L)
  expect_equal(ncol(c4), 4L)
})
