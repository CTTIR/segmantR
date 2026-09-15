# Condition classes used by segmantR contracts

Functions of the interchange, protocol, dataset, model and QuPath
adapters signal errors of class `sg_error` with one subclass. Each
condition has a `code` field (for example `"INTEGRITY_MISMATCH"`) and a
`details` list that never contains absolute file paths.

## Details

- `sg_validation_error`:

  Invalid input, schema or parameter (`VALIDATION_FAILED`,
  `UNKNOWN_PARAMETER`, `PARAMETER_OUT_OF_RANGE`, `DTYPE_MISMATCH`,
  `DIMENSION_MISMATCH`, `INVALID_PLANE`, `LEGEND_INCOMPLETE`,
  `NOT_INSTANCE_MASK`, `SPLIT_LEAKAGE`).

- `sg_protocol_error`:

  Unknown protocol or unsupported schema major version
  (`PROTOCOL_NOT_FOUND`, `PROTOCOL_MISMATCH`, `SCHEMA_MISMATCH`).

- `sg_capability_error`:

  An optional backend or runtime is missing (`CAPABILITY_UNAVAILABLE`).

- `sg_calibration_error`:

  Pixel calibration is missing but required (`CALIBRATION_MISSING`).

- `sg_conflict_error`:

  Revision or overwrite conflicts (`REVISION_CONFLICT`,
  `REVIEWED_OVERWRITE_DENIED`, `DESTINATION_EXISTS`,
  `IDEMPOTENCY_CONFLICT`).

- `sg_integrity_error`:

  Hash, size or inventory mismatch (`INTEGRITY_MISMATCH`,
  `ARCHIVE_UNSAFE`).

- `sg_security_error`:

  Path traversal or unsafe resource (`PATH_OUTSIDE_ROOT`).
