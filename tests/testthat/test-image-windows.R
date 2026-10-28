# Windowed channel reading and display ranges on synthetic multi-page TIFFs.

pixel_value <- function(r, c, k) (7 * r + 3 * c + 40 * k) %% 251  # 0-based row, column, channel

write_stack <- function(h = 40, w = 50, k = 3, names = c("A", "B", "C")) {
  f <- withr::local_tempfile(fileext = ".tif", .local_envir = parent.frame())
  arr <- array(0, c(h, w, k))
  for (ch in seq_len(k)) arr[, , ch] <- outer(0:(h - 1), 0:(w - 1), function(r, c) pixel_value(r, c, ch - 1))
  ome <- paste0("<OME><Image><Pixels>", paste0("<Channel ID=\"c", seq_len(k), "\" Name=\"", names, "\"/>", collapse = ""),
                "</Pixels></Image></OME>")
  storage.mode(arr) <- "integer"
  segmantR:::.sg_write_tiff(arr, f, dtype = "uint8", description = ome)
  f
}

test_that("channels of a multi-page TIFF are listed with names", {
  skip_if_not_installed("sf")
  f <- write_stack()
  ch <- sg_image_channels(f)
  expect_identical(ch$name, c("A", "B", "C"))
  expect_identical(ch$channel, 1:3)
  expect_equal(unique(ch$width), 50)
  expect_equal(unique(ch$height), 40)
  expect_identical(segmantR:::.sg_plane_name("<X><Biomarker>CD3e</Biomarker><Name>Opal</Name></X>"), "CD3e")
  expect_identical(segmantR:::.sg_plane_name("<X><Name>DAPI</Name></X>"), "DAPI")
  expect_true(is.na(segmantR:::.sg_plane_name("")))
})

test_that("windows equal the pixels, by name or number, and are padded outside the image", {
  skip_if_not_installed("sf")
  f <- write_stack()
  w <- sg_read_window(f, "B", x0 = 5, y0 = 7, width = 6, height = 4)
  expect_identical(dim(w), c(4L, 6L))
  expect_equal(unname(w[, , drop = TRUE]),
               outer(7:10, 5:10, function(r, c) pixel_value(r, c, 1)), ignore_attr = TRUE)
  expect_equal(attr(w, "x0"), 5)
  expect_identical(attr(w, "channel"), "B")
  expect_equal(as.numeric(sg_read_window(f, 2, 5, 7, 6, 4)), as.numeric(w))
  edge <- sg_read_window(f, "C", x0 = -2, y0 = 38, width = 4, height = 4, fill = -1)
  expect_equal(edge[1:2, 3:4], outer(38:39, 0:1, function(r, c) pixel_value(r, c, 2)), ignore_attr = TRUE)
  expect_true(all(edge[3:4, ] == -1) && all(edge[, 1:2] == -1))
  out <- sg_read_window(f, "A", 100, 100, 3, 3, fill = 0)
  expect_true(all(out == 0))
  expect_error(sg_read_window(f, "Z", 0, 0, 2, 2), class = "sg_validation_error")
  expect_error(sg_read_window(f, "A", 0.5, 0, 2, 2), class = "sg_validation_error")
})

test_that("fields are centred by the rounding rule and read in batches", {
  skip_if_not_installed("sf")
  f <- write_stack()
  fld <- sg_read_field(f, c("A", "C"), centre = c(10.2, 8.1), size = 4, pixel_size = 0.5)
  # n = 8 px; x0 = round(20.4) - 4 = 16; y0 = round(16.2) - 4 = 12
  expect_s3_class(fld, "sg_field")
  expect_identical(c(fld$n, fld$x0, fld$y0), c(8, 16, 12))
  expect_equal(fld$channels$C, outer(12:19, 16:23, function(r, c) pixel_value(r, c, 2)), ignore_attr = TRUE)
  expect_equal(fld$extent, c(8, 12, 6, 10))
  same <- sg_read_field(f, "A", centre = data.frame(x = 10.2, y = 8.1), size = 4, pixel_size = 0.5)
  expect_identical(same$channels$A, fld$channels$A)
  tab <- data.frame(img = c("one", "one"), x = c(5, 20), y = c(5, 10), extra = c("B", "C"))
  many <- sg_read_fields(tab, paths = list(k_one = f), channels = "A", size = 6, source = "img", key_prefix = "k_",
                         channel_columns = "extra")
  expect_length(many, 2L)
  expect_identical(names(many[[1]]$channels), c("A", "B"))
  expect_identical(names(many[[2]]$channels), c("A", "C"))
  expect_identical(many[[2]]$row$extra, "C")
  single <- sg_read_fields(tab, paths = f, channels = "A", size = 6)
  expect_identical(single[[1]]$channels$A, many[[1]]$channels$A)
  expect_error(sg_read_fields(tab, paths = list(other = f), channels = "A", size = 6, source = "img"),
               class = "sg_validation_error")
})

test_that("display ranges follow the percentile rule", {
  x <- c(0, 1, 2, 3, 100)
  r <- sg_display_range(x)
  expect_equal(unname(r), c(stats::quantile(x, 0.01, type = 7), stats::quantile(x, 0.997, type = 7)), ignore_attr = TRUE)
  expect_equal(unname(sg_display_range(rep(5, 10))), c(5, 6))
  r2 <- sg_display_range(1:10, probs = c(NA, 0.5), lo = 2, hi_floor = 20)
  expect_equal(unname(r2), c(2, 20))
  expect_error(sg_display_range(c(NA, NaN)), class = "sg_validation_error")
  expect_error(sg_display_range(1:3, probs = c(NA, 0.9)), class = "sg_validation_error")
})

test_that("slide ranges sample whole blocks reproducibly and levels separate cell sets", {
  skip_if_not_installed("sf")
  # a bright square around every "positive" cell on a dim background
  h <- 64; w <- 64
  plane <- matrix(10L, h, w)
  pos <- data.frame(x = c(10, 30, 50), y = c(12, 40, 20))
  for (i in seq_len(nrow(pos))) plane[pos$y[i] + (-2:2) + 1, pos$x[i] + (-2:2) + 1] <- 200L
  f <- withr::local_tempfile(fileext = ".tif")
  segmantR:::.sg_write_tiff(array(plane, c(h, w, 1)), f, dtype = "uint8")
  cells <- rbind(data.frame(pos, label = "pos"), data.frame(x = c(5, 25, 45, 58), y = c(55, 58, 50, 5), label = "neg"))
  r1 <- sg_slide_display_ranges(f, 1, cells, n_cells = 10, n_tiles = 5, step = 1, seed = 3, source = "img")
  r2 <- sg_slide_display_ranges(f, 1, cells, n_cells = 10, n_tiles = 5, step = 1, seed = 3, source = "img")
  expect_identical(r1, r2)
  expect_identical(r1$source, "img")
  expect_true(r1$lo >= 10 && r1$hi <= 200)
  lv <- sg_display_levels(f, "ch1", cells, positive = list(ch1 = "pos"), negative = list(ch1 = "neg"),
                          half = 1, statistic = "mean", n = 10)
  expect_equal(lv$lo, 10)
  expect_equal(lv$hi, 200)
  expect_identical(c(lv$n_negative, lv$n_positive), c(4L, 3L))
  lv2 <- sg_display_levels(f, "ch1", cells, positive = list(ch1 = "pos"), negative = list(ch1 = "neg"),
                           half = list(ch1 = 3, .default = 1), statistic = list(.default = 0.5))
  expect_equal(lv2$hi, 200)
  expect_error(sg_display_levels(f, "ch1", cells, positive = list(ch1 = "none"), negative = list(ch1 = "neg")),
               class = "sg_validation_error")
})

test_that("the image-window code carries no study identifiers", {
  src <- system.file(package = "segmantR")
  files <- list.files(file.path(src, "R"), full.names = TRUE)
  if (!length(files) && dir.exists(test_path("../../R"))) files <- test_path("../../R/image-windows.R")
  skip_if(!length(files), "sources not available")
  txt <- paste(unlist(lapply(files[grepl("image-windows", files)], readLines, warn = FALSE)), collapse = "\n")
  # names of studies and people come from the environment, never from this file
  private <- Sys.getenv("CTTIR_PRIVATE_TERMS")
  expect_false(grepl(paste(c("PRJ-2026", if (nzchar(private)) private), collapse = "|"), txt))
})
