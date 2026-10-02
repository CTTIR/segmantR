# Create a new sg_mask object

Constructor for the `sg_mask` S3 class, which stores an integer label
matrix where 0 represents background and positive integers represent
individual cell IDs.

## Usage

``` r
new_sg_mask(
  labels,
  image_id = NULL,
  model_info = NULL,
  mask_type = c("instance", "labelled", "binary"),
  legend = NULL,
  plane = NULL,
  origin = NULL,
  status = c("draft", "staged", "reviewed"),
  provenance = list(),
  id = NULL
)
```

## Arguments

- labels:

  Integer matrix of cell labels. 0 = background, positive values = cell
  IDs (gaps are allowed). Values must be finite whole numbers from 0 to
  2147483647; larger uint32 IDs are unsupported and rejected before
  integer conversion.

- image_id:

  Optional character string identifying the source image.

- model_info:

  Optional named list of model metadata.

- mask_type:

  One of `"instance"`, `"labelled"` or `"binary"`.

- legend:

  Optional data frame with one row per positive label and columns
  `label`, `object_id`, `class`, `name`. Missing legends are generated
  deterministically when needed (see
  [`sg_mask_legend()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_legend.md)).

- plane:

  Optional plane list (see
  [`new_sg_image()`](https://cttir.github.io/segmantR/dev/reference/new_sg_image.md)).

- origin:

  Optional origin list (see
  [`new_sg_image()`](https://cttir.github.io/segmantR/dev/reference/new_sg_image.md)).

- status:

  Review status: `"draft"` (default), `"staged"` or `"reviewed"`. See
  [`sg_review_mask()`](https://cttir.github.io/segmantR/dev/reference/sg_mask_review.md).

- provenance:

  Named list of provenance records.

- id:

  Optional mask identifier.

## Value

An object of class `sg_mask`.

## Details

Masks follow the segmantR mask contract: integer values, `0` is the
background, positive integers are object instances
(`mask_type = "instance"`, the default and historic meaning), class
codes (`"labelled"`) or foreground (`"binary"`, values 0/1 only). All
arguments after `model_info` are optional interchange fields.

## Examples

``` r
labels <- matrix(c(0L, 0L, 1L, 1L, 0L, 2L, 2L, 0L, 0L), nrow = 3)
mask <- new_sg_mask(labels)
print(mask)
#> <sg_mask>: 3 x 3, 2 cells
```
