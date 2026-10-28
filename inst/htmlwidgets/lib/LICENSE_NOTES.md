# Bundled front-end libraries

The cell annotation canvas (`sgcanvas`) is a self-contained HTML5 canvas in
`inst/htmlwidgets/sgcanvas.js` with its own stylesheet in
`inst/htmlwidgets/lib/sgcanvas/`. It bundles no external JavaScript
libraries, so there is no third-party front-end code to attribute, and it
works fully offline (no CDN requests).

## Possible later additions

OpenSeadragon (BSD-3-Clause) for gigapixel deep zoom and Annotorious
(BSD-3-Clause) for W3C Web Annotation drawing may be vendored here later.
Their exact versions and licences would then be recorded in this file and
attributed in the README. The R interface in `R/canvas.R` and the
JavaScript message protocol are shaped so that such a swap does not change
the R side.
