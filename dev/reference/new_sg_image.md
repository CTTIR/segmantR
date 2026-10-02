# Create a new sg_image object

Constructor for the `sg_image` S3 class, which represents a
multi-channel image with associated metadata.

## Usage

``` r
new_sg_image(
  pixels,
  channels = NULL,
  resolution = NULL,
  metadata = list(),
  id = NULL,
  plane = NULL,
  origin = NULL,
  bands = NULL,
  value_semantics = "unknown",
  source_digest = NULL,
  transform_digest = NULL,
  provenance = list()
)
```

## Arguments

- pixels:

  Numeric array of dimensions H x W (grayscale) or H x W x C
  (multi-channel).

- channels:

  Character vector of channel names. If `NULL`, defaults to `ch1`,
  `ch2`, etc.

- resolution:

  Named list with `x_um` and `y_um`: microns per current array pixel.
  Divide these by `origin$downsample` for the full-resolution reference
  pixel sizes.

- metadata:

  Named list of additional image metadata.

- id:

  Optional stable image identifier (string). Absolute file paths must
  not be used as identity.

- plane:

  Optional list with zero-based `level`, `series`, `c`, `z` and `t`.
  `c = NA` means that the array holds all channels.

- origin:

  Optional list with `x`, `y` (position of the array's top-left corner
  in full-resolution pixel coordinates) and `downsample`
  (full-resolution pixels per array pixel).

- bands:

  Optional data frame describing channels/bands with columns `name`,
  `wavelength_nm`, `fwhm_nm` (one row per channel).

- value_semantics:

  What pixel values represent: one of `"unknown"`, `"intensity"`,
  `"raw"`, `"reflectance"`, `"radiance"`, `"absorbance"`,
  `"probability"`.

- source_digest:

  Optional `"sha256:<hex>"` digest of the source file or pixel content.

- transform_digest:

  Optional digest of transformations applied to the source.

- provenance:

  Named list of provenance records.

## Value

An object of class `sg_image`.

## Details

The pixel array order is always `[y, x, channel]`: the first array row
is the top image row. All arguments after `metadata` are optional
interchange fields added in segmantR 0.1.0.9000; objects created by
older code simply lack them and are treated with the documented
defaults.

## Examples

``` r
pixels <- matrix(runif(100), nrow = 10, ncol = 10)
img <- new_sg_image(pixels)
print(img)
#> <sg_image>: 10 x 10 (1 channel)

# With interchange metadata
img2 <- new_sg_image(pixels, channels = "DAPI",
                     resolution = list(x_um = 0.5, y_um = 0.5),
                     id = "slide-001", value_semantics = "intensity")
```
