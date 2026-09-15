"""Independent TIFF fixtures for segmantR tests (written with tifffile).

Run with a Python that has numpy and tifffile:
    python data-raw/interop-fixtures/make_tiff_fixtures.py tests/testthat/fixtures/tiff
The expected label values are defined here with numpy, independently of the
segmantR TIFF writer and reader.
"""
import json
import sys
from pathlib import Path

import numpy as np
import tifffile

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)

labels = np.zeros((6, 9), dtype=np.int64)
labels[0:2, 0:3] = 1          # top-left block, touches border
labels[3:6, 1:3] = 2          # lower-left block
labels[1:4, 5:8] = 300        # needs uint16
labels[5, 8] = 7              # single bottom-right pixel (orientation probe)

cases = {
    "labels_uint16_le.tif": dict(data=labels.astype("<u2"), kw={}),
    "labels_uint16_be.tif": dict(data=labels.astype(">u2"), kw={"byteorder": ">"}),
    "labels_uint32_le.tif": dict(data=(labels * 1000).astype("<u4"), kw={}),
    "labels_uint8_le.tif": dict(data=np.where(labels > 255, 9, labels).astype("u1"), kw={}),
    "labels_uint16_zlib.tif": dict(data=labels.astype("<u2"), kw={"compression": "zlib"}),
    "labels_float32.tif": dict(data=labels.astype("<f4"), kw={}),
}
expected = {}
for name, spec in cases.items():
    tifffile.imwrite(out / name, spec["data"], **spec["kw"])
    expected[name] = {
        "dtype": str(spec["data"].dtype.newbyteorder("=")),
        "shape_yx": list(spec["data"].shape),
        "values_row_major": spec["data"].astype(np.float64).ravel(order="C").tolist(),
    }

# Four-page (channel) float64 stack, one plane per IFD
stack = np.arange(2 * 3 * 4, dtype=np.float64).reshape(4, 2, 3) / 7.0
tifffile.imwrite(out / "stack_float64_3d.tif", stack, photometric="minisblack")
expected["stack_float64_3d.tif"] = {
    "dtype": "float64",
    "shape_cyx": list(stack.shape),
    "values_c_y_x": stack.ravel(order="C").tolist(),
}

# Chunky (interleaved) RGB uint8, samples per pixel = 3
rgb = (np.arange(4 * 5 * 3) % 251).astype(np.uint8).reshape(4, 5, 3)
tifffile.imwrite(out / "rgb_uint8_chunky.tif", rgb, photometric="rgb")
expected["rgb_uint8_chunky.tif"] = {
    "dtype": "uint8",
    "shape_yxs": list(rgb.shape),
    "values_y_x_s": rgb.astype(np.float64).ravel(order="C").tolist(),
}
expected["_generator"] = {"tifffile": tifffile.__version__, "numpy": np.__version__}
(out / "expected.json").write_text(json.dumps(expected, indent=1, sort_keys=True))
print("wrote", len(cases) + 1, "TIFF fixtures")
