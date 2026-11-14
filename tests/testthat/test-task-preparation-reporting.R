test_that("annotation preparation reports its scope and retains the initial model", {
  local_mocked_bindings(
    .check_cellpose = function() invisible(TRUE),
    sg_train_cellpose = function(...) stop("unexpected training")
  )
  withr::local_seed(1)
  image <- new_sg_image(matrix(seq_len(64 * 64), 64, 64))
  expect_message(
    result <- sg_active_learning_loop(image, n_rounds = 2L,
                                      patches_per_round = 2L, patch_size = 16L,
                                      initial_model = "unchanged-initial-model"),
    "No model training or corrections have been applied"
  )
  expect_identical(result$final_model, "unchanged-initial-model")
  expect_length(result$rounds, 2L)
  expect_identical(result$metrics$total_patches, 4L)
  expect_true(all(vapply(result$rounds, function(x) {
    identical(x$model_used, result$final_model)
  }, logical(1))))
})
