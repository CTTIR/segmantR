test_that("sg_preprocess returns an sg_image after stretch + denoise", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20))
  out <- sg_preprocess(img, contrast = "stretch", denoise = TRUE)
  expect_s3_class(out, "sg_image")
  expect_equal(dim(out), c(20L, 20L))
  # stretch maps values into [0, 1]
  expect_gte(min(out$pixels), 0)
  expect_lte(max(out$pixels), 1)
})

test_that("sg_preprocess default returns the image unchanged", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  out <- sg_preprocess(img)
  expect_equal(out$pixels, img$pixels)
})

test_that("sg_preprocess clahe runs and returns valid pixels", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  out <- sg_preprocess(img, contrast = "clahe")
  expect_s3_class(out, "sg_image")
  expect_false(anyNA(out$pixels))
})

test_that("sg_preprocess stain normalisation returns valid pixels", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)))
  out <- sg_preprocess(img, stain_normalize = "reinhard")
  expect_s3_class(out, "sg_image")
  expect_gte(min(out$pixels), 0)
  expect_lte(max(out$pixels), 1)
})

test_that("sg_preprocess macenko falls through to reinhard path", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)))
  out <- sg_preprocess(img, stain_normalize = "macenko")
  expect_s3_class(out, "sg_image")
})

test_that("sg_preprocess resamples when resolution is set", {
  img <- new_sg_image(matrix(stats::runif(400), 20, 20),
                      resolution = list(x_um = 0.5, y_um = 0.5))
  out <- sg_preprocess(img, target_resolution = 1.0)
  expect_lt(dim(out)[1], 20L)
  expect_equal(out$resolution$x_um, 1.0)
})

test_that("sg_preprocess warns when resampling without resolution", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  expect_message(sg_preprocess(img, target_resolution = 1.0),
                 "resolution is not set")
})

test_that("sg_preprocess rejects bad target_resolution", {
  img <- new_sg_image(matrix(0, 5, 5), resolution = list(x_um = 1, y_um = 1))
  expect_error(sg_preprocess(img, target_resolution = -1))
})

test_that("sg_preprocess validates its image argument", {
  expect_error(sg_preprocess("not an image"))
})

test_that("sg_preprocess denoise output is deterministic", {
  img <- new_sg_image(matrix(seq_len(100) / 100, 10, 10))
  out <- sg_preprocess(img, denoise = TRUE)
  expect_snapshot_value(round(out$pixels, 4), style = "serialize")
})

test_that("sg_stain_deconvolve returns three stain channels", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)),
                      channels = c("R", "G", "B"))
  stains <- sg_stain_deconvolve(img)
  expect_named(stains, c("hematoxylin", "eosin", "residual"))
  expect_s3_class(stains$hematoxylin, "sg_image")
})

test_that("sg_stain_deconvolve supports the ruifrok method", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)),
                      channels = c("R", "G", "B"))
  stains <- sg_stain_deconvolve(img, method = "ruifrok")
  expect_length(stains, 3L)
})

test_that("sg_stain_deconvolve accepts a custom stain matrix", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)),
                      channels = c("R", "G", "B"))
  stains <- sg_stain_deconvolve(img, stains = diag(3))
  expect_length(stains, 3L)
})

test_that("sg_stain_deconvolve errors on a non-RGB image", {
  img <- new_sg_image(matrix(stats::runif(100), 10, 10))
  expect_error(sg_stain_deconvolve(img), "RGB image")
})

test_that("sg_stain_deconvolve errors on a singular stain matrix", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)),
                      channels = c("R", "G", "B"))
  singular <- matrix(0, 3, 3)
  singular[1, 1] <- 1
  expect_error(sg_stain_deconvolve(img, stains = singular), "singular")
})

test_that(".contrast_stretch returns input on a constant image", {
  m <- matrix(0.4, 4, 4)
  expect_equal(segmantR:::.contrast_stretch(m), m)
})

test_that(".clahe_2d returns input on a constant image", {
  m <- matrix(0.4, 4, 4)
  expect_equal(segmantR:::.clahe_2d(m), m)
})

test_that(".mean_filter handles 3D arrays", {
  arr <- array(stats::runif(75), dim = c(5, 5, 3))
  out <- segmantR:::.mean_filter(arr, size = 3L)
  expect_equal(dim(out), c(5L, 5L, 3L))
})

test_that(".resample_bilinear handles 3D arrays", {
  arr <- array(stats::runif(48), dim = c(4, 4, 3))
  out <- segmantR:::.resample_bilinear(arr, 0.5)
  expect_equal(dim(out)[3], 3L)
})

test_that(".estimate_macenko_stains falls back when too few stained pixels", {
  pixels <- array(1 - 1e-9, dim = c(5, 5, 3))  # near-white -> low OD
  stains <- segmantR:::.estimate_macenko_stains(pixels)
  expect_equal(dim(stains), c(3L, 3L))
})

test_that(".estimate_macenko_stains works with sufficient stained pixels", {
  set.seed(7)
  pixels <- array(stats::runif(3 * 100, 0.1, 0.6), dim = c(10, 10, 3))
  stains <- segmantR:::.estimate_macenko_stains(pixels)
  expect_equal(dim(stains), c(3L, 3L))
})

test_that(".clahe handles 3D arrays", {
  arr <- array(stats::runif(75), dim = c(5, 5, 3))
  out <- segmantR:::.clahe(arr)
  expect_equal(dim(out), c(5L, 5L, 3L))
})

test_that(".resample_2d upscales and downscales", {
  m <- matrix(seq_len(16) / 16, 4, 4)
  up <- segmantR:::.resample_2d(m, 2)
  down <- segmantR:::.resample_2d(m, 0.5)
  expect_equal(dim(up), c(8L, 8L))
  expect_equal(dim(down), c(2L, 2L))
})

test_that(".ruifrok_stain_matrix is a 3x3 matrix", {
  expect_equal(dim(segmantR:::.ruifrok_stain_matrix()), c(3L, 3L))
})

test_that("sg_stain_deconvolve records deconvolution metadata", {
  img <- new_sg_image(array(stats::runif(300), dim = c(10, 10, 3)),
                      channels = c("R", "G", "B"))
  stains <- sg_stain_deconvolve(img, method = "ruifrok")
  expect_equal(stains$hematoxylin$metadata$deconvolution_method, "ruifrok")
  expect_equal(stains$eosin$metadata$stain_channel, "eosin")
})
