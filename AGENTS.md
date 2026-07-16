# glexif Agent Guide

## Project Contract

- This is a pure Gleam library for reading standard EXIF metadata from JPEG APP1 segments. The public entrypoint `glexif.get_exif_data_for_file/1` returns `Result(ExifTagRecord, ExifError)` and must not panic for expected invalid input.
- Production parsing lives in `src/glexif/internal/raw.gleam`: walk JPEG segments to find a standard EXIF APP1 payload, validate the EXIF/TIFF headers, walk 12-byte IFD entries and linked EXIF/GPS IFDs, then fold `RawExifEntry` values into `ExifTagRecord`.
- `src/glexif/exif_tag.gleam` is the public data contract. Tag-specific enums live under `src/glexif/exif_tags/`; exact-value wrappers live under `src/glexif/units/`.
- `ExifTagRecordSimple` and `to_simple/1` are a temporary parity-test projection. They omit most GPS fields. A field added only to `ExifTagRecord` is not covered by the ExifTool record comparison.
- Maker notes, shutter-speed value, lens info, and some other tags remain intentionally unparsed/commented out. Do not imply support from a tag's presence in `RawExifTag` alone.
- CI pins OTP 27.0 and Gleam 1.17.0 even if the local Gleam is newer; avoid language features unavailable in Gleam 1.17.

## EXIF Parsing Rules

- TIFF supports Motorola (`MM`, big-endian) and Intel (`II`, little-endian) byte order. Endianness affects tag IDs, types, counts, offsets, and each integer inside a rational. Any byte-order refactor needs both Motorola and Intel regression coverage.
- IFD values whose total byte size is at most 4 are inline; larger values use an offset relative to the TIFF header. Preserve that distinction in `parse_data_or_offset/5`.
- `RATIONAL` is two unsigned 32-bit integers. `SRATIONAL` is two signed two's-complement 32-bit integers; never infer the sign from a nibble or discard the high byte.
- Preserve source precision. `ExposureTime` remains a `Fraction`; rational-derived floats must be numerator/denominator calculations without display rounding. `XResolution` and `YResolution` are rational values represented as `Float`.
- `ApertureValue` is stored as an APEX rational but exposed like ExifTool as an F-number using `2^(APEX / 2)`. `FNumber` and `FocalLength` are direct unsigned rationals; focal length is in millimeters. `BrightnessValue` and `ExposureCompensation` are signed rationals.
- EXIF ASCII remains text even when it resembles a number. In particular, `Software` may be `"26.5"`, and subsecond tags must preserve leading zeroes such as `"079"`.
- Numeric enum codes are authoritative; human labels are presentation. Keep raw parser mappings, tag enum types, and the ExifTool decoder mappings synchronized.
- Unknown numeric enum values should map to the corresponding `Invalid...` constructor where one exists rather than silently choosing a valid default.
- `extract_ascii_data/1` removes trailing NUL bytes and trims whitespace. Account for that normalization when adding ASCII fixture expectations.
- Invalid JPEG/TIFF structure, linked IFD pointers, and cycles are file-level errors. Unsupported or malformed optional tag values are skipped when they can be isolated safely.

## ExifTool Oracle

- ExifTool is the semantic reference, but default `exiftool -j` is not a raw correctness oracle: it applies print conversions, rounds rationals, emits localized/human labels, and may serialize numeric-looking ASCII as JSON numbers.
- Always generate parity JSON with the exact options used by `exif_tag_decoder/0`:

```sh
exiftool -j -n -api StructFormat=JSONQ -EXIF:all path/to/image.jpg
```

- `-n` disables human print conversion, `StructFormat=JSONQ` keeps all JSON leaves quoted so EXIF ASCII is not retyped, and `-EXIF:all` excludes XMP and maker-note tags that can overwrite standard EXIF names such as `ISO` or `MeteringMode`.
- `src/glexif/internal/decoders/exif_tag.gleam` decodes only that numeric, quoted format. It is a test oracle adapter, not the production JPEG parser.
- ExifTool exports many rationals as decimal values. Parity therefore compares those fields with `1e-11 + magnitude * 1e-9` tolerance and compares all strings, integers, lists, and enums exactly. Do not replace this with broad record rounding.
- ExifTool's decimal `ExposureTime` is converted to a high-precision approximate `Fraction` only for comparison; glexif's production fraction remains exact. Use direct `RawExifEntry` tests when exact numerator/denominator bytes matter.
- On a mismatch, first determine whether it is raw EXIF semantics, ExifTool value conversion, or presentation. Do not make glexif lossy merely to match default ExifTool display output.

## Testing Strategy

- `gleam test` is the complete verification command and requires the `exiftool` executable. Ubuntu CI installs it with `sudo apt-get install -y libimage-exiftool-perl`.
- Gleeunit discovers every public function under `test/` ending in `_test`; it has no native single-test filter. Do not assume `gleam test -- --match ...` works.
- `full_intel_test` and `full_motorola_test` assert complete records for representative byte orders. `test/internal/raw_test.gleam` isolates signed rationals, endian behavior, leading-zero ASCII, precision, and uncommon numeric codes.
- `auto_json_comparison_test` runs tracked files in `test/fixtures/pictures/` through both glexif and the exact ExifTool oracle, then checks Birdie snapshots in `birdie_snapshots/`.
- `test/private-fixtures/` is gitignored. When present, every JPEG/JPG there joins the ExifTool parity corpus; when absent, that test skips. Never commit private fixture photos.
- Every private JPEG calls the safe API. ExifTool records with no EXIF keys must correspond to `Error(ExifMarkerNotFound)`; records with EXIF keys retain the parity assertion.
- Intentional output changes create Birdie `.new` files. Review them with `gleam run -m birdie`; update accepted snapshots only after confirming the EXIF semantics, not merely to make tests green.
- When adding a supported tag, update all applicable layers: `RawExifTag` and `exif_tag_map`, byte/type extraction in `raw_exif_entry_to_parsed_tag`, the public record and `new`, `ExifTagRecordSimple`/`to_simple` if parity should cover it, the numeric ExifTool decoder, and focused plus fixture tests.
- A new rational-backed float must be added to both `records_match/2` and `without_decimal_rationals/1`; otherwise parity falls back to brittle exact float equality.

## Commands

```sh
gleam deps download
gleam format
gleam test
gleam format --check src test
```

- CI runs dependency download, `gleam test`, then `gleam format --check src test`. There is no separate lint, typecheck, or codegen step.
