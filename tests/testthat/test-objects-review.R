test_that("sg_image carries plane, origin, bands and semantics with defaults", {
  img <- new_sg_image(matrix(0, 3, 4))
  expect_equal(img$plane$z, 0L)
  expect_true(is.na(img$plane$c))
  expect_equal(img$origin, list(x = 0, y = 0, downsample = 1))
  expect_equal(img$value_semantics, "unknown")
  cube <- new_sg_image(array(0, c(2, 2, 3)),
                       bands = data.frame(wavelength_nm = c(500, 600, 700)),
                       plane = list(z = 2L, t = 1L),
                       value_semantics = "reflectance", id = "cube-1")
  expect_equal(cube$bands$c, 0:2)
  expect_equal(cube$plane$z, 2L)
  expect_error(new_sg_image(matrix(0, 2, 2), plane = list(z = -1)),
               class = "sg_validation_error")
  expect_error(new_sg_image(matrix(0, 2, 2), plane = list(q = 1)),
               class = "sg_validation_error")
  expect_error(new_sg_image(array(0, c(2, 2, 2)),
                            bands = data.frame(wavelength_nm = 1)),
               class = "sg_validation_error")
  expect_error(new_sg_image(matrix(0, 2, 2), value_semantics = "magic"))
})

test_that("subsetting shifts the origin and records non-contiguous subsets", {
  img <- new_sg_image(matrix(1:30, 5, 6) + 0, origin = list(x = 10, y = 20,
                                                            downsample = 2))
  sub <- img[2:3, 4:6]
  expect_equal(sub$origin$x, 10 + 3 * 2)
  expect_equal(sub$origin$y, 20 + 1 * 2)
  odd <- img[c(1, 3), 1:2]
  expect_true(is.na(odd$origin$x))
  expect_false(is.null(odd$transform_digest))
})

test_that("sg_read_image returns [y, x] orientation for non-square PNGs", {
  f <- withr::local_tempfile(fileext = ".png")
  grDevices::png(f, width = 40, height = 20)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
  graphics::rect(0, 0, 0.5, 1, col = "black", border = NA)
  grDevices::dev.off()
  local_mocked_bindings(.check_ebimage = function() FALSE)
  img <- sg_read_image(f)
  expect_equal(dim(img)[1:2], c(20L, 40L))
  px <- if (length(dim(img$pixels)) == 3L) img$pixels[, , 1] else img$pixels
  expect_lt(mean(px[, 5]), 0.2)
  expect_gt(mean(px[, 35]), 0.8)
  expect_match(img$source_digest, "^sha256:[0-9a-f]{64}$")
  expect_equal(img$metadata$source_name, basename(f))
})

test_that("mask legends are deterministic and follow the image binding", {
  l <- matrix(c(0L, 1L, 2L, 2L), 2)
  a <- sg_mask_legend(new_sg_mask(l, image_id = "img"))
  b <- sg_mask_legend(new_sg_mask(l, image_id = "img"))
  c <- sg_mask_legend(new_sg_mask(l, image_id = "other"))
  expect_identical(a, b)
  expect_false(identical(a$object_id, c$object_id))
  expect_equal(a$label, 1:2)
  bin <- sg_mask_legend(new_sg_mask(matrix(c(0L, 1L), 1), mask_type = "binary"))
  expect_equal(bin$class, "foreground")
  expect_error(new_sg_mask(l, legend = data.frame(label = c(1, 1))),
               class = "sg_validation_error")
})

test_that("revisions are content based and idempotent", {
  l <- matrix(c(0L, 1L, 1L, 0L), 2)
  m1 <- new_sg_mask(l, image_id = "x")
  m2 <- new_sg_mask(l, image_id = "x")
  expect_identical(sg_mask_revision(m1), sg_mask_revision(m2))
  m3 <- m1
  m3$labels[1, 1] <- 1L
  expect_false(identical(sg_mask_revision(m1), sg_mask_revision(m3)))
  expect_identical(sg_mask_revision(sg_mask_legend(m1, materialise = TRUE)),
                   sg_mask_revision(m1))
})

test_that("staged masks need an expected revision to be reviewed", {
  m <- sg_stage_mask(new_sg_mask(matrix(c(0L, 1L), 1)), source = "prediction")
  expect_equal(sg_mask_status(m)$status, "staged")
  expect_error(sg_review_mask(m), class = "sg_conflict_error")
  expect_error(sg_review_mask(m, expected_revision = "sha256:bad"),
               class = "sg_conflict_error")
  r <- sg_review_mask(m, reviewer = "rh",
                      expected_revision = sg_mask_revision(m))
  expect_equal(sg_mask_status(r)$status, "reviewed")
  expect_true(sg_mask_status(r)$consistent)
  expect_identical(sg_review_mask(r), r)
  expect_error(sg_stage_mask(r), class = "sg_conflict_error")
  r$labels[1, 1] <- 1L
  expect_false(sg_mask_status(r)$consistent)
})

test_that("reviewed masks are only replaced with revision and overwrite", {
  base <- sg_review_mask(new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2)))
  rev <- sg_mask_revision(base)
  cand <- new_sg_mask(matrix(c(1L, 1L, 1L, 0L), 2))
  err <- expect_error(sg_replace_mask(base, cand), class = "sg_conflict_error")
  expect_equal(err$code, "REVIEWED_OVERWRITE_DENIED")
  expect_error(sg_replace_mask(base, cand, expected_revision = rev),
               class = "sg_conflict_error")
  expect_error(sg_replace_mask(base, cand, expected_revision = "sha256:x",
                               overwrite = TRUE),
               class = "sg_conflict_error")
  out <- sg_replace_mask(base, cand, expected_revision = rev, overwrite = TRUE)
  st <- sg_mask_status(out)
  expect_equal(st$status, "staged")
  expect_equal(st$parent_revision, rev)
  same <- sg_replace_mask(base, new_sg_mask(base$labels))
  expect_equal(sg_mask_status(same)$status, "reviewed")
  expect_error(sg_replace_mask(base, new_sg_mask(matrix(0L, 3, 3))),
               class = "sg_validation_error")
})

test_that("corrections keep object ids, remap the legend and stage the result", {
  l <- matrix(0L, 6, 6)
  l[1:2, 1:2] <- 1L
  l[4:5, 4:5] <- 2L
  l[1:2, 5:6] <- 3L
  m <- sg_stage_mask(new_sg_mask(l, image_id = "img"))
  ids <- sg_mask_legend(m)$object_id
  out <- suppressMessages(sg_apply_corrections(
    m, list(list(action = "delete", cell_id = 2L))
  ))
  leg <- sg_mask_legend(out)
  expect_equal(leg$label, 1:2)
  expect_equal(leg$object_id, ids[c(1, 3)])
  expect_equal(sg_mask_status(out)$status, "staged")
  expect_equal(sg_mask_status(out)$parent_revision, sg_mask_revision(m))
  expect_length(out$provenance$corrections, 1L)
})
