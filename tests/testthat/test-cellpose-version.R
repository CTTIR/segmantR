test_that("legacy Cellpose versions are checked before model loading", {
  for (version in c("3.0", "3.0.0", "3.1.1.3", "3.1.1.3.post1",
                    "3.1.1.3+cpu", "3.1.1.3.post2+cpu.1")) {
    expect_true(segmantR:::.sg_validate_cellpose_version(version))
  }
  for (version in list("2.3.2", "4.0.0", "4.2.1.1", "30.0", "3.1rc1",
                       "3.1.dev1", "3.1.1.3.post1.dev2", "unknown", NA_character_, character(), 3)) {
    expect_error(segmantR:::.sg_validate_cellpose_version(version),
                 "Cellpose 3.x is required")
  }
})

test_that("the backend check rejects an existing incompatible distribution", {
  local_mocked_bindings(
    .sg_has_pkg = function(pkg) TRUE,
    .sg_python_selected = function() TRUE,
    .sg_py_module_available = function(module) TRUE,
    .sg_cellpose_version = function() "4.2.1.1"
  )
  expect_error(segmantR:::.check_cellpose(), "Cellpose 3.x is required")
})
