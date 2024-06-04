import file_streams/read_stream.{type ReadStream}
import file_streams/read_stream_error.{type ReadStreamError}
import fixtures/test_segment
import gleam/bit_array
import gleam/io
import gleam/list
import gleam/result
import gleeunit/should
import glexif/exif_tag
import glexif/internal/raw
import glexif/internal/utils

/// Verify the parsing of a exif segment within a real image gets the appropriate
/// pieces split out
pub fn read_exif_segment_test() {
  let assert Ok(rs) = read_stream.open("test/fixtures/test.jpeg")
  let _ = raw.read_until_marker(rs)
  let raw_size = raw.read_exif_size(rs)
  let _ = read_stream.close(rs)

  raw_size
  |> should.equal(12_493)
  // The raw siz of the full raw segment including all headers
  let segment =
    raw.read_exif_segment(rs, raw_size)
    |> should.be_ok

  segment
  |> should.equal(raw.ExifSegment(
    size: raw_size,
    exif_header: <<69, 120, 105, 102, 0, 0>>,
    tiff_header: raw.Motorola(<<0x4d, 0x4d, 0x0, 0x2A, 0x0, 0x0, 0x0, 0x8>>),
    raw_data: test_segment.test_jpeg_segment_raw_data,
  ))

  // Full size of the segment - "size" (2 bytes) - the "Exif" header to get all 
  // the raw bytes used for reading entries with offsets
  bit_array.byte_size(segment.raw_data)
  |> should.equal(12_493 - 2 - bit_array.byte_size(segment.exif_header))
}

/// Test the raw parsed entries that are a rough parsing of all the information in each entry
/// these values will then be handed to be formatted for what a user actually would want. This step
/// could be optimized I'm sure, but it's a good intermediate step as I am learning the spec and how to 
/// interpret these things
pub fn get_raw_entries_test() {
  let assert Ok(rs) = read_stream.open("test/fixtures/test.jpeg")
  let _ = raw.read_until_marker(rs)
  let raw_size = raw.read_exif_size(rs)
  let _ = read_stream.close(rs)

  raw_size
  |> should.equal(12_493)
  // The raw size of the full raw segment including all headers
  let segment =
    raw.read_exif_segment(rs, raw_size)
    |> should.be_ok

  segment
  |> should.equal(raw.ExifSegment(
    size: raw_size,
    exif_header: <<69, 120, 105, 102, 0, 0>>,
    tiff_header: raw.Motorola(<<0x4d, 0x4d, 0x0, 0x2A, 0x0, 0x0, 0x0, 0x8>>),
    raw_data: test_segment.test_jpeg_segment_raw_data,
  ))

  let entry_count =
    bit_array.slice(segment.raw_data, 8, 2)
    |> result.unwrap(<<0, 0>>)
    |> utils.bit_array_to_decimal

  list.take(raw.get_raw_entries(segment.raw_data, 10, entry_count, 1), 27)
  |> should.equal([
    Ok(raw.RawExifEntry(raw.Make, raw.AsciiString(1), 6, <<"Apple":utf8, 0>>)),
    Ok(
      raw.RawExifEntry(raw.Model, raw.AsciiString(1), 14, <<
        "iPhone 14 Pro":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.Orientation, raw.UnsignedShort(2), 1, <<
        00, 06, 00, 00,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.XResolution, raw.UnsignedRational(8), 1, <<
        00, 00, 00, 72, 00, 00, 00, 01,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.YResolution, raw.UnsignedRational(8), 1, <<
        00, 00, 00, 72, 00, 00, 00, 01,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ResolutionUnit, raw.UnsignedShort(2), 1, <<
        00, 02, 00, 00,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.Software, raw.AsciiString(1), 7, <<"17.2.1":utf8, 0>>),
    ),
    Ok(
      raw.RawExifEntry(raw.ModifyDate, raw.AsciiString(1), 20, <<
        "2024:02:18 17:34:57":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.HostComputer, raw.AsciiString(1), 14, <<
        "iPhone 14 Pro":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.YCbCrPositioning, raw.UnsignedShort(2), 1, <<
        00, 01, 00, 00,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ExposureTime, raw.UnsignedRational(8), 1, <<
        0, 0, 0, 1, 0, 0, 0, 179,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.FNumber, raw.UnsignedRational(8), 1, <<
        0x00, 0x00, 0x00, 0x59, 0x00, 0x00, 0x00, 0x32,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ExposureProgram, raw.UnsignedShort(2), 1, <<
        00, 02, 00, 00,
      >>),
    ),
    Ok(raw.RawExifEntry(raw.ISO, raw.UnsignedShort(2), 1, <<00, 64, 00, 00>>)),
    Ok(raw.RawExifEntry(raw.ExifVersion, raw.Undefined(1), 4, <<"0232":utf8>>)),
    Ok(
      raw.RawExifEntry(raw.DateTimeOriginal, raw.AsciiString(1), 20, <<
        "2024:02:18 17:34:57":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.CreateDate, raw.AsciiString(1), 20, <<
        "2024:02:18 17:34:57":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.OffsetTime, raw.AsciiString(1), 7, <<
        "-06:00":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.OffsetTimeOriginal, raw.AsciiString(1), 7, <<
        "-06:00":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.OffsetTimeDigitized, raw.AsciiString(1), 7, <<
        "-06:00":utf8, 0,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ComponentsConfiguration, raw.Undefined(1), 4, <<
        01, 02, 03, 00,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ShutterSpeedValue, raw.SignedRational(8), 1, <<
        0, 1, 232, 1, 0, 0, 65, 50,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ApertureValue, raw.UnsignedRational(8), 1, <<
        0, 2, 127, 191, 0, 1, 128, 133,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.BrightnessValue, raw.SignedRational(8), 1, <<
        0, 0, 50, 216, 0, 0, 9, 111,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.ExposureCompensation, raw.SignedRational(8), 1, <<
        0, 0, 0, 0, 0, 0, 0, 1,
      >>),
    ),
    Ok(
      raw.RawExifEntry(raw.MeteringMode, raw.UnsignedShort(2), 1, <<0, 5, 0, 0>>),
    ),
    Ok(raw.RawExifEntry(raw.Flash, raw.UnsignedShort(2), 1, <<0, 16, 0, 0>>)),
  ])
}

pub fn raw_exif_entry_to_parsed_tag_test() {
  raw.RawExifEntry(raw.Make, raw.AsciiString(1), 6, <<"Apple":utf8, 0>>)
  |> raw.raw_exif_entry_to_parsed_tag
  |> should.equal(exif_tag.Make("Apple"))

  raw.RawExifEntry(raw.Model, raw.AsciiString(1), 14, <<
    "iPhone 14 Pro":utf8, 0,
  >>)
  |> raw.raw_exif_entry_to_parsed_tag
  |> should.equal(exif_tag.Model("iPhone 14 Pro"))
}
