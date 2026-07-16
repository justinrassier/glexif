# Glexif Safe Result API

## Handoff Context

- Glexif checkout: `/home/justinrassier/git/glexif`
- Consumer checkout: `/home/justinrassier/git/otp_learning`
- `photo_flow` currently consumes the local checkout with `glexif = { path = "../glexif" }`.
- `photo_flow` currently calls `glexif:get_exif_data_for_file/1` through `src/photo_flow_glexif_ffi.erl` because the Glexif API can panic.
- The FFI catches Erlang exceptions and converts them into a Gleam `Result`, allowing `ExifParser` to persist an EXIF failure and continue processing its mailbox.

## Objective

Add a public, typed Glexif API that returns `Result` and does not panic for missing, unreadable, unsupported, truncated, or malformed input. Once that contract is implemented and tested, `photo_flow` can call Glexif directly and delete its Erlang exception wrapper.

The safe API must also make a JPEG with no EXIF segment distinguishable from malformed EXIF. This is an expected input condition for `photo_flow`: it needs to persist an empty metadata summary and continue face detection rather than dropping an otherwise valid photo.

## Consumer Evidence: JPEGs Without EXIF

`photo_flow` currently has 31 paths in `photo_processing_errors` with the same panic from `glexif.get_exif_data_for_file` at `src/glexif.gleam:19`. ExifTool reports no EXIF tags for sampled files, and none of these paths has a persisted `photos` row. The files are therefore being excluded from face detection even though the JPEG content itself is usable.

Glexif's current private-fixture parity test does not expose this problem. In `test/glexif_test.gleam`, it checks ExifTool first and skips the Glexif call when ExifTool returns an empty EXIF record:

```gleam
case exiftool_parsed == exif_tag.to_simple(exif_tag.new()) {
  True -> Nil
  False -> glexif.get_exif_data_for_file(pic_path)
}
```

That branch must not remain the only behavior exercised for no-EXIF JPEGs. The safe API must be called for every private JPEG, including files for which ExifTool reports no EXIF data.

## Required Public Contract

Add a safe API such as:

```gleam
pub fn read_exif_data_for_file(
  path: String,
) -> Result(exif_tag.ExifTagRecord, ExifError)
```

Expose a public error type. The exact constructors may evolve while implementing, but it must distinguish the major failure classes without leaking panics:

```gleam
pub type ExifError {
  FileOpenError(message: String)
  FileReadError(message: String)
  ExifMarkerNotFound
  UnexpectedEndOfFile
  InvalidSegmentSize(size: Int)
  InvalidExifHeader(message: String)
  InvalidTiffHeader(message: String)
  InvalidEntry(message: String)
  UnsupportedDataType(data_type: Int)
  InvalidRational
  InvalidOffset(offset: Int)
}
```

Also provide stable user-facing formatting so consumers do not need to know every constructor:

```gleam
pub fn error_to_string(error: ExifError) -> String
```

`ExifMarkerNotFound` (or an equivalently specific public constructor) is required as a stable condition that consumers can pattern match. It must not be collapsed into a generic invalid-file or read error. A valid JPEG with no EXIF APP1 segment should return this typed error without panicking.

The existing panic-based `get_exif_data_for_file` may remain temporarily as a compatibility wrapper, but the new safe function must not call through a path that can panic. If changing the existing function to return `Result`, treat that as a breaking API change and update all tests and documentation.

## Current Failure Paths

### Top-Level API

`src/glexif.gleam` currently has several unsafe behaviors:

1. `let assert Ok(rs) = file_stream.open_read(file_path)` panics for missing or unreadable files.
2. The result of `raw.read_until_marker(rs)` is ignored.
3. `raw.read_exif_size(rs)` converts read failure into `0`.
4. The stream is closed before `raw.read_exif_segment(rs, size)` attempts to read the segment.
5. A segment parsing error falls through to `panic`.

The stream must remain open through marker, size, and segment reads, and it must be closed on every success or error return path.

### Raw Segment Reading

`src/glexif/internal/raw.gleam` currently hides structural failures with fallback values:

- `read_exif_size` returns `0` after a stream error.
- `read_exif_segment` unwraps a failed read into `<<>>`.
- Bit-array slices frequently unwrap failures into empty arrays or zeros.
- `exif_full_size - 2` can become invalid for malformed sizes.
- Invalid offsets can lead to out-of-bounds reads or unsafe recursion.

Container-level corruption should return a typed `Error`, not an empty value that fails later in a less specific location.

### Tag Parsing

`extract_integer_data` currently contains:

```gleam
_ -> panic as "unimplemented data type"
```

Replace this with either a typed error or a deliberate unsupported-tag skip. A malformed or unsupported individual tag should preferably not discard otherwise valid EXIF data, but the behavior must be explicit and must never panic.

### Unsafe Arithmetic

Validate all rational values before division. Current parsing includes divisions for:

- Unsigned and signed rational values
- GPS degrees and minutes
- Other numeric EXIF fields

A zero denominator must return an error or skip the affected field. It must not crash the process.

Audit the complete safe API call graph for:

- `panic`
- `let assert`
- unchecked division
- negative bit sizes
- invalid offsets
- recursive offset cycles
- assumptions that a bit-array slice always exists

Pure Gleam cannot catch a panic after it occurs, so a trustworthy `Result` API requires removing every reachable expected-input panic rather than wrapping it in another Gleam function.

## Suggested Implementation Shape

The top-level function should preserve the first error while still closing the stream:

```gleam
pub fn read_exif_data_for_file(path: String) {
  use stream <- result.try(
    file_stream.open_read(path)
    |> result.map_error(fn(error) {
      FileOpenError(file_stream_error.to_string(error))
    }),
  )

  let outcome = {
    use _ <- result.try(find_exif_marker(stream))
    use size <- result.try(read_exif_size(stream))
    use segment <- result.try(read_exif_segment(stream, size))
    parse_exif_data_as_record(segment)
  }

  let _ = file_stream.close(stream)
  outcome
}
```

Adapt this sketch to the actual `file_streams` error API. Do not close the stream before reading the EXIF segment.

Lower-level functions should return `Result` where malformed input can invalidate parsing. Avoid broad `result.unwrap` defaults for structural reads. Defaults remain reasonable only for optional EXIF fields whose absence is valid.

## Error Policy

Use this distinction consistently:

- Return `Error(ExifMarkerNotFound)` for an otherwise readable JPEG with no EXIF APP1 segment. This is a file-level inability to produce an `ExifTagRecord`, but consumers may treat it as a valid photo with absent metadata.
- Fail the file with another typed error for invalid JPEG/EXIF container structure, truncated data, invalid TIFF headers, unsafe offsets, or unrecoverable stream failures.
- Skip an individual optional tag when the containing EXIF structure is valid but that tag is unsupported or malformed and can be isolated safely.
- Never return a partially fabricated value produced from empty fallback bytes after a structural read failed.

If warnings for skipped tags are important, that can become a future richer return type. It is not required to remove the `photo_flow` FFI boundary.

## Required Tests

Add deterministic tests proving the safe API returns `Ok` or `Error` without crashing:

1. Existing valid Intel fixture returns the same `ExifTagRecord`.
2. Existing valid Motorola fixture returns the same `ExifTagRecord`.
3. Missing file returns `Error(FileOpenError(...))`.
4. Unreadable file returns a file-related `Error` where the platform permits the test.
5. Non-JPEG input returns `Error`.
6. JPEG without an EXIF marker returns exactly `Error(ExifMarkerNotFound)` and never panics.
7. Truncated marker, segment-size, and segment-data fixtures return `Error`.
8. Invalid EXIF header returns `Error`.
9. Invalid TIFF byte order returns `Error`.
10. Unsupported EXIF data types return an error or skip the tag without panic.
11. Zero rational denominators return an error or skip the field without panic.
12. Out-of-range and cyclic offsets terminate with `Error` rather than recursing indefinitely.
13. Repeated failed reads do not leak file handles.

Add a private-fixture verification test or development command that walks `test/private-fixtures` and calls the safe Glexif API for every supported file. The corpus does not need to be committed. The test must distinguish these outcomes:

- ExifTool found EXIF: require `Ok(record)` and retain the existing parity assertions.
- ExifTool found no EXIF: require `Error(ExifMarkerNotFound)` (or the chosen equivalent), not a skipped Glexif call.
- Malformed or unsupported private input: permit another typed `Error`, but never a panic or process exit.

The existing `True -> Nil` no-EXIF branch is insufficient because it bypasses the exact API path that currently panics in `photo_flow`.

Run:

```sh
gleam format
gleam test
```

## Documentation Requirements

Update Glexif's README and generated API documentation with:

- The safe API example
- The public error model
- The difference between file-level failure and skipped unsupported tags
- Any retained legacy panic-based API and its deprecation status
- The currently supported JPEG/EXIF formats

## Acceptance Criteria

The Glexif work is complete for this integration when:

- A public function returns `Result(ExifTagRecord, ExifError)`.
- Missing and malformed inputs do not panic the calling actor or process.
- No reachable `panic` or `let assert` remains in the safe API's expected-input call path.
- Invalid sizes, offsets, slices, and rational denominators are validated.
- The file stream is closed after both successful and failed parsing.
- Existing valid fixture output remains unchanged.
- The private fixture corpus can be swept without crashing.
- Every no-EXIF private JPEG invokes the safe API and returns the specific no-marker error.
- `gleam format && gleam test` passes in Glexif.

## Photo Flow Follow-Up

After the safe Glexif API is available, update `/home/justinrassier/git/otp_learning`:

1. Replace the external declaration in `src/photo_flow/exif_parser.gleam` with a direct `glexif.read_exif_data_for_file(path)` call.
2. Pattern match `Error(ExifMarkerNotFound)` as an expected absence of metadata. Construct a `photo_metadata.Summary` for the path with every EXIF-derived field set to `None`, clear any existing `photo_processing_errors` EXIF row, persist the photo metadata/hash/fingerprint, and continue face detection normally.
3. Map every other `ExifError` through `glexif.error_to_string` before persisting `photo_processing_errors` and skipping the photo.
4. Delete `src/photo_flow_glexif_ffi.erl`.
5. Update the real-boundary integration tests to call the direct safe API. Include a no-EXIF JPEG proving that Photo Flow stores an empty summary, clears a historical EXIF error, and emits detection only after metadata commits.
6. Update `AGENTS.md` and `README.md` to remove the Erlang exception-boundary requirement and document no-EXIF handling.
7. Run `gleam format && gleam test` in `photo_flow`.

Do not remove the `photo_flow` FFI wrapper until the safe Glexif API and malformed-input tests are complete. Returning `Result` at only the top level is insufficient if internal parsing can still panic.
