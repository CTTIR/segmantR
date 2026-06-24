make_model <- function(loss = NULL) {
  new_sg_trained_model(
    model_path = tempdir(),
    backend = "cellpose",
    base_model = "cyto3",
    training_metrics = c(
      list(n_epochs = 100L, final_loss = 0.05),
      if (!is.null(loss)) list(loss = loss) else NULL
    ),
    model_card = list(author = "Test User", tissue = "lung")
  )
}

test_that("new_sg_trained_model constructs and validates", {
  mdl <- make_model()
  expect_s3_class(mdl, "sg_trained_model")
  expect_equal(mdl$backend, "cellpose")
  expect_error(new_sg_trained_model(model_path = 1, backend = "cellpose",
                                    base_model = "x",
                                    training_metrics = list()))
  expect_error(new_sg_trained_model(model_path = "p", backend = "cellpose",
                                    base_model = "x",
                                    training_metrics = "notalist"))
})

test_that("new_sg_trained_model rejects unknown backends", {
  expect_error(new_sg_trained_model(model_path = "p", backend = "nope",
                                    base_model = "x",
                                    training_metrics = list()))
})

test_that("print.sg_trained_model is invisible and stable", {
  mdl <- make_model()
  expect_invisible(print(mdl))
})

test_that("summary.sg_trained_model lists metrics and the card", {
  mdl <- make_model()
  expect_invisible(summary(mdl))
})

test_that("plot.sg_trained_model returns NULL without a loss curve", {
  mdl <- make_model()
  expect_message(p <- plot(mdl), "No loss curve")
  expect_null(p)
})

test_that("plot.sg_trained_model returns a ggplot with a loss curve", {
  mdl <- make_model(loss = c(1, 0.6, 0.3, 0.15))
  p <- plot(mdl)
  expect_s3_class(p, "ggplot")
})

test_that("sg_model_card returns a field/value tibble", {
  mdl <- make_model()
  card <- sg_model_card(mdl)
  expect_s3_class(card, "tbl_df")
  expect_true(all(c("field", "value") %in% names(card)))
  expect_true(any(card$field == "Backend"))
})

test_that("summary and model card format POSIXct and vector metrics", {
  mdl <- new_sg_trained_model(
    model_path = tempdir(), backend = "stardist", base_model = "2D",
    training_metrics = list(timestamp = Sys.time(),
                            loss = c(1, 0.5, 0.25),
                            n_epochs = 10L),
    model_card = list(notes = "ok")
  )
  expect_invisible(summary(mdl))
  card <- sg_model_card(mdl)
  expect_true(any(grepl("timestamp", card$field)))
  expect_true(any(grepl("loss", card$field)))
})

test_that("sg_model_card validates its argument", {
  expect_error(sg_model_card("x"), "sg_trained_model")
})

test_that("sg_package_model and sg_load_model round-trip", {
  weights <- withr::local_tempdir()
  writeLines("fake weights", file.path(weights, "model.bin"))
  mdl <- new_sg_trained_model(
    model_path = weights, backend = "cellpose", base_model = "cyto3",
    training_metrics = list(n_epochs = 50L),
    model_card = list(author = "RH")
  )
  archive <- withr::local_tempfile(fileext = ".segmantR")
  out <- sg_package_model(mdl, archive, name = "my_model",
                          description = "test model")
  skip_if(!file.exists(out), "zip utility unavailable")
  loaded <- sg_load_model(out)
  expect_s3_class(loaded, "sg_trained_model")
  expect_equal(loaded$backend, "cellpose")
  expect_equal(loaded$base_model, "cyto3")
})

test_that("sg_package_model validates its argument", {
  expect_error(sg_package_model("x", tempfile()), "sg_trained_model")
})

test_that("sg_load_model errors on a missing file", {
  expect_error(sg_load_model(tempfile(fileext = ".segmantR")), "not found")
})

test_that("sg_load_model errors when the archive lacks a model card", {
  archive <- withr::local_tempfile(fileext = ".zip")
  d <- withr::local_tempdir()
  writeLines("x", file.path(d, "stuff.txt"))
  utils::zip(archive, files = list.files(d, full.names = TRUE),
             extras = "-j", flags = "-r9Xq")
  skip_if(!file.exists(archive), "zip utility unavailable")
  expect_error(sg_load_model(archive), "model_card.json")
})
