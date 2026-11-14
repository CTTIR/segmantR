test_that("pure-R propagation records actual controls and sparse cell counts", {
  img <- new_sg_image(matrix(seq_len(25), 5, 5))
  seeds <- matrix(0L, 5, 5); seeds[2, 2] <- 2L; seeds[4, 4] <- 5L
  mask <- new_sg_mask(seeds)
  expect_message(a <- sg_segment_propagate(img, mask, lambda = 0,
                   expand_max = 1L, engine = "voronoi_r"), "assigned 2 cells")
  b <- suppressMessages(sg_segment_propagate(img, mask, lambda = 100,
                   expand_max = 1L, engine = "voronoi_r"))
  expect_identical(a$labels, b$labels)
  expect_false(a$model_info$lambda_applied)
  expect_identical(a$model_info$lambda, 0)
  expect_identical(b$model_info$lambda, 100)
  expect_null(a$model_info$membrane_threshold)
  expect_null(a$model_info$membrane_quantile)
  membrane <- matrix(seq_len(25), 5, 5)
  out <- suppressMessages(sg_segment_propagate(img, mask,
           membrane_image = new_sg_image(membrane), engine = "voronoi_r",
           expand_max = 20L))
  threshold <- unname(stats::quantile(membrane, 0.9))
  expect_equal(out$model_info$membrane_threshold, threshold)
  expect_identical(out$model_info$membrane_quantile, 0.9)
  expect_false(out$model_info$lambda_applied)
  expect_true(all(out$labels[membrane >= threshold & seeds == 0L] == 0L))
  expect_identical(out$labels[seeds > 0L], seeds[seeds > 0L])
})

test_that("actual EBImage propagation records lambda as applied", {
  skip_if_not_installed("EBImage")
  seeds <- matrix(0L, 3, 5); seeds[2, 3] <- 5L
  out <- sg_segment_propagate(new_sg_image(matrix(1, 3, 5)),
           new_sg_mask(seeds), lambda = 0.1, engine = "ebimage", expand_max = 1L)
  expect_true(out$model_info$lambda_applied)
  expect_identical(out$model_info$lambda, 0.1)
  expect_identical(out$model_info$method, "propagate:ebimage")
})
