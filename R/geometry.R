# Exact pixel-edge polygon tracing of label masks and pixel-centre
# rasterisation of polygon features. Coordinates follow the shared image
# convention: origin top-left, x to the right, y down, unit = level-0 px.
# Array cell [r, c] covers x in [c-1, c) and y in [r-1, r) before applying
# the image origin and downsample.

#' Trace the boundary rings of one binary region
#'
#' Boundary edges are oriented with the region on the left (mathematical
#' sense), so exterior rings have positive and holes negative signed area.
#' At pinch vertices the left-most turn is taken, which keeps diagonally
#' touching pixels in separate rings.
#' @return List of numeric matrices with columns x, y (closed rings).
#' @noRd
.sg_trace_rings <- function(binary) {
  nr <- nrow(binary)
  nc <- ncol(binary)
  b <- matrix(as.logical(binary), nr, nc)
  pad <- matrix(FALSE, nr + 2L, nc + 2L)
  pad[2:(nr + 1L), 2:(nc + 1L)] <- b
  inner <- pad[2:(nr + 1L), 2:(nc + 1L)]
  up <- pad[1:nr, 2:(nc + 1L)]
  down <- pad[3:(nr + 2L), 2:(nc + 1L)]
  left <- pad[2:(nr + 1L), 1:nc]
  right <- pad[2:(nr + 1L), 3:(nc + 2L)]
  rc <- function(sel) {
    w <- which(inner & sel)
    list(r = (w - 1L) %% nr + 1L, c = (w - 1L) %/% nr + 1L)
  }
  t_ <- rc(!up)
  r_ <- rc(!right)
  d_ <- rc(!down)
  l_ <- rc(!left)
  x0 <- c(t_$c - 1L, r_$c, d_$c, l_$c - 1L)
  y0 <- c(t_$r - 1L, r_$r - 1L, d_$r, l_$r)
  x1 <- c(t_$c, r_$c, d_$c - 1L, l_$c - 1L)
  y1 <- c(t_$r - 1L, r_$r, d_$r, l_$r - 1L)
  n_e <- length(x0)
  if (n_e == 0L) return(list())
  key <- function(x, y) y * (nc + 1L) + x
  start_key <- key(x0, y0)
  ord <- order(start_key)
  by_start <- split(ord, start_key[ord])
  used <- logical(n_e)
  dx <- x1 - x0
  dy <- y1 - y0
  rings <- list()
  for (e0 in seq_len(n_e)) {
    if (used[e0]) next
    xs <- integer(0)
    ys <- integer(0)
    e <- e0
    repeat {
      used[e] <- TRUE
      xs <- c(xs, x0[e])
      ys <- c(ys, y0[e])
      cand <- by_start[[as.character(key(x1[e], y1[e]))]]
      cand <- cand[!used[cand] | cand == e0]
      if (length(cand) == 0L) break
      if (length(cand) > 1L) {
        # cross product > 0 means a left turn (mathematical orientation)
        cross <- dx[e] * dy[cand] - dy[e] * dx[cand]
        dot <- dx[e] * dx[cand] + dy[e] * dy[cand]
        rank <- ifelse(cross > 0, 0L, ifelse(dot > 0, 1L, 2L))
        cand <- cand[order(rank)]
      }
      if (cand[1] == e0) break
      e <- cand[1]
    }
    m <- cbind(x = as.numeric(xs), y = as.numeric(ys))
    m <- .sg_drop_collinear(m)
    rings[[length(rings) + 1L]] <- rbind(m, m[1L, , drop = FALSE])
  }
  rings
}

#' Remove intermediate vertices on straight runs of an open ring
#' @noRd
.sg_drop_collinear <- function(m) {
  n <- nrow(m)
  if (n < 4L) return(m)
  prev <- c(n, seq_len(n - 1L))
  nxt <- c(seq(2L, n), 1L)
  cross <- (m[, "x"] - m[prev, "x"]) * (m[nxt, "y"] - m[, "y"]) -
    (m[, "y"] - m[prev, "y"]) * (m[nxt, "x"] - m[, "x"])
  m[cross != 0, , drop = FALSE]
}

#' Signed shoelace area of a closed ring
#' @noRd
.sg_ring_area <- function(ring) {
  x <- ring[, 1]
  y <- ring[, 2]
  n <- length(x)
  if (n < 4L) return(0)
  sum(x[-n] * y[-1] - x[-1] * y[-n]) / 2
}

#' Even-odd point-in-ring test for a set of rings
#' @noRd
.sg_point_in_rings <- function(px, py, rings) {
  inside <- FALSE
  for (ring in rings) {
    x <- ring[, 1]
    y <- ring[, 2]
    n <- length(x) - 1L
    if (n < 3L) next
    xi <- x[seq_len(n)]
    yi <- y[seq_len(n)]
    xj <- x[seq_len(n) + 1L]
    yj <- y[seq_len(n) + 1L]
    crosses <- ((yi > py) != (yj > py)) &
      (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
    if (sum(crosses) %% 2L == 1L) inside <- !inside
  }
  inside
}

#' Group rings into polygons (exterior + holes)
#' @return List of polygons; each polygon is a list of rings (first exterior).
#' @noRd
.sg_group_rings <- function(rings) {
  if (length(rings) == 0L) return(list())
  areas <- vapply(rings, .sg_ring_area, numeric(1))
  ext <- which(areas > 0)
  holes <- which(areas < 0)
  polys <- lapply(ext, function(i) list(rings[[i]]))
  for (h in holes) {
    ring <- rings[[h]]
    # A test point just inside the hole: the hole lies to the right of its
    # first edge because the object is on the left.
    ex <- ring[2, 1] - ring[1, 1]
    ey <- ring[2, 2] - ring[1, 2]
    len <- sqrt(ex^2 + ey^2)
    px <- (ring[1, 1] + ring[2, 1]) / 2 + 0.25 * ey / len
    py <- (ring[1, 2] + ring[2, 2]) / 2 - 0.25 * ex / len
    containing <- ext[vapply(ext, function(i) {
      .sg_point_in_rings(px, py, list(rings[[i]]))
    }, logical(1))]
    if (length(containing) == 0L) next
    best <- containing[which.min(areas[containing])]
    k <- match(best, ext)
    polys[[k]] <- c(polys[[k]], list(ring))
  }
  polys
}

#' Trace polygons for every label of a label matrix
#'
#' @return Named list (by label) of polygon lists in image coordinates.
#' @noRd
.sg_label_polygons <- function(labels, origin = list(x = 0, y = 0,
                                                     downsample = 1),
                               ids = NULL) {
  ids <- ids %||% sort(unique(labels[labels > 0L]))
  ds <- origin$downsample %||% 1
  ox <- origin$x %||% 0
  oy <- origin$y %||% 0
  out <- lapply(ids, function(id) {
    sel <- which(labels == id, arr.ind = TRUE)
    r0 <- min(sel[, 1])
    r1 <- max(sel[, 1])
    c0 <- min(sel[, 2])
    c1 <- max(sel[, 2])
    sub <- labels[r0:r1, c0:c1, drop = FALSE] == id
    polys <- .sg_group_rings(.sg_trace_rings(sub))
    lapply(polys, function(p) lapply(p, function(ring) {
      cbind(x = ox + (ring[, 1] + c0 - 1) * ds,
            y = oy + (ring[, 2] + r0 - 1) * ds)
    }))
  })
  stats::setNames(out, as.character(ids))
}

#' GeoJSON geometry object for a polygon list
#' @noRd
.sg_geojson_geometry <- function(polys) {
  ring_coords <- function(ring) {
    lapply(seq_len(nrow(ring)), function(i) I(unname(ring[i, ])))
  }
  if (length(polys) == 1L) {
    list(type = "Polygon", coordinates = lapply(polys[[1]], ring_coords))
  } else {
    list(type = "MultiPolygon",
         coordinates = lapply(polys, function(p) lapply(p, ring_coords)))
  }
}

#' Extract rings from a parsed GeoJSON geometry
#' @return List with `polygons` (list of ring lists), `kind`, `exact`.
#' @noRd
.sg_geometry_rings <- function(geometry) {
  type <- geometry$type %||% ""
  to_ring <- function(coords) {
    m <- do.call(rbind, lapply(coords, function(p) as.numeric(unlist(p))[1:2]))
    colnames(m) <- c("x", "y")
    m
  }
  polys <- switch(
    type,
    Polygon = list(lapply(geometry$coordinates, to_ring)),
    MultiPolygon = lapply(geometry$coordinates, function(p) {
      lapply(p, to_ring)
    }),
    NULL
  )
  if (is.null(polys)) {
    return(list(polygons = list(), kind = type, supported = FALSE,
                exact = FALSE))
  }
  all_pts <- do.call(rbind, unlist(polys, recursive = FALSE))
  integer_grid <- all(all_pts == round(all_pts))
  axis_aligned <- all(vapply(unlist(polys, recursive = FALSE), function(r) {
    all(diff(r[, 1]) == 0 | diff(r[, 2]) == 0)
  }, logical(1)))
  list(polygons = polys, kind = type, supported = TRUE,
       exact = integer_grid && axis_aligned)
}

#' Rasterise polygons by the pixel-centre even-odd rule
#'
#' @param polygons List of ring lists in image coordinates.
#' @param shape_yx Output array shape.
#' @param origin List with x, y, downsample of the output array.
#' @return Logical matrix.
#' @noRd
.sg_rasterise_polygons <- function(polygons, shape_yx,
                                   origin = list(x = 0, y = 0,
                                                 downsample = 1)) {
  nr <- as.integer(shape_yx[1])
  nc <- as.integer(shape_yx[2])
  out <- matrix(FALSE, nr, nc)
  ds <- origin$downsample %||% 1
  ox <- origin$x %||% 0
  oy <- origin$y %||% 0
  rings <- unlist(polygons, recursive = FALSE)
  if (length(rings) == 0L) return(out)
  segs <- do.call(rbind, lapply(rings, function(r) {
    x <- (r[, 1] - ox) / ds
    y <- (r[, 2] - oy) / ds
    n <- length(x)
    if (n < 2L) return(NULL)
    cbind(x[-n], y[-n], x[-1], y[-1])
  }))
  if (is.null(segs)) return(out)
  y_lo <- max(1L, floor(min(segs[, c(2, 4)])))
  y_hi <- min(nr, ceiling(max(segs[, c(2, 4)])) + 1L)
  if (y_lo > y_hi) return(out)
  for (r in y_lo:y_hi) {
    yc <- r - 0.5
    hit <- (segs[, 2] <= yc & segs[, 4] > yc) |
      (segs[, 4] <= yc & segs[, 2] > yc)
    if (!any(hit)) next
    s <- segs[hit, , drop = FALSE]
    xi <- sort(s[, 1] + (yc - s[, 2]) * (s[, 3] - s[, 1]) / (s[, 4] - s[, 2]))
    if (length(xi) < 2L) next
    for (k in seq(1L, length(xi) - 1L, by = 2L)) {
      c_from <- max(1L, ceiling(xi[k] + 0.5))
      c_to <- min(nc, ceiling(xi[k + 1L] + 0.5) - 1L)
      if (c_from <= c_to) out[r, c_from:c_to] <- TRUE
    }
  }
  out
}
