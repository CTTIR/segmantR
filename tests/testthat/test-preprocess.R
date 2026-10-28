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

test_that("sg_stain_deconvolve recovers known stain concentrations", {
  stains <- segmantR:::.ruifrok_stain_matrix()
  set.seed(3)
  c_h <- stats::runif(400, 0, 1.5)
  c_e <- stats::runif(400, 0, 1.5)
  # optical density = concentrations %*% t(stain vectors in columns)
  od <- cbind(c_h, c_e) %*% t(stains[, 1:2])
  img <- new_sg_image(array(exp(-od), dim = c(20, 20, 3)),
                      channels = c("R", "G", "B"))

  rf <- sg_stain_deconvolve(img, method = "ruifrok")
  expect_equal(as.vector(rf$hematoxylin$pixels), c_h, tolerance = 1e-8)
  expect_equal(as.vector(rf$eosin$pixels), c_e, tolerance = 1e-8)
  expect_lt(max(rf$residual$pixels), 1e-8)

  # a user matrix is read column-wise, too
  swapped <- sg_stain_deconvolve(img, stains = stains[, c(2, 1, 3)])
  expect_equal(as.vector(swapped$hematoxylin$pixels), c_e, tolerance = 1e-8)
  expect_equal(as.vector(swapped$eosin$pixels), c_h, tolerance = 1e-8)

  mk <- suppressMessages(sg_stain_deconvolve(img, method = "macenko"))
  expect_gt(stats::cor(as.vector(mk$hematoxylin$pixels), c_h), 0.99)
  expect_gt(stats::cor(as.vector(mk$eosin$pixels), c_e), 0.99)
})

test_that("the Ruifrok defaults are haematoxylin and eosin, not DAB", {
  stains <- segmantR:::.ruifrok_stain_matrix()
  expect_equal(unname(colSums(stains^2)), c(1, 1, 1), tolerance = 1e-6)
  # eosin absorbs mainly green; DAB (0.27, 0.57, 0.78) absorbs mainly blue
  expect_equal(which.max(stains[, 2]), 2L)
  expect_lt(stains[1, 2], 0.1)
  expect_equal(sum(stains[, 1] * stains[, 3]), 0, tolerance = 1e-6)
  expect_equal(sum(stains[, 2] * stains[, 3]), 0, tolerance = 1e-6)
})

test_that("upsampling interpolates within the input range", {
  img <- new_sg_image(matrix(c(0, 1, 1, 1), 2, 2, byrow = TRUE),
                      resolution = list(x_um = 1, y_um = 1))
  up <- suppressMessages(sg_preprocess(img, target_resolution = 0.5))
  expect_equal(dim(up$pixels), c(4L, 4L))
  expect_gte(min(up$pixels), 0)
  expect_lte(max(up$pixels), 1)
  expect_equal(up$pixels[1, 1], 0)
  m <- matrix(seq_len(16) / 16, 4, 4)
  up2 <- segmantR:::.resample_2d(m, 2)
  expect_equal(range(up2), range(m))
})
