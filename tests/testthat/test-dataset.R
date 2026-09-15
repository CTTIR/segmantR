instance_pair <- function(group) {
  l <- matrix(0L, 48, 48)
  l[4:10, 4:10] <- 1L
  l[20:30, 20:28] <- 2L
  l[36:44, 5:12] <- 3L
  l[26:38, 14] <- 4L        # U shape closed below row 32: two parts in the
  l[26:38, 18] <- 4L        # first 32 x 32 tile
  l[38, 14:18] <- 4L
  px <- matrix(0.1, 48, 48)
  px[l > 0L] <- 0.9
  list(image = new_sg_image(px, channels = "DAPI",
                            resolution = list(x_um = 0.5, y_um = 0.5),
                            value_semantics = "intensity"),
       mask = new_sg_mask(l, image_id = paste0("img-", group)),
       subject_id = group, slide_id = paste0("slide-", group))
}

test_that("grouped splits never leak and are seed deterministic", {
  pairs <- lapply(c("A", "A", "B", "C", "D", "E", "F"), instance_pair)
  m1 <- sg_dataset_manifest(pairs, tile_size = 24L, seed = 3L, min_objects = 0L)
  m2 <- sg_dataset_manifest(pairs, tile_size = 24L, seed = 3L, min_objects = 0L)
  expect_identical(m1$dataset_digest, m2$dataset_digest)
  src_split <- vapply(m1$sources, function(s) s$split, "")
  expect_identical(src_split[1], src_split[2])
  groups <- m1$split$groups
  all_groups <- unname(unlist(groups))
  expect_equal(sort(all_groups), c("A", "B", "C", "D", "E", "F"))
  expect_false(anyDuplicated(all_groups) > 0)
  for (t in m1$tiles) {
    expect_equal(t$split, m1$sources[[t$source_index]]$split)
  }
  expect_true(all(lengths(groups) >= 1L))
  withr::local_seed(10)
  expected_next <- withr::with_seed(10, stats::runif(1))
  sg_dataset_manifest(pairs, tile_size = 24L, seed = 99L, min_objects = 0L)
  expect_equal(stats::runif(1), expected_next)
  expect_true(sg_validate_training_manifest(m1)$ok)
})

test_that("tiles record bounds, objects and exclusion reasons", {
  pr <- instance_pair("A")
  man <- sg_dataset_manifest(list(pr), tile_size = 32L, overlap = 8L,
                             split = c(train = 1, validation = 0, test = 0),
                             partial_tiles = "exclude")
  reasons <- vapply(man$tiles, function(t) t$exclusion_reason %||% "", "")
  expect_true("partial_tile" %in% reasons)
  full <- Filter(function(t) !isTRUE(t$excluded), man$tiles)
  expect_true(all(vapply(full, function(t) t$width == 32L, logical(1))))
  first <- man$tiles[[1]]
  expect_equal(c(first$x, first$y), c(0, 0))
  expect_equal(first$n_objects, 3L)
  expect_equal(first$n_split_parts, 1L)
  ids <- vapply(first$objects, function(o) o$object_id, "")
  expect_equal(ids, sg_mask_legend(pr$mask)$object_id[c(1, 2, 4)])
  mem <- sg_prepare_training_data(list(pr), NULL, tile_size = 32L,
                                  overlap = 8L,
                                  split = c(train = 1, validation = 0,
                                            test = 0))
  t1 <- mem$tiles[[first$tile_id]]$labels
  expect_equal(max(t1), 4L)
  expect_true(segmantR:::.sg_check_labels(t1, "instance")$ok)
  keep <- sg_dataset_manifest(list(pr), tile_size = 32L, overlap = 8L,
                              split = c(train = 1, validation = 0, test = 0),
                              partial_tiles = "keep", min_objects = 2L)
  expect_true("too_few_objects" %in% names(keep$exclusions) ||
                "empty" %in% names(keep$exclusions))
  rv <- sg_dataset_manifest(list(pr), tile_size = 48L,
                            split = c(train = 1, validation = 0, test = 0),
                            require_reviewed = TRUE)
  expect_equal(rv$tiles[[1]]$exclusion_reason, "not_reviewed")
})

test_that("instance training data must be real instance masks", {
  pr <- instance_pair("A")
  binary <- pr
  binary$mask <- new_sg_mask(ifelse(pr$mask$labels > 0L, 1L, 0L))
  err <- expect_error(sg_dataset_manifest(list(binary), tile_size = 24L,
                                          split = c(train = 1, validation = 0,
                                                    test = 0)),
                      class = "sg_validation_error")
  expect_equal(err$code, "NOT_INSTANCE_MASK")
  expect_match(conditionMessage(err), "foreground/background")
  lab <- pr
  lab$mask$labels <- lab$mask$labels * 1.5
  expect_error(sg_dataset_manifest(list(lab), tile_size = 24L,
                                   split = c(train = 1, validation = 0,
                                             test = 0)))
  no_group <- pr
  no_group$subject_id <- NULL
  expect_error(sg_dataset_manifest(list(no_group), tile_size = 24L),
               "subject_id")
  other <- instance_pair("B")
  other$image$value_semantics <- "raw"
  expect_error(sg_dataset_manifest(list(pr, other), tile_size = 24L,
                                   split = c(train = 0.5, validation = 0.5,
                                             test = 0)),
               "value semantics")
  expect_error(sg_dataset_manifest(list(pr), tile_size = 24L),
               class = "sg_validation_error")
})

test_that("prepared datasets are integrity checked tile by tile", {
  pairs <- list(instance_pair("A"), instance_pair("B"))
  dest <- file.path(withr::local_tempdir(), "ds")
  ts <- sg_prepare_training_data(pairs, dest, tile_size = 24L,
                                 split = c(train = 0.5, validation = 0.5,
                                           test = 0), min_objects = 1L)
  expect_true(file.exists(file.path(dest, "dataset_manifest.json")))
  v <- sg_validate_training_manifest(dest, mask_type = "instance")
  expect_true(v$ok)
  expect_true("tile_masks" %in% v$checks$check)
  inc <- Filter(function(t) !isTRUE(t$excluded), ts$manifest$tiles)
  t1 <- inc[[1]]
  tif <- segmantR:::.sg_read_tiff(file.path(dest, t1$mask_path))
  labs <- sort(unique(as.vector(tif$data[tif$data > 0])))
  expect_equal(labs, seq_along(labs))
  expect_equal(length(t1$objects), length(labs))
  f <- file.path(dest, t1$mask_path)
  segmantR:::.sg_write_tiff(matrix(1L, t1$height, t1$width), f, dtype = "uint8")
  expect_error(sg_validate_training_manifest(dest), class = "sg_integrity_error")
  mem <- sg_prepare_training_data(pairs, NULL, tile_size = 24L,
                                  split = c(train = 0.5, validation = 0.5,
                                            test = 0))
  expect_equal(length(mem$tiles), length(inc))
})

test_that("leakage and tampering in manifests are detected", {
  pairs <- list(instance_pair("A"), instance_pair("B"))
  man <- sg_dataset_manifest(pairs, tile_size = 24L, min_objects = 0L,
                             split = c(train = 0.5, validation = 0.5, test = 0))
  leak <- unclass(man)
  leak$tiles[[1]]$split <- if (leak$tiles[[1]]$split == "train") "validation"
  else "train"
  err <- expect_error(sg_validate_training_manifest(leak),
                      class = "sg_validation_error")
  expect_equal(err$code, "SPLIT_LEAKAGE")
  edited <- unclass(man)
  edited$tile_size <- 99L
  expect_error(sg_validate_training_manifest(edited),
               class = "sg_integrity_error")
  expect_equal(sg_validate_training_manifest(man, mask_type = "binary",
                                             error = FALSE)$error$code,
               "NOT_INSTANCE_MASK")
  expect_error(sg_dataset_manifest(list(pairs[[1]]), tile_size = 24L,
                                   split = c(train = 0.5, validation = 0.5,
                                             test = 0)),
               class = "sg_validation_error")
})
