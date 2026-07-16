# EXIF Tag Coverage Plan

## Goal

Bring glexif closer to industry-level standard EXIF coverage while preserving raw EXIF semantics, byte-order correctness, and parity with ExifTool's numeric output.

This inventory is based on:

- The current `RawExifTag`, `ExifTagRecord`, parser branches, and commented TODOs.
- Tracked fixtures plus the local gitignored private fixture corpus.
- A scan of 274 images using:

```sh
exiftool -j -n -api StructFormat=JSONQ -EXIF:all test/fixtures/pictures test/private-fixtures
```

The corpus inventory is not an exhaustive list of every tag in the EXIF standard. It identifies concrete gaps already represented by the code or encountered in available images.

## Explicitly Unimplemented Tags

These tags have `RawExifTag` variants and entries in `exif_tag_map`, but their conversion branches are commented out. They currently fall through without modifying `ExifTagRecord`.

### ShutterSpeedValue (`0x9201`)

- Raw mapping: `src/glexif/internal/raw.gleam`.
- Public `shutter_speed_value` fields are commented out in `src/glexif/exif_tag.gleam`.
- The stored value is an APEX `SRATIONAL`; default ExifTool presentation may display exposure time instead of the stored APEX number.
- Decide the public contract before implementation: preserve the exact APEX `Fraction`, expose converted seconds, or expose both with unambiguous names.
- Add positive and negative `SRATIONAL` tests for Motorola and Intel byte order.

### MakerNote / MakerData (`0x927c`)

- Raw mapping exists, but the record conversion is commented out.
- Maker notes are vendor-specific and should not be treated as ordinary standard EXIF fields.
- Keep this separate from standard-tag completion. Reasonable first support would be opaque bytes plus make/model metadata; structured decoding requires vendor-specific parsers and offset rules.

### LensInfo (`0xa432`)

- Raw mapping exists, but four-rational conversion and public fields are commented out.
- The expected shape is four rationals describing minimum focal length, maximum focal length, minimum aperture at minimum focal length, and minimum aperture at maximum focal length.
- Prefer preserving the four source `Fraction` values. Add Motorola and Intel tests before adding display-oriented conversions.

The README currently shows these three fields as if they were active; update it when their final support status is decided.

## Partial Correctness And Verification Gaps

### GPS

The full public record currently exposes latitude, longitude, altitude, timestamp, and speed values, but `ExifTagRecordSimple` and the ExifTool parity decoder cover only `gps_latitude_ref`.

Not currently covered by ExifTool record parity:

- `gps_latitude`
- `gps_longitude_ref`
- `gps_longitude`
- `gps_altitude_ref`
- `gps_altitude`
- `gps_timestamp`
- `gps_speed_ref`
- `gps_speed`

Known risks to address before calling GPS support complete:

- GPS IFD pointer detection is hard-coded to Motorola-form bytes, so Intel GPS traversal needs an endian-aware implementation and regression fixture.
- GPS rational-list extraction needs explicit byte-order verification for every numerator and denominator.
- `GPSTimeStamp` currently uses numerators only and does not zero-pad values such as `05:18:55`.
- GPS coordinates should be compared numerically with ExifTool while retaining glexif's DMS representation and separate N/S/E/W references.
- Extend the parity projection or replace it with a dedicated oracle record so all active GPS fields are verified.

### SceneType (`0xa301`)

- Production parsing currently returns `DirectlyPhotographed` whenever the tag exists without checking its byte value.
- Validate code `1` explicitly and represent unsupported values rather than silently accepting them.

### Generic TIFF Types

- `RawExifType` recognizes TIFF type IDs 1 through 12, but public extraction is tag-specific and `extract_integer_data` handles only a subset.
- A recognized TIFF type does not imply that arbitrary tags using that type are supported.
- Add extraction helpers only when a supported tag requires them, with endian and signedness tests.

## Missing Tags Observed In The Corpus

### Exposure And Capture

- `CompressedBitsPerPixel`
- `MaxApertureValue`
- `LightSource`
- `SensitivityType`
- `StandardOutputSensitivity`
- `DigitalZoomRatio`
- `SubjectDistanceRange`

### Rendering And Source

- `FileSource`
- `CustomRendered`
- `Contrast`
- `Saturation`
- `Sharpness`
- `UserComment`

### Composite Images

- `CompositeImageCount`
- `CompositeImageExposureTimes`

`CompositeImage` itself is already supported.

### GPS

- `GPSVersionID`
- `GPSImgDirectionRef`
- `GPSImgDirection`
- `GPSDestBearingRef`
- `GPSDestBearing`
- `GPSDateStamp`
- `GPSHPositioningError`

### TIFF And Thumbnail IFD

- `Copyright`
- `TileWidth`
- `TileLength`
- `Compression`
- `ThumbnailOffset` / `JPEGInterchangeFormat`
- `ThumbnailLength` / `JPEGInterchangeFormatLength`

`ThumbnailImage` is derived by ExifTool from the offset and length; it is not a separate stored EXIF value. Decide whether glexif should expose thumbnail metadata, extracted bytes, or neither before implementing these tags.

### Interoperability IFD

- `InteropIndex`
- `InteropVersion`
- `InteropOffset` traversal is also required before these values can be read reliably.

## Out Of Scope Unless Deliberately Added

- XMP, ICC, MPF, JPEG container properties, and file-system metadata are not standard EXIF tag-reading responsibilities for this library.
- Vendor MakerNote subfields are not part of generic standard EXIF support and should not be added to the primary parser as if their layouts were universal.
- `SourceFile` is ExifTool output metadata, not image EXIF metadata.

## Recommended Implementation Order

1. Complete and parity-test the GPS fields already present in `ExifTagRecord`, including Intel GPS traversal and timestamp formatting.
2. Implement `LensInfo` with exact fractions.
3. Define and implement the `ShutterSpeedValue` public representation without conflating raw APEX data with displayed exposure time.
4. Add broadly useful standard fields: `UserComment`, sensitivity tags, `DigitalZoomRatio`, `LightSource`, and rendering enums.
5. Add the remaining GPS direction/date/error tags.
6. Add composite-image source fields.
7. Add Interoperability IFD traversal and values.
8. Decide whether thumbnail metadata and extraction belong in the public API.
9. Treat MakerNote decoding as a separate vendor-specific project.

## Per-Tag Completion Checklist

For every newly supported tag:

1. Add the correct `RawExifTag` and IFD/GPS map entry.
2. Verify the EXIF type, component count, inline-versus-offset storage, signedness, and byte order.
3. Parse it in `raw_exif_entry_to_parsed_tag` without display rounding or type coercion.
4. Add the public record field and initialize it in `new`.
5. Add it to `ExifTagRecordSimple` and `to_simple` when ExifTool parity should cover it.
6. Decode ExifTool's numeric `StructFormat=JSONQ` representation using numeric codes rather than labels.
7. Add rational-backed floats to both `records_match/2` and `without_decimal_rationals/1`.
8. Add focused raw-byte tests, including both byte orders when applicable.
9. Add or update a tracked fixture and review the Birdie snapshot semantically.
10. Run `gleam test` and `gleam format --check src test`.
