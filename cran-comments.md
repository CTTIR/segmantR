## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'R. Heller <raban.heller@uni-ulm.de>'
  New submission

  This is a new submission.

## Test environments

* local: macOS 27.0.1 (aarch64-apple-darwin), R 4.6.1,
  `R CMD check --as-cran` on the built tarball, including the PDF manual
  (TinyTeX, TeX Live 2026) and the HTML manual validation (HTML Tidy 5.8.0).
  The Bioconductor package 'EBImage' (Suggests) could not be installed
  locally (it needs the FFTW system library), so that run used
  `_R_CHECK_FORCE_SUGGESTS_=false`; the GitHub Actions runs install it.
* GitHub Actions (r-lib/actions v2, `--as-cran`): ubuntu-latest (R devel,
  release, oldrel-1), macos-latest (R release), windows-latest (R release),
  plus an informational ubuntu-latest oldrel-3 row.

## Optional dependencies

The deep learning backends ('Cellpose', 'StarDist', 'Mesmer') run through
'reticulate' in a Python environment the user sets up. segmantR never
starts or installs Python by itself: the backends are used only when
Python is already running in the session, when `RETICULATE_PYTHON` or
`RETICULATE_PYTHON_ENV` names one, or when the user sets
`options(segmantR.python = TRUE)`; otherwise they are reported as
unavailable. Examples that run a backend are wrapped in `\dontrun{}`; the
examples and tests that only check for the backends run without starting
Python. A test (skipped on CRAN) checks in a fresh R process with an empty
home directory that these checks neither start Python nor write files.
Tests with a real Python runtime run only when a Python is named for them
in an environment variable. The Bioconductor package 'EBImage' and the
other Suggests are used only when installed.
