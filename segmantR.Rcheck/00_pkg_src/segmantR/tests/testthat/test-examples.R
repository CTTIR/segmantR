test_that("example image and mask generators produce matching synthetic data", {
  for (type in c("he_breast", "fluorescence_nuclei", "multiplex_4ch")) {
    img <- sg_example_image(type)
    msk <- sg_example_mask(type)
    expect_s3_class(img, "sg_image")
    expect_s3_class(msk, "sg_mask")
    expect_equal(dim(img)[1:2], dim(msk))
    expect_gt(msk$n_cells, 0L)
  }
})
