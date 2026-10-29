# Stage, review or replace masks

`sg_stage_mask()` marks a mask as a staged candidate (for example an
imported prediction). `sg_review_mask()` records that a human reviewed
the current content. `sg_replace_mask()` replaces a mask by a candidate
while protecting reviewed data: replacing a reviewed mask requires both
`expected_revision` equal to its current revision and
`overwrite = TRUE`. Replacing with identical content is a no-op that
keeps the current status.

## Usage

``` r
sg_stage_mask(mask, source = NULL, parent = NULL)

sg_review_mask(mask, reviewer = NULL, note = NULL, expected_revision = NULL)

sg_replace_mask(
  current,
  replacement,
  expected_revision = NULL,
  overwrite = FALSE
)
```

## Arguments

- mask, current:

  An `sg_mask` object.

- source:

  Optional short description of where the candidate came from (e.g.
  `"stardist.2d.v1 prediction"`).

- parent:

  Optional `sg_mask` or revision string the candidate derives from.

- reviewer:

  Optional reviewer name or identifier.

- note:

  Optional free-text note stored in the review history (never
  evaluated).

- expected_revision:

  Revision the caller believes is current. Required to review a staged
  mask or to replace a reviewed one.

- replacement:

  The candidate `sg_mask`.

- overwrite:

  Logical; explicit decision to replace a reviewed mask.

## Value

The updated `sg_mask`.

## Examples

``` r
m <- new_sg_mask(matrix(c(0L, 1L, 1L, 0L), 2))
staged <- sg_stage_mask(m, source = "example")
rev <- sg_mask_revision(staged)
reviewed <- sg_review_mask(staged, reviewer = "me", expected_revision = rev)
sg_mask_status(reviewed)$status
#> [1] "reviewed"

candidate <- new_sg_mask(matrix(c(1L, 1L, 1L, 0L), 2))
try(sg_replace_mask(reviewed, candidate))
#> Error in sg_replace_mask(reviewed, candidate) : 
#>   Refusing to replace a reviewed mask.
#> ℹ Pass `expected_revision` =
#>   "sha256:aae04e92b620bf9e445573b0730a9f46997771628a7eac24eb723f0f32b6a2c9" and
#>   `overwrite = TRUE` to replace it.
replaced <- sg_replace_mask(reviewed, candidate,
                            expected_revision = rev, overwrite = TRUE)
sg_mask_status(replaced)$status
#> [1] "staged"
```
