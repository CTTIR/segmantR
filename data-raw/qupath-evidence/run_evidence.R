# QuPath / StarDist evidence run and fixture generator (not shipped).
#
#   SEGMANTR_QUPATH=/path/to/QuPath Rscript data-raw/qupath-evidence/run_evidence.R
#
# Steps (all headless through `QuPath script`; segmantR itself never starts
# QuPath):
#   1. synthetic calibrated nuclei image + known instance mask
#   2. fresh project A: StarDist program (sg_export_qupath) with --save,
#      then reopen and export (segmantR_export.groovy)
#   3. fresh project B: interactive code path of the StarDist template
#      (run.json in <project>/segmantR/, no --args)
#   4. fresh project C: segmantR mask -> import program with --save, reopen
#      and export; a second import must be refused (non-zero exit code)
#   5. compare everything in R and write evidence JSON + test fixtures
#
# Outputs: planning/evidence/qupath-stardist-evidence.json and
# tests/testthat/fixtures/qupath-0.7.0/.

pkgload::load_all(".", quiet = TRUE)
source(file.path("tests", "testthat", "helper-qupath.R"))
stopifnot(!is.na(qupath_binary()), !is.na(qupath_stardist_model()))

ws <- tempfile("segmantR-qupath-evidence-")
dir.create(ws)
redact <- function(x) gsub(ws, "<workspace>", x, fixed = TRUE)
steps <- list()
record <- function(name, res) {
  steps[[name]] <<- list(args = redact(res$args), exit_status = res$status,
                         segmantR_log = redact(grep("^segmantR", strsplit(
                           paste(res$stdout, res$stderr), "\n")[[1]],
                           value = TRUE)))
  cat(sprintf("%-28s exit %s\n", name, res$status))
  invisible(res)
}
fx <- make_nuclei_fixture(ws)
qp <- .sg_detect_qupath()
model <- qupath_stardist_model()

# ---- 2. StarDist headless ----------------------------------------------------
projA <- file.path(ws, "projectA")
record("create_project_A", qupath_create_project(projA, fx$path))
progA <- sg_export_qupath(
  "stardist.2d.v1", file.path(ws, "program_stardist"), image = fx$image,
  image_name = basename(fx$path), model = model, normalize_low = 1,
  normalize_high = 99, normalize_scope = "tile", pixel_size_um = 0.5,
  include_probability = TRUE, classification = "Nucleus",
  save_policy = "project"
)
proj_arg <- paste0("--project=", file.path(projA, "project.qpproj"))
img_arg <- paste0("--image=", basename(fx$path))
record("stardist_headless_save", qupath_run(
  c("script", proj_arg, img_arg, "--args=run.json", "--save",
    "segmantR_stardist.groovy"), wd = progA$path))
record("stardist_reopen_export", qupath_run(
  c("script", proj_arg, img_arg, "--args=run_export.json",
    "segmantR_export.groovy"), wd = progA$path))

# ---- 3. interactive code path (no --args) -------------------------------------
projB <- file.path(ws, "projectB")
record("create_project_B", qupath_create_project(projB, fx$path))
dir.create(file.path(projB, "segmantR"))
file.copy(list.files(progA$path, full.names = TRUE, all.files = FALSE),
          file.path(projB, "segmantR"), recursive = TRUE)
unlink(file.path(projB, "segmantR", c("out", "qupath_export")), recursive = TRUE)
record("stardist_interactive_path", qupath_run(
  c("script", paste0("--project=", file.path(projB, "project.qpproj")),
    img_arg, file.path("segmantR", "segmantR_stardist.groovy")), wd = projB))

# ---- 4. segmantR mask -> QuPath import -> export ------------------------------
projC <- file.path(ws, "projectC")
record("create_project_C", qupath_create_project(projC, fx$path))
progC <- sg_export_qupath(fx$mask, file.path(ws, "program_import"),
                          image = fx$image, image_name = basename(fx$path),
                          save_policy = "project")
projC_arg <- paste0("--project=", file.path(projC, "project.qpproj"))
record("import_headless_save", qupath_run(
  c("script", projC_arg, img_arg, "--args=run.json", "--save",
    "segmantR_import.groovy"), wd = progC$path))
record("import_reopen_export", qupath_run(
  c("script", projC_arg, img_arg, "--args=run_export.json",
    "segmantR_export.groovy"), wd = progC$path))
record("import_repeat_refused", qupath_run(
  c("script", projC_arg, img_arg, "--args=run.json", "--save",
    "segmantR_import.groovy"), wd = progC$path))

# ---- 5. comparisons -----------------------------------------------------------
sd_run <- sg_import_qupath(file.path(progA$path, "out"), image = fx$image)
sd_re <- sg_import_qupath(file.path(progA$path, "qupath_export"),
                          image = fx$image)
sd_int <- sg_import_qupath(file.path(projB, "segmantR", "out"),
                           image = fx$image)
imp <- sg_import_qupath(file.path(progC$path, "qupath_export"),
                        image = fx$image)
orig <- sg_mask_legend(fx$mask)
lc <- sg_mask_legend(imp$mask)
remap <- lc$label[match(orig$object_id, lc$object_id)]
back <- matrix(0L, nrow(imp$mask$labels), ncol(imp$mask$labels))
pos <- imp$mask$labels > 0L
back[pos] <- orig$label[match(imp$mask$labels[pos], remap)]
meas_key <- function(m) m[order(m$object_id, m$name), c("object_id", "name",
                                                        "value")]
ev <- suppressMessages(sg_evaluate_segmentation(sd_run$mask, fx$mask))
comparisons <- list(
  stardist_objects = sd_run$mask$n_cells,
  truth_objects = fx$mask$n_cells,
  stardist_metrics = stats::setNames(as.list(ev$value), ev$metric),
  stardist_reopened_labels_identical = identical(sd_run$mask$labels,
                                                 sd_re$mask$labels),
  stardist_reopened_ids_identical = identical(
    sg_mask_legend(sd_run$mask)$object_id, sg_mask_legend(sd_re$mask)$object_id),
  stardist_reopened_measurements_identical = isTRUE(all.equal(
    meas_key(sd_run$measurements), meas_key(sd_re$measurements),
    check.attributes = FALSE)),
  stardist_interactive_path_labels_identical = identical(
    sd_run$mask$labels > 0L, sd_int$mask$labels > 0L),
  stardist_geojson_vs_tiff = sd_run$qupath$agreement,
  import_all_ids_preserved = !anyNA(remap),
  import_pixels_identical_per_object_id = identical(back, fx$mask$labels),
  import_geojson_vs_tiff = imp$qupath$agreement,
  cross_language_revision_checked = all(c(
    "mask_revision" %in% sd_run$checks$check[sd_run$checks$status == "ok"],
    "mask_revision" %in% imp$checks$check[imp$checks$status == "ok"]))
)
print(comparisons)

evidence <- list(
  generated = .sg_utc_now(),
  segmantR_version = as.character(utils::packageVersion("segmantR")),
  source_revision = .sg_source_revision(),
  r_version = R.version.string,
  qupath_version = qp$version,
  stardist_extension_version = qp$stardist_version,
  model = list(file = basename(model),
               sha256 = .sg_sha256_file(model),
               inventory_digest = sg_stardist_manifest(model)$digest),
  run_ids = list(stardist = progA$run$run_id, import = progC$run$run_id),
  steps = steps,
  comparisons = comparisons,
  not_executed = "GUI Script Editor session (the interactive code path was exercised through QuPath script without --args)"
)
dir.create("planning/evidence", recursive = TRUE, showWarnings = FALSE)
.sg_write_json(evidence, "planning/evidence/qupath-stardist-evidence.json")

fixture <- file.path("tests", "testthat", "fixtures", "qupath-0.7.0")
unlink(fixture, recursive = TRUE)
dir.create(fixture, recursive = TRUE)
copy_dir <- function(from, to) {
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  for (f in .sg_list_rel_files(from)) {
    dir.create(dirname(file.path(to, f)), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(from, f), file.path(to, f))
  }
}
file.copy(fx$path, fixture)
copy_dir(file.path(progA$path, "out"), file.path(fixture, "stardist_out"))
copy_dir(file.path(progC$path, "bundle"), file.path(fixture, "segmantR_bundle"))
copy_dir(file.path(progC$path, "qupath_export"),
         file.path(fixture, "import_roundtrip_export"))
file.copy(file.path(progA$path, "run.json"), file.path(fixture, "run_stardist.json"))
file.copy(file.path(progC$path, "run.json"), file.path(fixture, "run_import.json"))
file.copy("planning/evidence/qupath-stardist-evidence.json",
          file.path(fixture, "evidence.json"))
cat("fixtures written to", fixture, "\n")
