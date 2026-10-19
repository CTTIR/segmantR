test_that("sg_roi_project builds provenance and normalises layers", {
  proj <- demo_project()
  expect_s3_class(proj, "sg_roi_project")
  expect_identical(proj$provenance$segmantR_version, as.character(utils::packageVersion("segmantR")))
  expect_named(proj$layers, c("tissue", "tumour"))
})

test_that("sg_roi_rois returns the exact contracted tibble (populated)", {
  proj <- demo_project()
  t <- sg_roi_rois(proj)
  expect_s3_class(t, "tbl_df")
  expect_equal(nrow(t), 3L)
  expect_identical(names(t), names(.sg_roi_empty_roi_tbl()))
  empty <- .sg_roi_empty_roi_tbl()
  types <- vapply(t[-14], function(x) class(x)[[1]], character(1))
  etypes <- vapply(empty[-14], function(x) class(x)[[1]], character(1))
  expect_identical(types, etypes)
  expect_true(inherits(t$geometry, "sfc"))
})

test_that("sg_roi_rois is type-stable on empty input", {
  proj <- sg_roi_project(small_image())
  t <- sg_roi_rois(proj)
  expect_s3_class(t, "tbl_df")
  expect_equal(nrow(t), 0L)
  expect_identical(names(t), names(.sg_roi_empty_roi_tbl()))
})

test_that("sg_roi_rois filters by layer and label", {
  proj <- demo_project()
  expect_equal(nrow(sg_roi_rois(proj, layer = "tumour")), 1L)
  expect_equal(nrow(sg_roi_rois(proj, label = "tissue")), 2L)
  expect_equal(nrow(sg_roi_rois(proj, label = "absent")), 0L)
})

test_that("sg_roi_layers reports one row per layer, empty-safe", {
  proj <- demo_project()
  l <- sg_roi_layers(proj)
  expect_equal(nrow(l), 2L)
  expect_identical(names(l), c("name", "n_rois", "labels", "visible", "locked", "z"))
  expect_identical(l$z, c(1L, 2L))
  expect_equal(nrow(sg_roi_layers(sg_roi_project(small_image()))), 0L)
})

test_that("sg_roi_add_layer rejects duplicate names", {
  proj <- demo_project()
  expect_error(sg_roi_add_layer(proj, sg_roi_layer("tissue")), "already exists")
})

test_that("sg_roi_add_roi requires an existing layer and keeps ids unique", {
  proj <- demo_project()
  expect_error(sg_roi_add_roi(proj, "nope", sg_roi_point(1, 1, label = "x")), "No layer")
  proj2 <- sg_roi_add_roi(proj, "tissue", sg_roi_point(1, 1, label = "tissue"))
  ids <- sg_roi_rois(proj2)$roi_id
  expect_length(unique(ids), length(ids))
})

test_that("mutators do not modify their input", {
  proj <- demo_project()
  snapshot <- proj
  invisible(sg_roi_add_roi(proj, "tissue", sg_roi_point(1, 1, label = "tissue")))
  invisible(sg_roi_remove_layer(proj, "tumour"))
  expect_identical(proj, snapshot)
})

test_that("sg_roi_remove_roi removes across layers or warns", {
  proj <- demo_project()
  id <- sg_roi_rois(proj)$roi_id[1]
  proj2 <- sg_roi_remove_roi(proj, id)
  expect_equal(nrow(sg_roi_rois(proj2)), nrow(sg_roi_rois(proj)) - 1L)
  expect_warning(sg_roi_remove_roi(proj, "no-such-id"), "nothing removed")
})

test_that("edit log grows with each mutation", {
  proj <- demo_project()
  n0 <- length(proj$provenance$edit_log)
  proj <- sg_roi_add_roi(proj, "tissue", sg_roi_point(1, 1, label = "tissue"))
  expect_equal(length(proj$provenance$edit_log), n0 + 1L)
})

test_that("sg_roi_validate passes clean projects and flags duplicate ids", {
  proj <- demo_project()
  expect_s3_class(sg_roi_validate(proj), "sg_roi_project")
  proj$layers$tissue$rois[[2]]$id <- proj$layers$tissue$rois[[1]]$id
  expect_error(sg_roi_validate(proj), "unique")
})

test_that("sg_roi_summary returns per-label counts", {
  s <- sg_roi_summary(demo_project())
  expect_s3_class(s, "sg_roi_summary")
  expect_identical(s$n_layers, 2L)
  expect_identical(s$n_rois, 3L)
  expect_true(all(c("tissue", "tumour") %in% s$per_label$label))
})

test_that("print methods produce output", {
  expect_output(print(demo_project()), "sg_roi_project")
  expect_output(print(sg_roi_summary(demo_project())), "sg_roi_summary")
})

test_that("sg_roi_project rejects a non-layer layers argument", {
  expect_error(sg_roi_project(small_image(), layers = 42), "sg_roi_layer")
  expect_error(sg_roi_project(small_image(), layers = list(1, 2)), "Every element")
})

test_that("sg_roi_rois errors on an unknown layer filter", {
  expect_error(sg_roi_rois(demo_project(), layer = "nope"), "No layer")
  expect_error(sg_roi_add_roi(demo_project(), "nope", sg_roi_point(1, 1, label = "x")), "No layer")
  expect_error(sg_roi_remove_layer(demo_project(), "nope"), "No layer")
})

test_that("summary.sg_roi_project dispatches to sg_roi_summary", {
  expect_s3_class(summary(demo_project()), "sg_roi_summary")
})

test_that("sg_roi_project detects duplicate layer names on construction", {
  a <- sg_roi_layer("dup")
  expect_error(.sg_roi_normalize_layers(list(a, a)), "unique")
})
