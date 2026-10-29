## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* local: Ubuntu 26.04, R 4.6.1 (`R CMD check --as-cran`, also with
  `_R_CHECK_DEPENDS_ONLY_=true`)
* GitHub Actions: ubuntu-latest (R devel, release, oldrel-1),
  macos-latest (R release), windows-latest (R release)

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
