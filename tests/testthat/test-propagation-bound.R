# Independent support oracle: minimum Manhattan distance to any supplied seed.
propagation_support_reference <- function(seeds, steps) {
  positions <- which(seeds > 0L, arr.ind = TRUE)
  distance <- matrix(Inf, nrow(seeds), ncol(seeds))
  for (i in seq_len(nrow(positions))) {
    distance <- pmin(distance, abs(row(seeds) - positions[i, 1L]) +
                               abs(col(seeds) - positions[i, 2L]))
  }
  distance <= steps
}

test_that("propagation support matches independent geometry at image borders", {
  cases <- list(matrix(0L, 7L, 11L), matrix(0L, 4L, 9L),
                 matrix(0L, 1L, 7L), matrix(0L, 7L, 1L), matrix(0L, 1L, 1L))
  cases[[1]][4L, 6L] <- 1L
  cases[[2]][1L, 1L] <- 1L
  cases[[2]][4L, 9L] <- 2L
  cases[[3]][1L, 3L] <- 1L
  cases[[4]][3L, 1L] <- 1L
  cases[[5]][1L, 1L] <- 1L
  cases[[6]] <- matrix(0L, 5L, 8L)
  for (seeds in cases) {
    for (steps in c(0L, 1L, 2L, 100L)) {
      expected <- propagation_support_reference(seeds, steps)
      expect_identical(segmantR:::.sg_propagation_support(seeds, steps), expected)
      expect_identical(segmantR:::.voronoi_propagate_r(seeds, expand_max = steps) > 0L,
                       expected)
    }
  }
})

test_that("real EBImage propagation honors the bound without changing seed identities", {
  skip_if_not_installed("EBImage")
  for (shape in list(c(7L, 11L), c(1L, 7L), c(7L, 1L))) {
    seeds <- matrix(0L, shape[1L], shape[2L])
    seeds[1L, 1L] <- 2L
    seeds[shape[1L], shape[2L]] <- 5L
    image <- new_sg_image(matrix(0, shape[1L], shape[2L]))
    mask <- new_sg_mask(seeds)
    for (steps in c(0L, 1L, 2L, 100L)) {
      result <- suppressMessages(sg_segment_propagate(image, mask,
        expand_max = steps, engine = "ebimage"))
      expect_identical(dim(result$labels), shape)
      expect_identical(result$labels > 0L,
                       propagation_support_reference(seeds, steps))
      expect_identical(result$labels[seeds > 0L], seeds[seeds > 0L])
      expect_identical(result$model_info$expand_max, steps)
      expect_identical(result$model_info$method, "propagate:ebimage")
      if (steps == 0L) expect_identical(result$labels, seeds)
    }
  }
  seeds <- matrix(0L, 4L, 9L)
  empty <- suppressMessages(sg_segment_propagate(new_sg_image(matrix(0, 4L, 9L)),
    new_sg_mask(seeds), expand_max = 3L, engine = "ebimage"))
  expect_identical(empty$labels, seeds)
})

test_that("propagation refuses ambiguous bounds and mismatched geometry", {
  image <- new_sg_image(matrix(0, 5L, 7L))
  seeds <- matrix(0L, 5L, 7L)
  seeds[3L, 4L] <- 1L
  mask <- new_sg_mask(seeds)
  for (bad in list(-1, 1.5, NA_real_, NaN, Inf, numeric(), c(1, 2),
                   "1", TRUE, matrix(1), .Machine$integer.max + 1)) {
    expect_error(sg_segment_propagate(image, mask, expand_max = bad), "expand_max")
  }
  for (bad in list(-1, NA_real_, NaN, Inf, c(1, 2), matrix(1))) {
    expect_error(sg_segment_propagate(image, mask, lambda = bad))
  }
  expect_error(sg_segment_propagate(image, new_sg_mask(matrix(0L, 7L, 5L))),
               "dimensions must match")
  expect_error(sg_segment_propagate(image, mask,
    membrane_image = new_sg_image(matrix(0, 7L, 5L))), "dimensions must match")
})
