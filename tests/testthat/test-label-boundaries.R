test_that("PNG palettes depend on present objects, not maximum label", {
  palette_sizes <- integer(0)
  rendered <- NULL
  rainbow_original <- grDevices::rainbow
  local_mocked_bindings(
    rainbow = function(n, ...) {
      palette_sizes <<- c(palette_sizes, n)
      if (n > 8L) cli::cli_abort("unsafe max-label palette allocation")
      rainbow_original(n, ...)
    },
    png = function(...) NULL,
    dev.off = function(...) NULL,
    .package = "grDevices"
  )
  local_mocked_bindings(
    par = function(...) NULL,
    image = function(z, col, ...) rendered <<- list(z = z, col = col),
    .package = "graphics"
  )
  labels <- matrix(c(0L, 2L, .Machine$integer.max, 0L), 2L, 2L)
  mask <- new_sg_mask(labels)
  path <- withr::local_tempfile(fileext = ".png")
  expect_no_error(sg_export_mask(mask, path, format = "png"))
  expect_identical(palette_sizes, 2L)
  expected <- matrix(c(0L, 1L, 2L, 0L), 2L, 2L)
  expect_identical(rendered$z, t(expected[2:1, ]))
  expect_identical(rendered$col, c("black", rainbow_original(2L)))
  expect_identical(mask$labels, labels)
})

test_that("label cleanup does not allocate IDs when no split needs one", {
  top <- .Machine$integer.max
  connected <- matrix(c(top, top, 0L), 1L, 3L)
  for (policy in c("keep", "split", "keep_largest")) {
    expect_no_warning(result <- sg_cleanup_labels(
      new_sg_mask(connected), disconnected = policy, relabel = "none"
    ))
    expect_identical(result$labels, connected)
  }
  disconnected <- matrix(c(top, 0L, top), 1L, 3L)
  expect_no_warning(result <- sg_cleanup_labels(
    new_sg_mask(disconnected), disconnected = "keep_largest", relabel = "none"
  ))
  expect_identical(result$labels, matrix(c(top, 0L, 0L), 1L, 3L))
})

test_that("splitting labels checks the entire required ID range", {
  top <- .Machine$integer.max
  labels <- matrix(c(top - 1L, 0L, top - 1L), 1L, 3L)
  expect_no_warning(result <- sg_cleanup_labels(
    new_sg_mask(labels), disconnected = "split", relabel = "none"
  ))
  expect_identical(result$labels, matrix(c(top - 1L, 0L, top), 1L, 3L))
  for (labels in list(
    matrix(c(top, 0L, top), 1L, 3L),
    matrix(c(top - 1L, 0L, top - 1L, 0L, top - 1L), 1L, 5L)
  )) {
    mask <- new_sg_mask(labels)
    expect_error(
      sg_cleanup_labels(mask, disconnected = "split", relabel = "none"),
      "exhaust.*label|label.*exhaust", class = "sg_error"
    )
    expect_identical(mask$labels, labels)
  }
})

test_that("contiguous-label PNG appearance remains byte-identical", {
  reference_png <- function(labels, path) {
    grDevices::png(path, width = ncol(labels), height = nrow(labels))
    on.exit(grDevices::dev.off())
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::image(t(labels[rev(seq_len(nrow(labels))), ]),
                    col = c("black", grDevices::rainbow(max(1L, labels))),
                    axes = FALSE)
  }
  for (labels in list(
    matrix(0L, 8L, 8L), matrix(1L, 8L, 8L),
    matrix(rep(0:2, length.out = 64L), 8L, 8L)
  )) {
    reference <- withr::local_tempfile(fileext = ".png")
    actual <- withr::local_tempfile(fileext = ".png")
    reference_png(labels, reference)
    suppressMessages(sg_export_mask(
      new_sg_mask(labels), actual, format = "png"
    ))
    expect_identical(
      readBin(actual, "raw", n = file.info(actual)$size),
      readBin(reference, "raw", n = file.info(reference)$size)
    )
  }
})
