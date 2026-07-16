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

## Note about AI
The first releases of this library (<0.1.0) was created without any AI. It was a fun project to stretch my skills out of the regular web development world I know into something different. But I am not expert in the world of photography and bit parsing. So some of the first rounds of data were partially incorrect and a lot of it was incomplete. But for version 0.1.0 I needed something slightly more filled out to work with a different side-project. So this is a warning that 0.1.0 indeed leveraged AI just to get it to a better spot for my needs.

I haven't followed the Gleam Community's feelings on AI, and I have plenty of mixed feelings myself. So I wanted to be at least transparent about the project so you can make your own mind on using this as a dependency or not.
