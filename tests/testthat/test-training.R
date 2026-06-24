test_that("sg_train_cellpose validates training data shape", {
  # Bypass the python availability check so validation logic is reached.
  local_mocked_bindings(.check_cellpose = function() invisible(TRUE))
  expect_error(sg_train_cellpose(list()), "non-empty list")
  expect_error(sg_train_cellpose(list(list(image = 1))), "\\$image and")
  expect_error(
    sg_train_cellpose(list(list(image = "x", mask = new_sg_mask(matrix(0L, 4, 4))))),
    "sg_image"
  )
  expect_error(
    sg_train_cellpose(list(list(image = new_sg_image(matrix(0, 4, 4)),
                                mask = "y"))),
    "sg_mask"
  )
})

test_that("sg_train_cellpose surfaces the python check error", {
  local_mocked_bindings(
    .check_cellpose = function() cli::cli_abort("Cellpose not available")
  )
  td <- list(list(image = new_sg_image(matrix(0, 4, 4)),
                  mask = new_sg_mask(matrix(0L, 4, 4))))
  expect_error(sg_train_cellpose(td), "not available")
})

test_that("sg_active_learning_loop validates its image", {
  expect_error(sg_active_learning_loop("x"), "sg_image")
})

test_that("sg_active_learning_loop runs annotation rounds", {
  local_mocked_bindings(.check_cellpose = function() invisible(TRUE))
  img <- new_sg_image(matrix(stats::runif(64 * 64), 64, 64))
  result <- sg_active_learning_loop(img, n_rounds = 2L,
                                    patches_per_round = 3L, patch_size = 16L)
  expect_s3_class(result, "sg_hitl_result")
  expect_equal(result$n_rounds, 2L)
  expect_length(result$rounds, 2L)
})

test_that("print.sg_hitl_result is invisible", {
  local_mocked_bindings(.check_cellpose = function() invisible(TRUE))
  img <- new_sg_image(matrix(stats::runif(64 * 64), 64, 64))
  result <- sg_active_learning_loop(img, n_rounds = 1L,
                                    patches_per_round = 2L, patch_size = 16L)
  expect_invisible(print(result))
})
