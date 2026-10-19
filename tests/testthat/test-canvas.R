cell_box <- function(x0 = 1, y0 = 1, x1 = 4, y1 = 4) {
  list(type = "Polygon", coordinates = list(list(c(x0,y0), c(x1,y0),
    c(x1,y1), c(x0,y1), c(x0,y0))))
}

test_that("cell drawing stages masks independently with image binding intact", {
  mask <- new_sg_mask(matrix(0L, 8, 9), image_id = "slide",
    origin = list(x = 100, y = 200, downsample = 2))
  added <- sg_canvas_correct(mask, cell_box(), expected_revision = sg_mask_revision(mask))
  expect_equal(sum(added$labels > 0), 9)
  expect_identical(added$origin, mask$origin)
  expect_identical(added$image_id, "slide")
  expect_identical(added$review$status, "staged")
  expect_equal(sum(mask$labels), 0)
  expect_error(sg_canvas_correct(added, cell_box(), expected_revision = sg_mask_revision(mask)), "changed")
  expect_error(sg_canvas_correct(added, cell_box(), expected_revision = sg_mask_revision(added)), "overlap")
  moved <- sg_canvas_correct(added, cell_box(4,4,7,7), "edit", 1L, sg_mask_revision(added))
  expect_equal(sum(moved$labels > 0), 9)
  expect_equal(sum(moved$labels[2:4,2:4]), 0)
  erased <- sg_canvas_correct(moved, action = "erase", cell_id = 1L,
    expected_revision = sg_mask_revision(moved))
  expect_equal(sum(erased$labels), 0)
  expect_identical(erased$review$status, "staged")
})

test_that("invalid and out-of-bounds polygons are refused", {
  mask <- new_sg_mask(matrix(0L, 8, 9))
  for (g in list(cell_box(-1), cell_box(x1 = 99), list(type = "Point", coordinates = c(2,2)), cell_box(x1 = NA))) {
    expect_error(sg_canvas_correct(mask, g, expected_revision = sg_mask_revision(mask)), "polygons")
  }
})

test_that("the cell widget uses its own engine and rejects mismatched masks", {
  skip_if_not_installed("htmlwidgets")
  skip_if_not_installed("magick")
  img <- new_sg_image(matrix(seq_len(72), 8, 9), id = "slide")
  mask <- new_sg_mask(matrix(0L,8,9), image_id = "slide")
  w <- sg_canvas(img, mask, tool = "polygon")
  expect_s3_class(w, "sgcanvas")
  expect_identical(w$x$revision, sg_mask_revision(mask))
  expect_identical(w$x$tileSource$width, 9L)
  expect_match(w$x$tileSource$dataUri, "^data:image/png;base64,")
  mask$image_id <- "other"
  expect_error(sg_canvas(img, mask), "matching")
})

test_that("the app stages drawing events and rejects stale revisions", {
  skip_if_not_installed("htmlwidgets")
  skip_if_not_installed("magick")
  img <- new_sg_image(matrix(seq_len(72),8,9), id = "slide")
  shiny::testServer(sg_app(img), {
    session$setInputs(channel = "1", cell_tool = "rect")
    rev <- canvas_state()$revision
    session$setInputs(cell_canvas_created = list(revision = rev,
      payload = list(geometry = cell_box())))
    expect_equal(sum(rv$candidate$labels > 0), 9)
    expect_identical(rv$candidate$review$status, "staged")
    session$setInputs(cell_canvas_created = list(revision = rev,
      payload = list(geometry = cell_box(4,4,7,7))))
    expect_match(rv$message, "REVISION_CONFLICT")
    expect_equal(sum(rv$candidate$labels > 0), 9)
    session$setInputs(accept = 1)
    expect_identical(rv$reviewed$review$status, "reviewed")
  })
})
