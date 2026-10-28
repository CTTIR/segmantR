## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* The NOTE also lists the version number 0.1.0.9000 as having large
  components; it is the development version and will be bumped to a
  release version before submission.

## Test environments

* local: Ubuntu 26.04, R 4.6.1 (`R CMD check --as-cran`, also with
  `_R_CHECK_DEPENDS_ONLY_=true`)
* GitHub Actions: ubuntu-latest (R devel, release, oldrel-1),
  macos-latest (R release), windows-latest (R release)

## Optional dependencies

The deep learning backends ('Cellpose', 'StarDist', 'Mesmer') run through
'reticulate' in a Python environment the user sets up. All Python use is
conditional: examples that need Python are wrapped in `\dontrun{}` and the
corresponding tests are skipped when the modules are absent. The
Bioconductor package 'EBImage' and the other Suggests are used only when
installed.
