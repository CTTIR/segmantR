# The mask engine is the core deliverable; this is the largest test file.

test_that("the pixel-coverage contract holds on a hand-verified case", {
  # Rect x[2,5], y[2,5] on a 10x10 grid. Pixel (i,j) centre = (j-0.5, i-0.5),
  # so centres in (2,5) => i,j in {3,4,5}. Exactly nine pixels.
  m <- sg_roi_mask(sg_roi_rect(2, 2, 5, 5, label = "a"), "binary", dims = c(10, 10))
  expect_equal(sum(m), 9L)
  idx <- which(as.matrix(m), arr.ind = TRUE)
  expect_identical(sort(unique(idx[, 1])), 3:5)
  expect_identical(sort(unique(idx[, 2])), 3:5)
})

test_that("boundary ties resolve as [lower, upper) symmetrically", {
  # Edges exactly on pixel centres x=2.5..5.5: lower centre included, upper
  # excluded -> rows and cols 3,4,5.
  m <- sg_roi_mask(sg_roi_rect(2.5, 2.5, 5.5, 5.5, label = "a"), "binary", dims = c(10, 10))
  idx <- which(as.matrix(m), arr.ind = TRUE)
  expect_identical(sort(unique(idx[, 1])), 3:5)
  expect_identical(sort(unique(idx[, 2])), 3:5)
})

test_that("touches = TRUE grows the region beyond centre coverage", {
  r <- sg_roi_rect(2.6, 2.6, 4.4, 4.4, label = "a")
  mf <- sg_roi_mask(r, "binary", dims = c(10, 10), touches = FALSE)
  mt <- sg_roi_mask(r, "binary", dims = c(10, 10), touches = TRUE)
  expect_equal(sum(mf), 1L)
  expect_equal(sum(mt), 9L)
})

test_that("the three mask types return the right structure", {
  proj <- demo_project()
  mb <- sg_roi_mask(proj, "binary")
  ml <- sg_roi_mask(proj, "labelled")
  mc <- sg_roi_mask(proj, "multiclass")
  expect_true(is.logical(as.matrix(mb)))
  expect_true(is.integer(as.matrix(ml)))
  expect_equal(nrow(sg_roi_mask_legend(ml)), 3L) # one id per ROI
  expect_equal(nrow(sg_roi_mask_legend(mc)), 2L) # one id per label
})

test_that("overlap policies resolve deterministically", {
  a <- sg_roi_rect(0, 0, 6, 6, label = "a")
  b <- sg_roi_rect(4, 4, 10, 10, label = "b")
  lyr <- sg_roi_layer_add(sg_roi_layer_add(sg_roi_layer("l"), a), b)
  expect_equal(as.matrix(sg_roi_mask(lyr, "labelled", dims = c(10, 10), overlap = "last"))[5, 5], 2L)
  expect_equal(as.matrix(sg_roi_mask(lyr, "labelled", dims = c(10, 10), overlap = "first"))[5, 5], 1L)
  expect_equal(as.matrix(sg_roi_mask(lyr, "labelled", dims = c(10, 10), overlap = "max"))[5, 5], 2L)
  expect_equal(as.matrix(sg_roi_mask(lyr, "labelled", dims = c(10, 10), overlap = "min"))[5, 5], 1L)
  expect_error(sg_roi_mask(lyr, "labelled", dims = c(10, 10), overlap = "error"), "Overlapping")
})

test_that("an empty project gives an all-background mask of correct type/dims", {
  proj <- sg_roi_project(small_image())
  ml <- sg_roi_mask(proj, "labelled")
  expect_identical(dim(ml), c(100L, 100L))
  expect_true(all(as.matrix(ml) == 0L))
  expect_equal(nrow(sg_roi_mask_legend(ml)), 0L)
  mb <- sg_roi_mask(proj, "binary")
  expect_true(is.logical(as.matrix(mb)))
  expect_false(any(as.matrix(mb)))
})

test_that("terra and stars rasterisers are bit-identical", {
  skip_if_not_installed("terra")
  proj <- demo_project()
  for (ty in c("binary", "labelled", "multiclass")) {
    ms <- as.matrix(sg_roi_mask(proj, ty, engine = "stars"))
    mt <- as.matrix(sg_roi_mask(proj, ty, engine = "terra"))
    expect_identical(ms, mt, info = ty)
  }
  # And on a boundary-tie case.
  r <- sg_roi_rect(2.5, 2.5, 5.5, 5.5, label = "a")
  expect_identical(
    as.matrix(sg_roi_mask(r, "binary", dims = c(10, 10), engine = "stars")),
    as.matrix(sg_roi_mask(r, "binary", dims = c(10, 10), engine = "terra"))
  )
})

test_that("mask at level 2 has level-2 dims and aligns with level 0", {
  img <- small_image() # 100, 50, 25
  lyr <- sg_roi_layer_add(sg_roi_layer("l"), sg_roi_rect(20, 20, 60, 60, label = "a"))
  proj <- sg_roi_project(img, lyr)
  m0 <- as.matrix(sg_roi_mask(proj, "binary", level = 0))
  m2 <- as.matrix(sg_roi_mask(proj, "binary", level = 2))
  expect_identical(dim(m2), c(25L, 25L))
  # Upsample level 2 by 4 and compare: mismatch confined to a thin boundary.
  up <- m2[rep(seq_len(25), each = 4), rep(seq_len(25), each = 4)]
  mismatch <- mean(up != m0)
  expect_lt(mismatch, 0.1)
})

test_that("level masking uses real image dims for non-power-of-two pyramids", {
  img <- .new_sg_roi_frame("np.tif", "tiff", c(100L, 100L), 3L,
                         list(c(100L, 100L), c(40L, 40L), c(16L, 16L)), 1L)
  proj <- sg_roi_project(img, sg_roi_layer_add(sg_roi_layer("l"),
                                       sg_roi_rect(0, 0, 50, 50, label = "a")))
  m1 <- sg_roi_mask(proj, "binary", level = 1)
  expect_identical(dim(m1), c(40L, 40L))
  # 50 * (40/100) = 20, not the power-of-two 25.
  idx <- which(as.matrix(m1), arr.ind = TRUE)
  expect_equal(max(idx[, 2]), 20L)
})

test_that("the legend is populated with the contracted columns", {
  lg <- sg_roi_mask_legend(sg_roi_mask(demo_project(), "labelled"))
  expect_identical(names(lg), c("value", "label", "layer", "roi_id", "n_px", "colour"))
  expect_true(all(lg$n_px > 0))
})

test_that("sg_roi_mask_stats is type-stable and correct", {
  m <- sg_roi_mask(sg_roi_rect(2, 2, 5, 5, label = "a"), "labelled", dims = c(10, 10))
  st <- sg_roi_mask_stats(m)
  expect_equal(st$n_px, 9L)
  expect_equal(st$area_px, 9)
  expect_true(is.na(st$area_physical))
  st2 <- sg_roi_mask_stats(m, pixel_size = c(2, 2))
  expect_equal(st2$area_physical, 36)
  # empty
  empty <- sg_roi_mask_stats(sg_roi_mask(sg_roi_project(small_image()), "labelled"))
  expect_equal(nrow(empty), 0L)
  expect_identical(names(empty)[1:3], c("value", "label", "n_px"))
})

test_that("sg_roi_mask_boundary marks object edges", {
  m <- sg_roi_mask(sg_roi_rect(2, 2, 8, 8, label = "a"), "labelled", dims = c(10, 10))
  b <- sg_roi_mask_boundary(m)
  expect_true(is.matrix(b) && is.logical(b))
  expect_true(sum(b) > 0 && sum(b) < sum(as.matrix(m) != 0))
})

test_that("sg_roi_mask_preview downsamples nearest-neighbour", {
  proj <- demo_project()
  m <- sg_roi_mask(proj, "labelled")
  pv <- sg_roi_mask_preview(m, max_dim = 25)
  expect_true(max(dim(pv)) <= 25L)
  expect_true(all(unique(as.integer(pv)) %in% unique(as.integer(m))))
})

test_that("sg_roi_mask_stack has one plane per layer", {
  proj <- demo_project()
  stk <- sg_roi_mask_stack(proj)
  expect_length(dim(stk), 3L)
  expect_identical(dim(stk)[3], length(proj$layers))
})

test_that("sg_roi_mask errors on unsupported input", {
  expect_error(sg_roi_mask(1), "sg_roi")
})

test_that("plot.sg_roi_mask returns a ggplot", {
  expect_s3_class(plot(sg_roi_mask(demo_project(), "labelled")), "ggplot")
  expect_s3_class(plot(sg_roi_mask(demo_project(), "labelled"), legend = FALSE), "ggplot")
})

test_that("sg_roi_mask derives dims from the geometry bbox when none are given", {
  m <- sg_roi_mask(sg_roi_rect(2, 2, 8, 8, label = "a"), "binary")
  expect_identical(dim(m), c(8L, 8L))
})

test_that("sg_roi_mask print, dim, as.matrix, and summary work", {
  m <- sg_roi_mask(demo_project(), "labelled")
  expect_output(print(m), "sg_roi_mask")
  expect_identical(dim(m), c(100L, 100L))
  expect_true(is.matrix(as.matrix(m)))
  expect_s3_class(summary(m), "tbl_df")
})

test_that("sg_roi_mask_boundary supports a thicker boundary", {
  m <- sg_roi_mask(sg_roi_rect(2, 2, 18, 18, label = "a"), "labelled", dims = c(20, 20))
  expect_gt(sum(sg_roi_mask_boundary(m, width = 2L)), sum(sg_roi_mask_boundary(m, width = 1L)))
})

test_that("sg_roi_mask_stack is empty for a layerless project", {
  stk <- sg_roi_mask_stack(sg_roi_project(small_image()))
  expect_identical(dim(stk)[3], 0L)
})

test_that("sg_roi_mask_stats reports zero pixels for a fully occluded label", {
  # ROI 'a' is completely covered by 'b' under overlap = "last".
  a <- sg_roi_rect(2, 2, 6, 6, label = "a")
  b <- sg_roi_rect(0, 0, 10, 10, label = "b")
  lyr <- sg_roi_layer_add(sg_roi_layer_add(sg_roi_layer("l"), a), b)
  m <- sg_roi_mask(lyr, "labelled", dims = c(10, 10), overlap = "last")
  st <- sg_roi_mask_stats(m)
  expect_true(0L %in% st$n_px)
})

test_that("a right triangle is not rasterised as its bounding rectangle", {
  tri <- sg_roi_polygon(rbind(c(0, 0), c(10, 0), c(10, 10)), label = "t")
  expect_false(segmantR:::.sg_roi_is_axis_aligned_rect(tri$geometry[[1]]))
  expect_equal(sum(sg_roi_mask(tri, dims = c(10, 10))), 45L)
  far <- sg_roi_rect(100, 100, 101, 101, label = "t")
  lyr <- sg_roi_layer_add(sg_roi_layer_add(sg_roi_layer("L"), tri), far)
  expect_equal(sum(sg_roi_mask(lyr, dims = c(10, 10), overlap = "last")), 45L)
  rect <- sg_roi_rect(2, 2, 8, 8, label = "r")
  expect_true(segmantR:::.sg_roi_is_axis_aligned_rect(rect$geometry[[1]]))
  expect_equal(sum(sg_roi_mask(rect, dims = c(10, 10))), 36L)
})
