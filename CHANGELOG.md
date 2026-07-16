# Changelog

## 0.1.0 - 2026-07-16

This is a breaking release. It replaces the panic-based file API with a typed
`Result`, changes two public field types, and preserves more of the precision
and semantics stored in EXIF rational and ASCII values.

### Breaking Changes

- `glexif.get_exif_data_for_file/1` now returns
  `Result(exif_tag.ExifTagRecord, glexif.ExifError)` instead of returning an
  `ExifTagRecord` directly. There is no legacy panic-based wrapper.
- `ExifTagRecord.x_resolution` and `ExifTagRecord.y_resolution` now use
  `Option(Float)` instead of `Option(Int)`. The same change applies to
  `ExifTagRecordSimple`.
- `ExifTagRecord.sub_sec_time_original` and
  `ExifTagRecord.sub_sec_time_digitized` now use `Option(String)` instead of
  `Option(Int)`. The same change applies to `ExifTagRecordSimple`. EXIF stores
  these fields as ASCII, so values such as `"079"` now retain leading zeroes.
- Rational-derived float fields preserve source precision instead of applying
  display rounding. Exact output may change for F-number, aperture value,
  brightness value, focal length, and fractional X/Y resolution. Consumers
  comparing floats should use an appropriate tolerance.
- `ApertureValue` is now exposed as an F-number calculated from its APEX value
  with `2^(APEX / 2)`. Code relying on the previous direct rational value must
  update its interpretation.
- `BrightnessValue` and `ExposureCompensation` now decode signed TIFF
  rationals correctly. Negative values that were previously interpreted as
  large unsigned values now produce negative floats.

### Typed Error API

- Added the public `glexif.ExifError` type for file open, read, and close
  failures; missing EXIF; truncated input; invalid JPEG, EXIF, and TIFF
  structure; invalid entries and offsets; offset cycles; and traversal limits.
- Added `glexif.ExifMarkerNotFound` as the stable result when a readable JPEG
  reaches image data or end-of-image without an EXIF candidate. An APP1
  payload beginning with `Exif` is treated as a candidate; if its required
  `Exif\0\0` header is malformed, parsing returns `InvalidExifHeader`.
- Added `glexif.error_to_string/1` for stable diagnostic formatting.
- Opened file streams are closed on both successful and failed parsing paths.
  If parsing and closing both fail, the parsing error is retained.

### Parsing And Correctness

- JPEG parsing now validates the start-of-image marker and walks declared JPEG
  segment boundaries rather than scanning arbitrary byte pairs.
- APP1 payloads that do not begin with `Exif`, including XMP, are ignored while
  searching. The first `Exif`-prefixed candidate is validated and either parsed
  or returned as an error. Searching stops at start-of-scan or end-of-image.
- EXIF and TIFF headers now validate their complete structure, including TIFF
  byte order, magic value, and declared first-IFD offset.
- IFD traversal now validates table bounds and linked EXIF, GPS, and next-IFD
  pointers. Offset cycles and excessive traversal return typed errors.
- TIFF values continue to follow the standard inline-versus-offset rule:
  values up to four bytes are inline, while larger values use offsets relative
  to the TIFF header.
- Intel and Motorola values are decoded by integer width and byte order. This
  corrects endian handling for tag IDs, types, counts, offsets, signed and
  unsigned rationals, multi-component values, and GPS data.
- GPS timestamps now apply each rational denominator. For example, seconds
  stored as `113/2` are returned as `"56.5"`.
- Exposure program code `9` now maps to `Bulb`.
- Color space code `0xfffd` now maps to `WideGamutRGB`, and `0xfffe` maps to
  `ICCProfile`.

### Malformed Optional Tags

- Structural JPEG, TIFF, and IFD corruption fails the file with `ExifError`.
- Unsupported or malformed optional tag values are skipped when they can be
  isolated safely, allowing other valid metadata to be returned.
- Unknown TIFF data types, invalid optional value offsets, invalid UTF-8,
  incorrect tag types or component counts, and zero rational denominators no
  longer panic or fabricate fallback values.
- Skipped optional tags remain `None`. This release does not expose warnings
  for skipped tags.

### Migration

Before `0.1.0`:

```gleam
let metadata = glexif.get_exif_data_for_file(path)
use_make(metadata.make)
```

With `0.1.0`:

```gleam
case glexif.get_exif_data_for_file(path) {
  Ok(metadata) -> use_make(metadata.make)
  Error(glexif.ExifMarkerNotFound) -> handle_photo_without_exif()
  Error(error) -> report(glexif.error_to_string(error))
}
```

Applications that consider a JPEG without EXIF to be valid should translate
`ExifMarkerNotFound` into their own empty or absent metadata representation.

### Supported Scope

- Standard EXIF APP1 data in JPEG files.
- Motorola (`MM`, big-endian) and Intel (`II`, little-endian) TIFF data.
- Standard, linked EXIF, GPS, and next-IFD traversal.

Maker notes, shutter-speed value, lens info, XMP, PNG EXIF containers, and
nonstandard APP1 payloads remain unsupported.

### Package Metadata

- Added the GitHub repository URL to the published package metadata.
- Added this changelog to the generated HexDocs pages.
