# helper local to this file
geom_type <- function(roi) as.character(sf::st_geometry_type(roi$geometry))

test_that("constructors produce the expected geometry types", {
  expect_identical(geom_type(sg_roi_point(1, 2, label = "a")), "POINT")
  expect_identical(geom_type(sg_roi_rect(0, 0, 4, 4, label = "a")), "POLYGON")
  expect_identical(geom_type(sg_roi_circle(5, 5, 2, label = "a")), "POLYGON")
  expect_identical(geom_type(sg_roi_ellipse(5, 5, 3, 2, label = "a")), "POLYGON")
  sq <- matrix(c(0, 0, 4, 0, 4, 4, 0, 4), ncol = 2, byrow = TRUE)
  expect_identical(geom_type(sg_roi_polygon(sq, label = "a")), "POLYGON")
  expect_identical(
    geom_type(sg_roi_freehand(cbind(c(0, 4, 2), c(0, 0, 4)), label = "a")),
    "POLYGON"
  )
})

test_that("rect validates ordering of bounds", {
  expect_error(sg_roi_rect(4, 0, 0, 4, label = "a"), "xmax")
  expect_error(sg_roi_rect(0, 4, 4, 0, label = "a"), "ymax")
})

test_that("area is correct and NA for non-areal geometry", {
  expect_equal(sg_roi_area(sg_roi_rect(0, 0, 10, 5, label = "a")), 50)
  expect_true(is.na(sg_roi_area(sg_roi_point(1, 1, label = "a"))))
  expect_equal(sg_roi_area(donut_roi()), 100 - 16)
})

test_that("centroid and bbox are correct", {
  r <- sg_roi_rect(0, 0, 10, 10, label = "a")
  expect_equal(sg_roi_centroid(r), c(5, 5))
  expect_equal(sg_roi_bbox(r), c(0, 0, 10, 10))
})

test_that("sg_roi_rescale round-trips exactly", {
  r <- sg_roi_rect(0, 0, 100, 100, label = "a")
  back <- sg_roi_rescale(sg_roi_rescale(r, 0, 2), 2, 0)
  expect_equal(
    sf::st_coordinates(r$geometry),
    sf::st_coordinates(back$geometry),
    tolerance = 1e-9
  )
  expect_identical(back$level, 0L)
})

test_that("rescale changes coordinates by the expected power-of-two factor", {
  r <- sg_roi_point(100, 80, label = "a")
  r2 <- sg_roi_rescale(r, 0, 2)
  co <- as.numeric(sf::st_coordinates(r2$geometry))
  expect_equal(co, c(25, 20))
  expect_identical(r2$level, 2L)
})

test_that("rescale does not modify its input (immutability)", {
  r <- sg_roi_rect(0, 0, 100, 100, label = "a")
  snapshot <- r
  invisible(sg_roi_rescale(r, 0, 2))
  expect_identical(r, snapshot)
})

test_that("buffer and simplify return sg_roi", {
  r <- sg_roi_point(10, 10, label = "a")
  b <- sg_roi_buffer(r, 5)
  expect_s3_class(b, "sg_roi")
  expect_gt(sg_roi_area(b), 0)
  s <- sg_roi_simplify(sg_roi_circle(50, 50, 10, n_seg = 128, label = "a"), 1)
  expect_s3_class(s, "sg_roi")
})

test_that("invalid geometry is repaired with a warning", {
  bow <- matrix(c(0, 0, 10, 10, 10, 0, 0, 10, 0, 0), ncol = 2, byrow = TRUE)
  expect_warning(sg_roi_polygon(bow, label = "bow"), "Repaired")
})

test_that("dots set reserved fields and store attributes", {
  r <- sg_roi_point(1, 1, label = "a", source = "imported", grade = 3)
  expect_identical(r$source, "imported")
  expect_identical(r$attributes$grade, 3)
})

test_that("st_as_sf and st_geometry methods work", {
  r <- sg_roi_rect(0, 0, 4, 4, label = "a")
  expect_s3_class(sf::st_as_sf(r), "sf")
  expect_s3_class(sf::st_geometry(r), "sfc")
})

test_that("plot returns a ggplot without drawing", {
  p <- plot(sg_roi_rect(0, 0, 4, 4, label = "a"))
  expect_s3_class(p, "ggplot")
})

test_that("print and format produce output", {
  expect_output(print(sg_roi_rect(0, 0, 4, 4, label = "a")), "sg_roi")
})

test_that("sg_roi_polygon accepts holes and rejects bad coords", {
  outer <- matrix(c(0, 0, 10, 0, 10, 10, 0, 10), ncol = 2, byrow = TRUE)
  inner <- matrix(c(3, 3, 3, 7, 7, 7, 7, 3), ncol = 2, byrow = TRUE)
  r <- sg_roi_polygon(outer, label = "a", hole = inner)
  expect_equal(sg_roi_area(r), 100 - 16)
  expect_error(sg_roi_polygon("nope", label = "a"), "numeric matrix")
})

test_that("sg_roi_freehand rejects malformed input", {
  expect_error(sg_roi_freehand(matrix(1:4, ncol = 2), label = "a"), "at least 3 rows")
})

test_that("physical area uses the pixel_size attribute or errors", {
  r <- sg_roi_rect(0, 0, 10, 10, label = "a", pixel_size = c(2, 3))
  expect_equal(sg_roi_area(r, units = "physical"), 100 * 6)
  r2 <- sg_roi_rect(0, 0, 10, 10, label = "a")
  expect_error(sg_roi_area(r2, units = "physical"), "pixel_size")
})

test_that("sg_roi_simplify with a tolerance reduces vertices", {
  r <- sg_roi_simplify(sg_roi_circle(50, 50, 20, n_seg = 128, label = "a"), tolerance = 2)
  expect_s3_class(r, "sg_roi")
  expect_lt(nrow(sf::st_coordinates(r$geometry)), 129)
})

test_that("roi plot and sf coercions work", {
  r <- sg_roi_rect(0, 0, 4, 4, label = "a")
  expect_s3_class(plot(r), "ggplot")
  expect_s3_class(sf::st_as_sf(r), "sf")
  expect_s3_class(sf::st_geometry(r), "sfc")
})

test_that("reserved ROI fields are not set by partial name matches", {
  r <- sg_roi_point(1, 2, label = "cell", idx = 7)
  expect_false(identical(r$id, "7"))
  expect_equal(r$attributes$idx, 7)
  r <- sg_roi_point(1, 2, label = "cell", source_file = "slide.tif")
  expect_equal(r$source, "manual")
  expect_equal(r$attributes$source_file, "slide.tif")
  r <- sg_roi_point(1, 2, label = "cell", authority = "WHO")
  expect_false(identical(r$author, "WHO"))
  expect_equal(r$attributes$authority, "WHO")
  r <- sg_roi_point(1, 2, label = "cell", id = "c1", source = "qc")
  expect_equal(c(r$id, r$source), c("c1", "qc"))
})
