# Create an annotation task for human review

Samples informative image patches for manual annotation or correction.
Patches are selected on a grid or, when an initial mask is provided,
prioritised by segmentation uncertainty.

## Usage

``` r
sg_create_annotation_task(
  image,
  initial_mask = NULL,
  region = NULL,
  n_patches = 20L,
  patch_size = 256L
)
```

## Arguments

- image:

  An `sg_image` object.

- initial_mask:

  Optional `sg_mask` object. When provided, patches are scored by
  segmentation uncertainty and sampled accordingly.

- region:

  Optional numeric vector `c(row_min, row_max, col_min, col_max)` to
  restrict patch sampling to a sub-region.

- n_patches:

  Integer. Number of patches to sample. Default `20L`.

- patch_size:

  Integer. Size of each square patch in pixels. Default `256L`.

## Value

An `sg_annotation_task` S3 object (a list with elements `patches`,
`image_id`, `n_patches`, `patch_size`, and `created`).

## Examples

``` r
pixels <- matrix(runif(100 * 100), nrow = 100, ncol = 100)
img <- new_sg_image(pixels)
task <- sg_create_annotation_task(img, n_patches = 4L, patch_size = 32L)
#> ✔ Created annotation task with 4 patches.
#> ℹ Patch size: 32 x 32 px.
print(task)
#> <sg_annotation_task>
#> Patches: 4 (32 x 32 px)
#> Created: 2026-07-19 09:09:41
```
