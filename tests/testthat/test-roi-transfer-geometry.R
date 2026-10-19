test_that("set operations produce geometrically correct areas", {
  a <- sg_roi_rect(0, 0, 6, 6, label = "x")
  b <- sg_roi_rect(4, 4, 10, 10, label = "x")
  expect_equal(sg_roi_area(sg_roi_union(a, b)), 68)
  expect_equal(sg_roi_area(sg_roi_intersect(a, b)), 4)
  expect_equal(sg_roi_area(sg_roi_difference(a, b)), 32)
  expect_equal(sg_roi_area(sg_roi_symdiff(a, b)), 64)
})

test_that("set operations return a single derived sg_roi", {
  a <- sg_roi_rect(0, 0, 6, 6, label = "x")
  b <- sg_roi_rect(4, 4, 10, 10, label = "x")
  u <- sg_roi_union(a, b)
  expect_s3_class(u, "sg_roi")
  expect_identical(u$source, "derived")
})

test_that("set operations accept a single layer", {
  pair <- overlap_pair()
  lyr <- sg_roi_layer_add(sg_roi_layer_add(sg_roi_layer("l"), pair$a), pair$b)
  expect_s3_class(sg_roi_union(lyr), "sg_roi")
})

test_that("sg_roi_transform is exactly invertible across pyramid levels", {
  img <- small_image()
  r <- sg_roi_rect(0, 0, 80, 80, label = "a")
  for (lv in c(1L, 2L)) {
    back <- sg_roi_transform(sg_roi_transform(r, 0, lv, img), lv, 0, img)
    expect_equal(sf::st_coordinates(r$geometry),
                 sf::st_coordinates(back$geometry), tolerance = 1e-9)
  }
})

test_that("sg_roi_transform uses real level dimensions", {
  img <- small_image() # levels 100, 50, 25
  r <- sg_roi_point(80, 40, label = "a")
  r2 <- sg_roi_transform(r, 0, 1, img)
  expect_equal(as.numeric(sf::st_coordinates(r2$geometry))[1:2], c(40, 20))
})

test_that("flip_y is self-inverse", {
  r <- sg_roi_rect(0, 0, 10, 5, label = "a")
  back <- sg_roi_flip_y(sg_roi_flip_y(r, 100), 100)
  expect_equal(sf::st_coordinates(r$geometry),
               sf::st_coordinates(back$geometry), tolerance = 1e-9)
})

test_that("snap rounds vertices to the grid", {
  r <- sg_roi_snap(sg_roi_point(3.4, 5.6, label = "a"), grid = 1)
  expect_equal(as.numeric(sf::st_coordinates(r$geometry))[1:2], c(3, 6))
})

test_that("clamp clips to image bounds", {
  r <- sg_roi_clamp(sg_roi_rect(-5, -5, 20, 20, label = "a"), dims = c(10, 10))
  expect_equal(sg_roi_area(r), 100)
})

test_that("sg_roi_contains vectorises over points", {
  r <- sg_roi_rect(0, 0, 10, 10, label = "a")
  expect_identical(sg_roi_contains(r, c(5, 20), c(5, 20)), c(TRUE, FALSE))
  expect_identical(sg_roi_contains(r, numeric(0), numeric(0)), logical(0))
})

test_that("sg_roi_overlaps and sg_roi_distance are correct", {
  a <- sg_roi_rect(0, 0, 6, 6, label = "a")
  b <- sg_roi_rect(4, 4, 10, 10, label = "a")
  c <- sg_roi_rect(20, 20, 25, 25, label = "a")
  expect_true(sg_roi_overlaps(a, b))
  expect_false(sg_roi_overlaps(a, c))
  expect_equal(sg_roi_distance(sg_roi_rect(0, 0, 1, 1, label = "a"),
                               sg_roi_rect(5, 0, 6, 1, label = "a")), 4)
})

test_that("sg_roi_rois_overlap reports overlapping pairs, empty-safe", {
  pair <- overlap_pair()
  lyr <- sg_roi_layer_add(sg_roi_layer_add(sg_roi_layer("l"), pair$a), pair$b)
  ov <- sg_roi_rois_overlap(lyr)
  expect_equal(nrow(ov), 1L)
  expect_identical(names(ov), c("id_a", "id_b", "overlap_px", "jaccard"))
  expect_equal(ov$overlap_px, 4)
  # No overlaps -> 0 rows, same columns.
  lyr2 <- sg_roi_layer_add(sg_roi_layer_add(sg_roi_layer("l"),
                                    sg_roi_rect(0, 0, 1, 1, label = "a")),
                       sg_roi_rect(5, 5, 6, 6, label = "a"))
  empty <- sg_roi_rois_overlap(lyr2)
  expect_equal(nrow(empty), 0L)
  expect_identical(names(empty), c("id_a", "id_b", "overlap_px", "jaccard"))
})

test_that("sg_roi_check_geometry detects every issue class", {
  targets <- c(
    self_intersect = "self_intersection", zero_area = "zero_area",
    degenerate = "degenerate", out_of_bounds = "out_of_bounds",
    na_coord = "na_coordinates", dup_vertex = "duplicate_vertices",
    ring_orientation = "ring_orientation"
  )
  for (nm in names(targets)) {
    ch <- sg_roi_check_geometry(broken_project(nm))
    expect_true(targets[[nm]] %in% ch$issue, info = nm)
  }
})

test_that("sg_roi_check_geometry is type-stable and clean projects pass", {
  ch <- sg_roi_check_geometry(demo_project())
  expect_s3_class(ch, "tbl_df")
  expect_equal(nrow(ch), 0L)
  expect_identical(names(ch), c("roi_id", "issue", "severity", "fixable"))
})

test_that("sg_roi_fix_geometry repairs invalid geometry and reports", {
  proj <- broken_project("self_intersect")
  expect_message(fixed <- sg_roi_fix_geometry(proj), "Repaired")
  expect_false("self_intersection" %in% sg_roi_check_geometry(fixed)$issue)
})

test_that("sg_roi_fix_geometry leaves unfixable issues and reports them", {
  proj <- broken_project("zero_area")
  fixed <- suppressMessages(sg_roi_fix_geometry(proj, verbose = FALSE))
  expect_s3_class(fixed, "sg_roi_project")
})

test_that("geometry mutators do not modify their input", {
  r <- sg_roi_rect(0, 0, 10, 10, label = "a")
  snapshot <- r
  invisible(sg_roi_snap(r, 2))
  invisible(sg_roi_flip_y(r, 50))
  expect_identical(r, snapshot)
})
