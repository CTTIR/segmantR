test_that("sg_roi_style validates and stores its fields", {
  s <- sg_roi_style(fill_alpha = 0.5, z = 3)
  expect_s3_class(s, "annot_style")
  expect_identical(s$z, 3L)
  expect_error(sg_roi_style(fill_alpha = 2), "range")
  expect_error(sg_roi_style(visible = NA), "TRUE")
})

test_that("sg_roi_layer resolves a stable colour mapping", {
  lyr <- sg_roi_layer("l", labels = c("a", "b"))
  expect_named(lyr$style$colour, c("a", "b"))
  expect_identical(unname(lyr$style$colour["a"]), "#999999")
  expect_identical(sg_roi_layer_n(lyr), 0L)
})

test_that("sg_roi_layer_add appends and extends labels", {
  lyr <- sg_roi_layer("l", labels = "a")
  lyr <- sg_roi_layer_add(lyr, sg_roi_rect(0, 0, 1, 1, label = "a"))
  lyr <- sg_roi_layer_add(lyr, sg_roi_rect(2, 2, 3, 3, label = "new"))
  expect_identical(sg_roi_layer_n(lyr), 2L)
  expect_true("new" %in% lyr$labels)
  expect_true("new" %in% names(lyr$style$colour))
})

test_that("sg_roi_layer_add re-mints colliding identifiers", {
  lyr <- sg_roi_layer("l", labels = "a")
  r <- sg_roi_rect(0, 0, 1, 1, label = "a", id = "dup")
  lyr <- sg_roi_layer_add(lyr, r)
  lyr <- sg_roi_layer_add(lyr, r)
  ids <- vapply(lyr$rois, `[[`, character(1), "id")
  expect_length(unique(ids), 2L)
})

test_that("sg_roi_layer_add does not modify its input", {
  lyr <- sg_roi_layer("l", labels = "a")
  snapshot <- lyr
  invisible(sg_roi_layer_add(lyr, sg_roi_rect(0, 0, 1, 1, label = "a")))
  expect_identical(lyr, snapshot)
})

test_that("sg_roi_layer_remove drops the ROI or warns", {
  lyr <- sg_roi_layer("l", labels = "a")
  r <- sg_roi_rect(0, 0, 1, 1, label = "a", id = "keepme")
  lyr <- sg_roi_layer_add(lyr, r)
  lyr2 <- sg_roi_layer_remove(lyr, "keepme")
  expect_identical(sg_roi_layer_n(lyr2), 0L)
  expect_warning(sg_roi_layer_remove(lyr, "nope"), "nothing removed")
})

test_that("sg_roi_layer_rois honours the query contract when empty", {
  t <- sg_roi_layer_rois(sg_roi_layer("l"))
  expect_equal(nrow(t), 0L)
  expect_identical(names(t), names(.sg_roi_empty_roi_tbl()))
})

test_that("sg_roi_style rejects a non-character colour", {
  expect_error(sg_roi_style(colour = 42), "character vector")
})

test_that("layer print and format produce output", {
  lyr <- sg_roi_layer_add(sg_roi_layer("l", labels = "a"), sg_roi_rect(0, 0, 1, 1, label = "a"))
  expect_output(print(lyr), "sg_roi_layer")
  expect_type(format(lyr), "character")
})
