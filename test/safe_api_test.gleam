import gleam/bit_array
import gleam/list
import gleam/string
import gleeunit/should
import glexif
import glexif/exif_tag
import simplifile

pub fn missing_file_returns_open_error_test() {
  case
    glexif.get_exif_data_for_file(
      "/tmp/glexif-safe-api-file-that-does-not-exist.jpeg",
    )
  {
    Error(glexif.FileOpenError(_)) -> Nil
    result -> {
      let message = "Expected FileOpenError, got " <> string.inspect(result)
      panic as message
    }
  }
}

pub fn directory_path_returns_file_error_test() {
  case glexif.get_exif_data_for_file("test/fixtures") {
    Error(glexif.FileOpenError(_)) | Error(glexif.FileReadError(_)) -> Nil
    result -> {
      let message = "Expected file error, got " <> string.inspect(result)
      panic as message
    }
  }
}

pub fn non_jpeg_returns_invalid_header_test() {
  with_fixture("non-jpeg", <<"not a jpeg":utf8>>, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidJpegHeader))
}

pub fn jpeg_without_exif_returns_marker_not_found_test() {
  with_fixture(
    "no-exif",
    <<0xff, 0xd8, 0xff, 0xd9>>,
    glexif.get_exif_data_for_file,
  )
  |> should.equal(Error(glexif.ExifMarkerNotFound))
}

pub fn non_exif_app1_is_ignored_test() {
  jpeg_with_app1(<<"http://ns.adobe.com/xap/1.0/":utf8, 0>>)
  |> with_fixture("xmp-app1", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.ExifMarkerNotFound))
}

pub fn truncated_marker_returns_error_test() {
  with_fixture(
    "truncated-marker",
    <<0xff, 0xd8, 0xff>>,
    glexif.get_exif_data_for_file,
  )
  |> should.equal(Error(glexif.UnexpectedEndOfFile))
}

pub fn truncated_segment_size_returns_error_test() {
  with_fixture(
    "truncated-size",
    <<0xff, 0xd8, 0xff, 0xe1, 0>>,
    glexif.get_exif_data_for_file,
  )
  |> should.equal(Error(glexif.UnexpectedEndOfFile))
}

pub fn truncated_segment_data_returns_error_test() {
  with_fixture(
    "truncated-data",
    <<0xff, 0xd8, 0xff, 0xe1, 0, 16, "Exif":utf8>>,
    glexif.get_exif_data_for_file,
  )
  |> should.equal(Error(glexif.UnexpectedEndOfFile))
}

pub fn invalid_segment_size_returns_error_test() {
  with_fixture(
    "invalid-size",
    <<0xff, 0xd8, 0xff, 0xe0, 0, 1>>,
    glexif.get_exif_data_for_file,
  )
  |> should.equal(Error(glexif.InvalidSegmentSize(1)))
}

pub fn invalid_exif_header_returns_error_test() {
  jpeg_with_app1(<<"Exif":utf8, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0>>)
  |> with_fixture("invalid-exif", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidExifHeader))
}

pub fn invalid_tiff_byte_order_returns_error_test() {
  jpeg_with_app1(<<"Exif":utf8, 0, 0, "ZZ":utf8, 0, 42, 0, 0, 0, 8>>)
  |> with_fixture("invalid-byte-order", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidTiffHeader))
}

pub fn invalid_tiff_magic_returns_error_test() {
  jpeg_with_app1(<<"Exif":utf8, 0, 0, "MM":utf8, 0, 41, 0, 0, 0, 8>>)
  |> with_fixture("invalid-tiff-magic", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidTiffHeader))
}

pub fn unsupported_data_type_skips_tag_test() {
  let entry = motorola_entry(0x0112, 13, 1, <<0, 0, 0, 1>>)

  motorola_exif(one_entry_ifd(entry, <<>>))
  |> with_fixture("unsupported-type", _, glexif.get_exif_data_for_file)
  |> should.equal(Ok(exif_tag.new()))
}

pub fn wrong_data_type_for_known_tag_skips_tag_test() {
  let entry = motorola_entry(0x0112, 2, 1, <<"1":utf8, 0, 0, 0>>)

  motorola_exif(one_entry_ifd(entry, <<>>))
  |> with_fixture("wrong-known-type", _, glexif.get_exif_data_for_file)
  |> should.equal(Ok(exif_tag.new()))
}

pub fn zero_rational_denominator_skips_tag_test() {
  let entry = motorola_entry(0x011a, 5, 1, <<0, 0, 0, 26>>)
  let rational = <<0, 0, 0, 1, 0, 0, 0, 0>>

  motorola_exif(one_entry_ifd(entry, rational))
  |> with_fixture("zero-rational", _, glexif.get_exif_data_for_file)
  |> should.equal(Ok(exif_tag.new()))
}

pub fn optional_value_offset_out_of_range_skips_tag_test() {
  let entry = motorola_entry(0x011a, 5, 1, <<0, 0, 1, 0>>)

  motorola_exif(one_entry_ifd(entry, <<>>))
  |> with_fixture("optional-offset", _, glexif.get_exif_data_for_file)
  |> should.equal(Ok(exif_tag.new()))
}

pub fn optional_value_offset_into_tiff_header_skips_tag_test() {
  let entry = motorola_entry(0x011a, 5, 1, <<0, 0, 0, 0>>)

  motorola_exif(one_entry_ifd(entry, <<>>))
  |> with_fixture("optional-header-offset", _, glexif.get_exif_data_for_file)
  |> should.equal(Ok(exif_tag.new()))
}

pub fn first_ifd_offset_out_of_range_returns_error_test() {
  jpeg_with_app1(<<"Exif":utf8, 0, 0, "MM":utf8, 0, 42, 0, 0, 0, 100>>)
  |> with_fixture("first-ifd-offset", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidOffset(100)))
}

pub fn linked_ifd_offset_out_of_range_returns_error_test() {
  let entry = motorola_entry(0x8769, 4, 1, <<0, 0, 0, 100>>)

  motorola_exif(one_entry_ifd(entry, <<>>))
  |> with_fixture("linked-ifd-offset", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidOffset(100)))
}

pub fn truncated_ifd_table_returns_error_test() {
  motorola_exif(<<0, 1>>)
  |> with_fixture("truncated-ifd", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.InvalidEntry(8)))
}

pub fn cyclic_ifd_offset_returns_error_test() {
  motorola_exif(<<0, 0, 0, 0, 0, 8>>)
  |> with_fixture("cyclic-ifd", _, glexif.get_exif_data_for_file)
  |> should.equal(Error(glexif.OffsetCycle(8)))
}

pub fn repeated_failed_reads_close_stream_test() {
  with_fixture("repeated-no-exif", <<0xff, 0xd8, 0xff, 0xd9>>, fn(path) {
    let descriptors_before = simplifile.read_directory("/proc/self/fd")
    list.range(1, 2048)
    |> list.each(fn(_) {
      glexif.get_exif_data_for_file(path)
      |> should.equal(Error(glexif.ExifMarkerNotFound))
    })

    let _ = case
      descriptors_before,
      simplifile.read_directory("/proc/self/fd")
    {
      Ok(before), Ok(after) -> {
        let descriptor_count_is_stable =
          list.length(after) <= list.length(before) + 2
        should.be_true(descriptor_count_is_stable)
      }
      // The repetition still runs on platforms without procfs.
      _, _ -> Nil
    }
    Nil
  })
}

pub fn error_to_string_is_stable_test() {
  [
    #(glexif.FileOpenError("denied"), "Could not open file: denied"),
    #(glexif.FileReadError("bad read"), "Could not read file: bad read"),
    #(glexif.FileCloseError("bad close"), "Could not close file: bad close"),
    #(glexif.InvalidJpegHeader, "Invalid JPEG header"),
    #(glexif.ExifMarkerNotFound, "No EXIF APP1 segment was found"),
    #(glexif.UnexpectedEndOfFile, "Unexpected end of file"),
    #(glexif.InvalidSegmentSize(1), "Invalid JPEG segment size: 1"),
    #(glexif.InvalidExifHeader, "Invalid EXIF header"),
    #(glexif.InvalidTiffHeader, "Invalid TIFF header"),
    #(glexif.InvalidEntry(12), "Invalid TIFF entry at offset 12"),
    #(glexif.InvalidOffset(20), "Invalid TIFF offset: 20"),
    #(glexif.OffsetCycle(8), "TIFF offset cycle detected at 8"),
    #(glexif.TraversalLimitExceeded, "TIFF traversal limit exceeded"),
  ]
  |> list.each(fn(pair) {
    let #(error, expected) = pair
    glexif.error_to_string(error) |> should.equal(expected)
  })
}

fn with_fixture(
  name: String,
  bits: BitArray,
  run: fn(String) -> result,
) -> result {
  let path = "/tmp/glexif-safe-api-" <> name <> ".jpeg"
  let assert Ok(Nil) = simplifile.write_bits(to: path, bits: bits)
  let output = run(path)
  let assert Ok(Nil) = simplifile.delete(file_or_dir_at: path)
  output
}

fn jpeg_with_app1(payload: BitArray) -> BitArray {
  let size = bit_array.byte_size(payload) + 2
  <<0xff, 0xd8, 0xff, 0xe1, size:size(16), payload:bits, 0xff, 0xd9>>
}

fn motorola_exif(ifd_and_data: BitArray) -> BitArray {
  jpeg_with_app1(<<
    "Exif":utf8,
    0,
    0,
    "MM":utf8,
    0,
    42,
    0,
    0,
    0,
    8,
    ifd_and_data:bits,
  >>)
}

fn one_entry_ifd(entry: BitArray, data: BitArray) -> BitArray {
  <<0, 1, entry:bits, 0, 0, 0, 0, data:bits>>
}

fn motorola_entry(
  tag: Int,
  data_type: Int,
  component_count: Int,
  value_or_offset: BitArray,
) -> BitArray {
  <<
    tag:size(16),
    data_type:size(16),
    component_count:size(32),
    value_or_offset:bits,
  >>
}
