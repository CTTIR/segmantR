test_that("sg_filter_cells removes cells outside size limits", {
  labels <- matrix(0L, 20L, 20L)
  labels[3:5, 3:5]   <- 1L  # area 9
  labels[10:18, 10:18] <- 2L  # area 81
  mask <- new_sg_mask(labels)
  filt <- sg_filter_cells(mask, min_area = 50L, max_area = 5000L,
                          min_circularity = 0, max_eccentricity = 1)
  expect_lte(filt$n_cells, mask$n_cells)
  expect_true(all(filt$labels[3:5, 3:5] == 0L))
})

test_that("sg_filter_cells passes through empty masks", {
  mask <- new_sg_mask(matrix(0L, 5L, 5L))
  expect_equal(sg_filter_cells(mask)$n_cells, 0L)
})
