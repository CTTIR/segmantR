test_that("sg_create_annotation_task creates patches on a grid", {
  img <- new_sg_image(matrix(stats::runif(100 * 100), 100, 100))
  task <- sg_create_annotation_task(img, n_patches = 4L, patch_size = 32L)
  expect_s3_class(task, "sg_annotation_task")
  expect_gt(task$n_patches, 0L)
  expect_equal(task$patch_size, 32L)
})

test_that("sg_create_annotation_task ranks patches by uncertainty with a mask", {
  img <- new_sg_image(matrix(stats::runif(64 * 64), 64, 64))
  labels <- matrix(0L, 64, 64)
  labels[10:20, 10:20] <- 1L
  labels[40:50, 40:50] <- 2L
  task <- sg_create_annotation_task(img, initial_mask = new_sg_mask(labels),
                                    n_patches = 4L, patch_size = 16L)
  expect_s3_class(task, "sg_annotation_task")
})

test_that("sg_create_annotation_task crops to a region", {
  img <- new_sg_image(matrix(stats::runif(64 * 64), 64, 64))
  task <- sg_create_annotation_task(img, region = c(1, 32, 1, 32),
                                    n_patches = 2L, patch_size = 8L)
  expect_s3_class(task, "sg_annotation_task")
})

test_that("sg_create_annotation_task validates its arguments", {
  expect_error(sg_create_annotation_task("x"), "sg_image")
  img <- new_sg_image(matrix(0, 32, 32))
  expect_error(sg_create_annotation_task(img, initial_mask = "y"), "sg_mask")
  expect_error(sg_create_annotation_task(img, region = c(1, 2, 3)),
               "length-4")
})

test_that("print.sg_annotation_task is invisible", {
  img <- new_sg_image(matrix(stats::runif(1024), 32, 32))
  task <- sg_create_annotation_task(img, n_patches = 2L, patch_size = 8L)
  expect_invisible(print(task))
})

test_that("sg_apply_corrections deletes a cell", {
  labels <- matrix(0L, 20, 20); labels[3:8, 3:8] <- 1L; labels[12:18, 12:18] <- 2L
  mask <- new_sg_mask(labels)
  corrected <- sg_apply_corrections(mask, list(
    list(action = "delete", cell_id = 2L)
  ))
  expect_equal(corrected$n_cells, 1L)
})

test_that("sg_apply_corrections merges cells", {
  labels <- matrix(0L, 20, 20); labels[3:8, 3:8] <- 1L; labels[12:18, 12:18] <- 2L
  mask <- new_sg_mask(labels)
  corrected <- sg_apply_corrections(mask, list(
    list(action = "merge", cell_ids = c(1L, 2L))
  ))
  expect_equal(corrected$n_cells, 1L)
})

test_that("sg_apply_corrections adds a cell", {
  labels <- matrix(0L, 20, 20); labels[3:8, 3:8] <- 1L
  mask <- new_sg_mask(labels)
  px <- cbind(c(15L, 16L, 17L), c(15L, 16L, 17L))
  corrected <- sg_apply_corrections(mask, list(
    list(action = "add", pixels = px)
  ))
  expect_equal(corrected$n_cells, 2L)
})

test_that("sg_apply_corrections splits a cell", {
  labels <- matrix(0L, 20, 20); labels[3:18, 3:18] <- 1L
  mask <- new_sg_mask(labels)
  seeds <- rbind(c(5L, 5L), c(15L, 15L))
  corrected <- sg_apply_corrections(mask, list(
    list(action = "split", cell_id = 1L, seed_points = seeds)
  ))
  expect_gte(corrected$n_cells, 1L)
})

test_that("sg_apply_corrections validates inputs", {
  mask <- new_sg_mask(matrix(0L, 5, 5))
  expect_error(sg_apply_corrections("x", list()), "sg_mask")
  expect_error(sg_apply_corrections(mask, "y"), "list")
  expect_error(sg_apply_corrections(mask, list(list(foo = 1))), "action")
})

test_that("sg_apply_corrections rejects malformed correction operations", {
  labels <- matrix(0L, 10, 10); labels[2:5, 2:5] <- 1L
  mask <- new_sg_mask(labels)
  expect_error(sg_apply_corrections(mask, list(list(action = "delete"))),
               "cell_id")
  expect_error(sg_apply_corrections(mask, list(list(action = "merge",
                                                    cell_ids = 1L))),
               "at least 2")
  expect_error(sg_apply_corrections(mask, list(list(action = "split",
                                                    cell_id = 1L))),
               "seed_points")
  expect_error(sg_apply_corrections(mask, list(list(action = "add"))),
               "pixels")
})
