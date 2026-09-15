# Helpers for the opt-in QuPath lane (test-qupath-live.R) and the evidence
# generator in data-raw/qupath-evidence/. Nothing here runs unless a test
# explicitly calls it; the package itself never starts QuPath.

qupath_lane_enabled <- function() {
  identical(tolower(Sys.getenv("SEGMANTR_QUPATH_EVIDENCE")), "true")
}

qupath_binary <- function() {
  cand <- c(Sys.getenv("SEGMANTR_QUPATH"), Sys.which("qupath"),
            Sys.which("QuPath"), "/opt/QuPath/bin/QuPath")
  cand <- cand[nzchar(cand) & file.exists(cand)]
  if (length(cand)) cand[[1]] else NA_character_
}

qupath_stardist_model <- function() {
  cand <- c(Sys.getenv("SEGMANTR_STARDIST_PB"),
            file.path(path.expand("~"), "QuPath", "v0.7", "models", "stardist",
                      "dsb2018_heavy_augment.pb"))
  cand <- cand[nzchar(cand) & file.exists(cand)]
  if (length(cand)) cand[[1]] else NA_character_
}

qupath_run <- function(args, wd, timeout = 600) {
  res <- processx::run(qupath_binary(), args, wd = wd, error_on_status = FALSE,
                       timeout = timeout)
  list(status = res$status, stdout = res$stdout, stderr = res$stderr,
       args = args)
}

# Synthetic calibrated nuclei image with a known instance mask.
make_nuclei_fixture <- function(dir, nr = 96L, nc = 128L, n = 14L,
                                seed = 2026L) {
  withr::local_seed(seed)
  img <- matrix(200, nr, nc)
  lab <- matrix(0L, nr, nc)
  yy <- row(img)
  xx <- col(img)
  k <- 0L
  for (i in seq_len(4L * n)) {
    if (k >= n) break
    cr <- sample(10:(nr - 10L), 1L)
    cc <- sample(10:(nc - 10L), 1L)
    r <- sample(5:7, 1L)
    inside <- (yy - cr)^2 + (xx - cc)^2 <= r^2
    grown <- (yy - cr)^2 + (xx - cc)^2 <= (r + 2)^2
    if (any(lab[grown] > 0L)) next
    k <- k + 1L
    lab[inside] <- k
    img[inside] <- 1500 + 1000 * stats::runif(1L)
  }
  img <- img + matrix(stats::rnorm(nr * nc, 0, 30), nr, nc)
  img <- matrix(as.integer(pmax(0, round(img))), nr, nc)
  desc <- segmantR:::.sg_ome_xml(c(nr, nc), 1L, "uint16",
                                 pixel_size = list(x = 0.5, y = 0.5),
                                 channels = "DAPI", name = "nuclei")
  path <- file.path(dir, "nuclei.ome.tif")
  segmantR:::.sg_write_tiff(img, path, dtype = "uint16", description = desc)
  image <- new_sg_image(matrix(as.numeric(img), nr, nc), channels = "DAPI",
                        resolution = list(x_um = 0.5, y_um = 0.5),
                        id = "nuclei", value_semantics = "raw")
  mask <- sg_mask_legend(new_sg_mask(lab, image_id = "nuclei"),
                         materialise = TRUE)
  list(path = path, image = image, mask = mask)
}

qupath_create_project <- function(project_dir, image_path) {
  script <- testthat::test_path("qupath", "create_project.groovy")
  if (!file.exists(script)) {
    script <- file.path("tests", "testthat", "qupath", "create_project.groovy")
  }
  qupath_run(c("script", paste0("--args=", project_dir),
               paste0("--args=", image_path), normalizePath(script)),
             wd = dirname(project_dir))
}
