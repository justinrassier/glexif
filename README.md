# glexif

[![Package Version](https://img.shields.io/hexpm/v/glexif)](https://hex.pm/packages/glexif)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glexif/)

A pure Gleam library for reading standard EXIF metadata from JPEG APP1
segments.

## Installation

```sh
gleam add glexif
```

## Usage

`get_exif_data_for_file/1` returns a typed `Result` and does not panic for
missing, unreadable, unsupported, truncated, or malformed input.

```gleam
import gleam/io
import glexif

pub fn main() {
  case glexif.get_exif_data_for_file("photo.jpeg") {
    Ok(metadata) -> io.debug(metadata)
    Error(glexif.ExifMarkerNotFound) ->
      io.println("The JPEG has no EXIF metadata")
    Error(error) -> io.println(glexif.error_to_string(error))
  }
}
```

`ExifMarkerNotFound` is a stable, expected condition when a readable JPEG has
no `Exif`-prefixed APP1 candidate. A candidate with a malformed `Exif\0\0`
header returns `InvalidExifHeader` instead. Other `ExifError` constructors
describe file I/O, malformed JPEG segments, invalid EXIF or TIFF headers,
truncated data, unsafe offsets, and cyclic IFD links. `error_to_string/1`
provides stable diagnostic formatting when a consumer does not need to pattern
match every constructor.

## Parsing Policy

File-level structural failures return `Error` without fabricating metadata.
These include invalid JPEG framing, truncated segments, malformed TIFF headers,
invalid IFD tables or pointers, and offset cycles.

An unsupported or malformed optional tag is skipped when it can be isolated
safely and the containing JPEG, TIFF header, and IFD structure remain valid.
For example, an unknown TIFF data type or a rational with a zero denominator
does not discard other valid EXIF fields. The result does not currently include
warnings for skipped tags.

## Supported Formats

- JPEG files containing standard EXIF APP1 segments
- Motorola (`MM`, big-endian) TIFF data
- Intel (`II`, little-endian) TIFF data
- Inline TIFF values up to four bytes and TIFF-relative offset values
- Standard IFD, linked EXIF IFD, GPS IFD, and next-IFD traversal

The public `ExifTagRecord` documents the currently exposed tags. Maker notes,
shutter-speed value, lens info, XMP, PNG EXIF containers, and nonstandard APP1
payloads are not parsed. Unknown non-EXIF APP1 segments are ignored while
looking for a standard EXIF segment.

## Development

The complete test suite requires ExifTool:

```sh
gleam deps download
gleam format
gleam test
gleam format --check src test
```

Further API documentation is available at <https://hexdocs.pm/glexif>.
Release and migration notes are available in the
[changelog](https://hexdocs.pm/glexif/changelog.html).
