test_that("TensorFlow distribution selection respects platform availability", {
  for (platform in c("Darwin", "Linux", "Windows")) {
    expect_identical(.sg_tensorflow_package(TRUE, platform), "tensorflow")
    expect_identical(.sg_tensorflow_package(FALSE, platform),
                     if (platform == "Darwin") "tensorflow" else "tensorflow-cpu")
  }
})

test_that("StarDist setup passes the platform distribution to the installer", {
  installed <- NULL
  local_mocked_bindings(
    .sg_has_pkg = function(pkg) TRUE,
    .sg_virtualenv_create = function(envname) invisible(TRUE),
    .sg_tensorflow_package = function(gpu) {
      expect_false(gpu)
      "tensorflow"
    },
    .sg_py_install = function(packages, envname, method) {
      installed <<- packages
      invisible(TRUE)
    }
  )
  expect_true(sg_setup_python(method = "virtualenv", backends = "stardist",
                             gpu = FALSE))
  expect_identical(installed, c("stardist", "tensorboard", "tensorflow"))
})
