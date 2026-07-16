// Verify the parsing of an EXIF segment within a real image gets the appropriate
// pieces split out. These raw entries are later formatted for consumers.
// import fixtures/test_segment
// import gleam/bit_array
// import gleam/io
// import gleam/list
// import gleam/result
// import gleeunit/should
// import glexif/exif_tag
// import glexif/internal/raw
// import glexif/internal/utils
// pub fn read_exif_segment_test() {
//   let assert Ok(rs) = read_stream.open("test/fixtures/test.jpeg")
//   let _ = raw.read_until_marker(rs)
//   let raw_size = raw.read_exif_size(rs)
//   let _ = read_stream.close(rs)
//
//   raw_size
//   |> should.equal(12_493)
//   // The raw siz of the full raw segment including all headers
//   let segment =
//     raw.read_exif_segment(rs, raw_size)
//     |> should.be_ok
//
//   segment
//   |> should.equal(raw.ExifSegment(
//     size: raw_size,
//     exif_header: <<69, 120, 105, 102, 0, 0>>,
//     tiff_header: raw.Motorola(<<0x4d, 0x4d, 0x0, 0x2A, 0x0, 0x0, 0x0, 0x8>>),
//     raw_data: test_segment.test_jpeg_segment_raw_data,
//   ))
//
//   // Full size of the segment - "size" (2 bytes) - the "Exif" header to get all 
//   // the raw bytes used for reading entries with offsets
//   bit_array.byte_size(segment.raw_data)
//   |> should.equal(12_493 - 2 - bit_array.byte_size(segment.exif_header))
// }
// pub fn get_raw_entries_test() {
//   let assert Ok(rs) = read_stream.open("test/fixtures/test.jpeg")
//   let _ = raw.read_until_marker(rs)
//   let raw_size = raw.read_exif_size(rs)
//   let _ = read_stream.close(rs)
//
//   raw_size
//   |> should.equal(12_493)
//   // The raw size of the full raw segment including all headers
//   let segment =
//     raw.read_exif_segment(rs, raw_size)
//     |> should.be_ok
//
//   segment
//   |> should.equal(raw.ExifSegment(
//     size: raw_size,
//     exif_header: <<69, 120, 105, 102, 0, 0>>,
//     tiff_header: raw.Motorola(<<0x4d, 0x4d, 0x0, 0x2A, 0x0, 0x0, 0x0, 0x8>>),
//     raw_data: test_segment.test_jpeg_segment_raw_data,
//   ))
//
//   // bit_array.base16_encode(test_segment.test_jpeg_segment_raw_data)
//   // |> should.equal("asdf")
//
//   let entry_count =
//     bit_array.slice(segment.raw_data, 8, 2)
//     |> result.unwrap(<<0, 0>>)
//     |> utils.bit_array_to_decimal
//
//   list.take(raw.get_raw_entries(segment.raw_data, 10, entry_count, 1), 38)
//   |> should.equal([
//     Ok(raw.RawExifEntry(raw.Make, raw.AsciiString(1), 6, <<"Apple":utf8, 0>>)),
//     Ok(
//       raw.RawExifEntry(raw.Model, raw.AsciiString(1), 14, <<
//         "iPhone 14 Pro":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.Orientation, raw.UnsignedShort(2), 1, <<
//         00, 06, 00, 00,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.XResolution, raw.UnsignedRational(8), 1, <<
//         00, 00, 00, 72, 00, 00, 00, 01,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.YResolution, raw.UnsignedRational(8), 1, <<
//         00, 00, 00, 72, 00, 00, 00, 01,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ResolutionUnit, raw.UnsignedShort(2), 1, <<
//         00, 02, 00, 00,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.Software, raw.AsciiString(1), 7, <<"17.2.1":utf8, 0>>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ModifyDate, raw.AsciiString(1), 20, <<
//         "2024:02:18 17:34:57":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.HostComputer, raw.AsciiString(1), 14, <<
//         "iPhone 14 Pro":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.YCbCrPositioning, raw.UnsignedShort(2), 1, <<
//         00, 01, 00, 00,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ExposureTime, raw.UnsignedRational(8), 1, <<
//         0, 0, 0, 1, 0, 0, 0, 179,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.FNumber, raw.UnsignedRational(8), 1, <<
//         0x00, 0x00, 0x00, 0x59, 0x00, 0x00, 0x00, 0x32,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ExposureProgram, raw.UnsignedShort(2), 1, <<
//         00, 02, 00, 00,
//       >>),
//     ),
//     Ok(raw.RawExifEntry(raw.ISO, raw.UnsignedShort(2), 1, <<00, 64, 00, 00>>)),
//     Ok(raw.RawExifEntry(raw.ExifVersion, raw.Undefined(1), 4, <<"0232":utf8>>)),
//     Ok(
//       raw.RawExifEntry(raw.DateTimeOriginal, raw.AsciiString(1), 20, <<
//         "2024:02:18 17:34:57":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.CreateDate, raw.AsciiString(1), 20, <<
//         "2024:02:18 17:34:57":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.OffsetTime, raw.AsciiString(1), 7, <<
//         "-06:00":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.OffsetTimeOriginal, raw.AsciiString(1), 7, <<
//         "-06:00":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.OffsetTimeDigitized, raw.AsciiString(1), 7, <<
//         "-06:00":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ComponentsConfiguration, raw.Undefined(1), 4, <<
//         01, 02, 03, 00,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ShutterSpeedValue, raw.SignedRational(8), 1, <<
//         0, 1, 232, 1, 0, 0, 65, 50,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ApertureValue, raw.UnsignedRational(8), 1, <<
//         0, 2, 127, 191, 0, 1, 128, 133,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.BrightnessValue, raw.SignedRational(8), 1, <<
//         0, 0, 50, 216, 0, 0, 9, 111,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ExposureCompensation, raw.SignedRational(8), 1, <<
//         0, 0, 0, 0, 0, 0, 0, 1,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.MeteringMode, raw.UnsignedShort(2), 1, <<0, 5, 0, 0>>),
//     ),
//     Ok(raw.RawExifEntry(raw.Flash, raw.UnsignedShort(2), 1, <<0, 16, 0, 0>>)),
//     Ok(
//       raw.RawExifEntry(raw.FocalLength, raw.UnsignedRational(8), 1, <<
//         0, 0, 1, 87, 0, 0, 0, 50,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.SubjectArea, raw.UnsignedShort(2), 4, <<
//         7, 217, 5, 225, 8, 160, 5, 44,
//       >>),
//     ),
//     Ok(raw.RawExifEntry(
//       raw.MakerData,
//       raw.Undefined(1),
//       1813,
//       test_segment.test_maker_data,
//     )),
//     Ok(
//       raw.RawExifEntry(raw.SubSecTimeOriginal, raw.AsciiString(1), 4, <<
//         "289":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.SubSecTimeDigitized, raw.AsciiString(1), 4, <<
//         "289":utf8, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.FlashpixVersion, raw.Undefined(1), 4, <<"0100":utf8>>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ColorSpace, raw.UnsignedShort(2), 1, <<
//         255, 255, 0, 0,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ExifImageWidth, raw.UnsignedLong(4), 1, <<
//         0, 0, 15, 192,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.ExifImageHeight, raw.UnsignedLong(4), 1, <<
//         0, 0, 11, 208,
//       >>),
//     ),
//     Ok(
//       raw.RawExifEntry(raw.SensingMethod, raw.UnsignedShort(2), 1, <<
//         0, 2, 0, 0,
//       >>),
//     ),
//     Ok(raw.RawExifEntry(raw.SceneType, raw.Undefined(1), 1, <<1, 0, 0, 0>>)),
//   ])
// }
// pub fn raw_exif_entry_to_parsed_tag_test() {
//   raw.RawExifEntry(raw.Make, raw.AsciiString(1), 6, <<"Apple":utf8, 0>>)
//   |> raw.raw_exif_entry_to_parsed_tag
//   |> should.equal(exif_tag.Make("Apple"))
//
//   raw.RawExifEntry(raw.Model, raw.AsciiString(1), 14, <<
//     "iPhone 14 Pro":utf8, 0,
//   >>)
//   |> raw.raw_exif_entry_to_parsed_tag
//   |> should.equal(exif_tag.Model("iPhone 14 Pro"))
// }

import gleam/option.{Some}
import gleeunit/should
import glexif/exif_tag
import glexif/exif_tags/color_space
import glexif/exif_tags/exposure_program
import glexif/internal/raw

pub fn signed_rational_motorola_test() {
  let entry =
    raw.RawExifEntry(
      tag: raw.BrightnessValue,
      data_type: raw.SignedRational(8),
      component_count: 1,
      data: <<0xff, 0xff, 0xff, 0xfd, 0, 0, 0, 2>>,
    )

  raw.raw_exif_entry_to_parsed_tag(exif_tag.new(), entry, raw.Motorola(<<>>)).brightness_value
  |> should.equal(Some(-1.5))
}

pub fn signed_rational_intel_test() {
  let entry =
    raw.RawExifEntry(
      tag: raw.ExposureCompensation,
      data_type: raw.SignedRational(8),
      component_count: 1,
      data: <<0xfd, 0xff, 0xff, 0xff, 2, 0, 0, 0>>,
    )

  raw.raw_exif_entry_to_parsed_tag(exif_tag.new(), entry, raw.Intel(<<>>)).exposure_compensation
  |> should.equal(Some(-1.5))
}

pub fn subsecond_ascii_preserves_leading_zeroes_test() {
  let entry =
    raw.RawExifEntry(
      tag: raw.SubSecTimeOriginal,
      data_type: raw.AsciiString(1),
      component_count: 4,
      data: <<"079":utf8, 0>>,
    )

  raw.raw_exif_entry_to_parsed_tag(exif_tag.new(), entry, raw.Motorola(<<>>)).sub_sec_time_original
  |> should.equal(Some("079"))
}

pub fn rational_precision_is_preserved_test() {
  let f_number =
    raw.RawExifEntry(
      tag: raw.FNumber,
      data_type: raw.UnsignedRational(8),
      component_count: 1,
      data: <<0, 0, 0, 89, 0, 0, 0, 50>>,
    )
  let focal_length =
    raw.RawExifEntry(
      tag: raw.FocalLength,
      data_type: raw.UnsignedRational(8),
      component_count: 1,
      data: <<0, 0, 1, 87, 0, 0, 0, 50>>,
    )

  let record =
    raw.raw_exif_entry_to_parsed_tag(
      exif_tag.new(),
      f_number,
      raw.Motorola(<<>>),
    )
    |> raw.raw_exif_entry_to_parsed_tag(focal_length, raw.Motorola(<<>>))

  record.f_number |> should.equal(Some(1.78))
  record.focal_length |> should.equal(Some(6.86))
}

pub fn extended_numeric_values_test() {
  let bulb =
    raw.RawExifEntry(
      tag: raw.ExposureProgram,
      data_type: raw.UnsignedShort(2),
      component_count: 1,
      data: <<0, 9>>,
    )
  let wide_gamut =
    raw.RawExifEntry(
      tag: raw.ColorSpace,
      data_type: raw.UnsignedShort(2),
      component_count: 1,
      data: <<0xff, 0xfd>>,
    )
  let icc_profile =
    raw.RawExifEntry(
      tag: raw.ColorSpace,
      data_type: raw.UnsignedShort(2),
      component_count: 1,
      data: <<0xff, 0xfe>>,
    )

  let record =
    raw.raw_exif_entry_to_parsed_tag(exif_tag.new(), bulb, raw.Motorola(<<>>))
    |> raw.raw_exif_entry_to_parsed_tag(wide_gamut, raw.Motorola(<<>>))

  record.exposure_program |> should.equal(Some(exposure_program.Bulb))
  record.color_space |> should.equal(Some(color_space.WideGamutRGB))

  raw.raw_exif_entry_to_parsed_tag(
    exif_tag.new(),
    icc_profile,
    raw.Motorola(<<>>),
  ).color_space
  |> should.equal(Some(color_space.ICCProfile))
}

pub fn gps_timestamp_uses_rational_denominators_test() {
  let entry =
    raw.RawExifEntry(
      tag: raw.GPSTimestamp,
      data_type: raw.UnsignedRational(8),
      component_count: 3,
      data: <<
        0, 0, 0, 23, 0, 0, 0, 1, 0, 0, 0, 34, 0, 0, 0, 1, 0, 0, 0, 113, 0, 0, 0,
        2,
      >>,
    )

  raw.raw_exif_entry_to_parsed_tag(exif_tag.new(), entry, raw.Motorola(<<>>)).gps_timestamp
  |> should.equal(Some("23:34:56.5"))
}
