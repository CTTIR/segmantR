## R CMD check results
0 errors | 0 warnings | 0 notes

## Test environments
* local: Windows 11, R 4.4.x
* GitHub Actions: ubuntu-latest (release), macos-latest (release), windows-latest (release)

## This is a new submission.

## Note on optional dependencies
This package optionally uses 'reticulate' to interface with Python-based
segmentation models (Cellpose, StarDist). All reticulate usage is conditional
and the package is fully functional without Python. Bioconductor packages
(EBImage, simpleSeg) are in Suggests and used conditionally.
