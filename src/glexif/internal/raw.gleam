import file_streams/read_stream.{type ReadStream}
import file_streams/read_stream_error.{type ReadStreamError}
import gleam/bit_array
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glexif/exif_tag
import glexif/internal/utils

pub type ExifParseError {
  BadHeaders(message: String)
  InvalidEntry(entry_byte_string: String)
}

pub type TiffHeader {
  Intel(header_bytes: BitArray)
  Motorola(header_bytes: BitArray)
}

pub type RawExifType {
  UnsignedByte(bytes: Int)
  AsciiString(bytes: Int)
  UnsignedShort(bytes: Int)
  UnsignedLong(bytes: Int)
  UnsignedRational(bytes: Int)
  SignedByte(bytes: Int)
  Undefined(bytes: Int)
  SignedShort(bytes: Int)
  SignedLong(bytes: Int)
  SignedRational(bytes: Int)
  SingleFloat(bytes: Int)
  DoubleFloat(bytes: Int)
  Unknown(bytes: Int)
}

pub type ExifSegment {
  ExifSegment(
    /// full size of the segment
    size: Int,
    /// the raw "Exif" header in byte array form
    exif_header: BitArray,
    /// The parsed type of Header (Motorola or Intel)
    tiff_header: TiffHeader,
    /// the full segment bit array that includes the TIFF Header  ("MM", or "II")
    /// but not the Exif" bytes which is used in offset calculations
    raw_data: BitArray,
  )
}

pub type RawExifTag {
  Make
  Model
  Orientation
  XResolution
  YResolution
  ResolutionUnit
  Software
  ModifyDate
  HostComputer
  YCbCrPositioning
  ExifOffset
  ExposureTime
  FNumber
  ExposureProgram
  ISO
  ExifVersion
  DateTimeOriginal
  CreateDate
  OffsetTime
  OffsetTimeOriginal
  OffsetTimeDigitized
  ComponentsConfiguration
  ShutterSpeedValue
  ApertureValue
  BrightnessValue
  ExposureCompensation
  MeteringMode
  Flash
  FocalLength
  SubjectArea
  MakerData
  SubSecTimeOriginal
  SubSecTimeDigitized
  FlashpixVersion

  IFDLink(Int)
  // EndOfLink
  // Paired with ExifOffset
  EndOfIFD
  // No more offset. End of everything
  UnknownExifTag(entry_byte_string: String)
}

// Raw
pub type RawExifEntry {
  // tag: 2 bytes
  // data_type: 2 bytes
  // component_count: 4 bytes
  // data_or_offset: 4 bytes
  RawExifEntry(
    tag: RawExifTag,
    data_type: RawExifType,
    component_count: Int,
    data: BitArray,
  )
}

/// move the stream ahead by reading until the exif marker in the file
pub fn read_until_marker(
  rs: read_stream.ReadStream,
) -> Result(BitArray, ReadStreamError) {
  case read_stream.read_bytes(rs, 2) {
    Ok(bytes) -> {
      let _ = case bytes {
        <<0xFF, 0xE1>> -> Ok(bytes)
        _ -> read_until_marker(rs)
      }
    }
    Error(e) -> Error(e)
  }
}

/// size is the two bytes after the exif marker
pub fn read_exif_size(rs: ReadStream) -> Int {
  case read_stream.read_int16_be(rs) {
    Ok(val) -> {
      val
    }
    Error(_) -> 0
  }
}

pub fn read_exif_segment(
  rs: ReadStream,
  exif_full_size: Int,
) -> Result(ExifSegment, ExifParseError) {
  // the exif size info is part of the data size itself, and we already read those bytes in
  let raw_bytes =
    result.unwrap(read_stream.read_bytes(rs, exif_full_size - 2), <<>>)

  let exif_header_bytes = bit_array.slice(raw_bytes, 0, 6)

  let tiff_header_type =
    raw_bytes
    |> bit_array.slice(6, 8)
    |> result.unwrap(<<>>)
    |> get_tiff_header

  let raw_data =
    raw_bytes
    |> bit_array.slice(6, bit_array.byte_size(raw_bytes) - 6)
    |> result.unwrap(<<>>)

  case exif_header_bytes, tiff_header_type {
    Ok(<<69, 120, 105, 102, 0, 0>>), Ok(tiff_header) ->
      Ok(ExifSegment(
        size: exif_full_size,
        exif_header: <<69, 120, 105, 102, 0, 0>>,
        tiff_header: tiff_header,
        raw_data: raw_data,
      ))
    _, Error(m) -> Error(m)
    _, _ -> Error(BadHeaders("Generic error"))
  }
}

fn get_tiff_header(
  tiff_header_bytes: BitArray,
) -> Result(TiffHeader, ExifParseError) {
  case bit_array.slice(tiff_header_bytes, 0, 2) {
    Ok(<<0x4d, 0x4d>>) -> Ok(Motorola(tiff_header_bytes))
    Ok(<<0x49, 0x49>>) -> Ok(Intel(tiff_header_bytes))
    _ -> Error(BadHeaders("No matching tiff header type (Motorola or Intel)"))
  }
}

pub fn parse_exif_data(exif_segment: ExifSegment) -> List(exif_tag.ExifTag) {
  // let total_entries =
  //   exif_segment.raw_data
  //   |> bit_array.slice(8, 2)
  //   |> result.unwrap(<<>>)
  //   |> bit_array_to_decimal

  // entries are 12 bytes long. They start at an offset of 8, but including the "MM" header bytes means we start at 10
  let entry_count =
    bit_array.slice(exif_segment.raw_data, 8, 2)
    |> result.unwrap(<<0, 0>>)
    |> utils.bit_array_to_decimal

  get_raw_entries(exif_segment.raw_data, 10, entry_count, 1)
  |> list.map(fn(r) {
    case r {
      Ok(raw_tag) -> raw_exif_entry_to_parsed_tag(raw_tag)
      Error(_) -> exif_tag.Unknown
    }
  })
}

pub fn get_raw_entries(
  segment_bytes: BitArray,
  start: Int,
  total_segment_count: Int,
  current_entry: Int,
) -> List(Result(RawExifEntry, ExifParseError)) {
  let entry_bits = bit_array.slice(segment_bytes, start, 12)

  let tag = parse_raw_exif_tag(entry_bits, current_entry, total_segment_count)

  // io.debug(
  //   int.to_string(current_entry) <> "/" <> int.to_string(total_segment_count),
  // )
  // io.debug(tag)
  let data_type =
    entry_bits
    |> result.try(bit_array.slice(_, 2, 2))
    |> result.map(utils.bit_array_to_decimal)
    |> result.try(dict.get(exif_type_map(), _))

  let component_count =
    entry_bits
    |> result.try(bit_array.slice(_, 4, 4))
    |> result.map(utils.bit_array_to_decimal)

  let data =
    entry_bits
    |> result.try(bit_array.slice(_, 8, 4))
    |> result.try(parse_data_or_offset(
      _,
      segment_bytes,
      data_type,
      result.unwrap(component_count, 0),
    ))

  case tag, data_type, component_count, data {
    // In the case we hit the ExifOffset, this points us to a different offset location
    // to start parsing out more
    ExifOffset, _, _, Ok(data) -> {
      let offset = utils.bit_array_to_decimal(data)
      let entry_count =
        bit_array.slice(segment_bytes, offset, 2)
        |> result.unwrap(<<0, 0>>)
        |> utils.bit_array_to_decimal
      // first 2 bytes is the number of elements.
      list.append(
        // recurse down the offset
        get_raw_entries(segment_bytes, offset + 2, entry_count, 1),
        // continue recursing the current segment
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
        ),
      )
    }
    // link off to the next IFD
    IFDLink(offset), _, _, _ -> {
      // io.debug("exif offset?")
      // io.debug(
      //   int.to_string(current_entry)
      //   <> "/"
      //   <> int.to_string(total_segment_count),
      // )
      // io.debug(tag)
      let entry_count =
        bit_array.slice(segment_bytes, offset, 2)
        |> result.unwrap(<<0, 0>>)
        |> utils.bit_array_to_decimal
      list.append(
        get_raw_entries(segment_bytes, offset + 2, entry_count, 1),
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
        ),
      )
    }
    t, Ok(data_type), Ok(component_count), Ok(data)
      if current_entry <= total_segment_count
    -> {
      let base_element = [
        Ok(RawExifEntry(
          tag: t,
          data_type: data_type,
          component_count: component_count,
          data: data,
        )),
      ]
      list.append(
        base_element,
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
        ),
      )
    }
    _, _, _, _ -> {
      // io.debug("here?")
      // io.debug(
      //   int.to_string(current_entry)
      //   <> "/"
      //   <> int.to_string(total_segment_count),
      // )
      // io.debug(tag)
      []
    }
  }
}

/// Takes the entry and tries to map it to a known RawExifTag
fn parse_raw_exif_tag(
  entry: Result(BitArray, Nil),
  current_entry_count: Int,
  total_segment_count: Int,
) -> RawExifTag {
  // the one segment past the last segment is either offset to a new link or the end of things
  let end_or_offset_index = total_segment_count + 1
  entry
  |> result.try(bit_array.slice(_, 0, 2))
  |> result.try(dict.get(exif_tag_map(), _))
  |> result.try_recover(fn(_) {
    case current_entry_count, total_segment_count {
      // if we are one past the last entry, that will either be an offset
      // to a new IFD or it will mark the end
      c, _ if c == end_or_offset_index -> {
        case bit_array.slice(result.unwrap(entry, <<>>), 0, 4) {
          Ok(<<0, 0, 0, 0>>) -> {
            Ok(EndOfIFD)
          }
          Ok(offset_bits) -> {
            let offset = utils.bit_array_to_decimal(offset_bits)
            Ok(IFDLink(offset))
          }
          _ -> Error(Nil)
        }
      }
      // if we got past the last entry, which happens at the very end of recursion, we are done
      c, _ if c > end_or_offset_index -> {
        Ok(EndOfIFD)
      }
      _, _ -> Error(Nil)
    }
  })
  |> result.unwrap(
    UnknownExifTag(bit_array.base16_encode(result.unwrap(entry, <<>>))),
  )
}

/// Convert the sub-optimal raw partially parsed entry into
/// the final consumable tag
pub fn raw_exif_entry_to_parsed_tag(entry: RawExifEntry) -> exif_tag.ExifTag {
  case entry.tag {
    Make ->
      entry.data
      |> extract_ascii_data
      |> exif_tag.Make

    Model ->
      entry.data
      |> extract_ascii_data
      |> exif_tag.Model

    Orientation ->
      entry
      |> extract_integer_data
      |> dict.get(exif_orientation_map(), _)
      |> result.unwrap(exif_tag.InvalidOrientation)
      |> exif_tag.Orientation

    XResolution -> exif_tag.XResolution(extract_integer_data(entry))
    YResolution -> exif_tag.YResolution(extract_integer_data(entry))
    ResolutionUnit -> {
      case extract_integer_data(entry) {
        1 -> exif_tag.ResolutionUnit(exif_tag.None)
        2 -> exif_tag.ResolutionUnit(exif_tag.Inches)
        3 -> exif_tag.ResolutionUnit(exif_tag.Centimeters)
        _ -> exif_tag.ResolutionUnit(exif_tag.InvalidResolutionUnit)
      }
    }
    Software ->
      entry.data
      |> extract_ascii_data
      |> exif_tag.Software

    ModifyDate ->
      entry.data
      |> extract_ascii_data
      |> exif_tag.ModifyDate

    HostComputer ->
      entry.data
      |> extract_ascii_data
      |> exif_tag.HostComputer

    YCbCrPositioning -> {
      case extract_integer_data(entry) {
        1 -> exif_tag.YCbCrPositioning(exif_tag.Centered)
        2 -> exif_tag.YCbCrPositioning(exif_tag.CoSited)
        _ -> exif_tag.YCbCrPositioning(exif_tag.InvalidYCbCrPositioning)
      }
    }
    ExposureTime ->
      exif_tag.ExposureTime(extract_unsigned_rational_to_fraction(entry.data))

    FNumber ->
      exif_tag.FNumber(extract_unsigned_rational_to_fraction(entry.data))

    ExposureProgram ->
      case extract_integer_data(entry) {
        0 -> exif_tag.ExposureProgram(exif_tag.NotDefined)
        1 -> exif_tag.ExposureProgram(exif_tag.Manual)
        2 -> exif_tag.ExposureProgram(exif_tag.ProgramAE)
        3 -> exif_tag.ExposureProgram(exif_tag.AperturePriorityAE)
        4 -> exif_tag.ExposureProgram(exif_tag.ShutterSpeedPriorityAE)
        5 -> exif_tag.ExposureProgram(exif_tag.Creative)
        6 -> exif_tag.ExposureProgram(exif_tag.Action)
        7 -> exif_tag.ExposureProgram(exif_tag.Portrait)
        8 -> exif_tag.ExposureProgram(exif_tag.Landscape)
        _ -> exif_tag.ExposureProgram(exif_tag.InvalidExposureProgram)
      }

    ISO -> exif_tag.ISO(extract_integer_data(entry))

    ExifVersion -> exif_tag.ExifVersion(extract_ascii_data(entry.data))

    DateTimeOriginal ->
      exif_tag.DateTimeOriginal(extract_ascii_data(entry.data))

    CreateDate -> exif_tag.CreateDate(extract_ascii_data(entry.data))

    OffsetTime -> exif_tag.OffsetTime(extract_ascii_data(entry.data))

    OffsetTimeOriginal ->
      exif_tag.OffsetTimeOriginal(extract_ascii_data(entry.data))

    OffsetTimeDigitized ->
      exif_tag.OffsetTimeDigitized(extract_ascii_data(entry.data))

    ComponentsConfiguration ->
      bit_array_to_decimal_list(entry.data)
      |> list.map(fn(v) {
        case v {
          0 -> exif_tag.NA
          1 -> exif_tag.Y
          2 -> exif_tag.Cb
          3 -> exif_tag.Cr
          4 -> exif_tag.R
          5 -> exif_tag.G
          6 -> exif_tag.B
          _ -> exif_tag.InvalidComponentsConfiguration
        }
      })
      |> exif_tag.ComponentsConfiguration

    ShutterSpeedValue ->
      exif_tag.ShutterSpeedValue(extract_signed_rational_to_fraction(entry.data))

    ApertureValue ->
      exif_tag.ApertureValue(extract_unsigned_rational_to_fraction(entry.data))

    BrightnessValue -> {
      let exif_tag.Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data)
      exif_tag.BrightnessValue(
        int.to_float(numerator) /. int.to_float(denominator),
      )
    }

    ExposureCompensation ->
      exif_tag.ExposureCompensation(extract_unsigned_rational_to_fraction(
        entry.data,
      ))

    MeteringMode ->
      {
        case extract_integer_data(entry) {
          0 -> exif_tag.UnknownMeteringMode
          1 -> exif_tag.Average
          2 -> exif_tag.CenterWeightedAverage
          3 -> exif_tag.Spot
          4 -> exif_tag.MultiSpot
          5 -> exif_tag.MultiSegement
          6 -> exif_tag.Partial
          255 -> exif_tag.Other
          _ -> exif_tag.InvalidMeteringMode
        }
      }
      |> exif_tag.MeteringMode

    Flash ->
      bit_array.slice(entry.data, 0, 2)
      |> result.try(dict.get(flash_tag_map(), _))
      |> result.unwrap(exif_tag.InvalidFlash)
      |> exif_tag.Flash

    FocalLength -> {
      let exif_tag.Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data)
      exif_tag.FocalLength(int.to_float(numerator) /. int.to_float(denominator))
    }

    SubjectArea -> {
      extract_unsigned_short_to_int_list(entry.data, entry.component_count, 0)
      |> exif_tag.SubjectArea
    }

    MakerData -> exif_tag.MakerData

    SubSecTimeOriginal ->
      exif_tag.SubSecTimeOriginal(extract_ascii_data(entry.data))

    SubSecTimeDigitized ->
      exif_tag.SubSecTimeDigitized(extract_ascii_data(entry.data))

    FlashpixVersion -> exif_tag.FlashpixVersion(extract_ascii_data(entry.data))

    _ -> {
      exif_tag.Unknown
    }
  }
}

fn bit_array_to_decimal_list(b: BitArray) -> List(Int) {
  case b {
    <<i, rest:bits>> -> {
      [i, ..bit_array_to_decimal_list(rest)]
    }
    _ -> []
  }
}

fn extract_unsigned_short_to_int_list(
  data: BitArray,
  size: Int,
  count: Int,
) -> List(Int) {
  case data {
    <<num:size(16), rest:bits>> if count < size -> {
      [num, ..extract_unsigned_short_to_int_list(rest, size, count + 1)]
    }
    _ -> []
  }
}

fn exif_orientation_map() {
  dict.from_list([
    #(1, exif_tag.Horizontal),
    #(2, exif_tag.MirrorHorizontal),
    #(3, exif_tag.Rotate180),
    #(4, exif_tag.MirrorVertical),
    #(5, exif_tag.MirrorHorizontalAndRotate270CW),
    #(6, exif_tag.Rotate90CW),
    #(7, exif_tag.MirrorHorizontalAndRotate90CW),
    #(8, exif_tag.Rotate270CW),
  ])
}

fn exif_type_map() {
  // lookup map from the decimal value to the type. The type holds the number of bytes per entry
  dict.from_list([
    #(1, UnsignedByte(1)),
    #(2, AsciiString(1)),
    #(3, UnsignedShort(2)),
    #(4, UnsignedLong(4)),
    #(5, UnsignedRational(8)),
    #(6, SignedByte(1)),
    #(7, Undefined(1)),
    #(8, SignedShort(2)),
    #(9, SignedLong(4)),
    #(10, SignedRational(8)),
    #(11, SingleFloat(4)),
    #(12, DoubleFloat(8)),
  ])
}

fn extract_ascii_data(data: BitArray) -> String {
  data
  |> utils.trim_zero_bits
  |> bit_array.to_string
  |> result.unwrap("[[ERROR]]")
}

/// For an unsigned short of length n, turn it into a list of ints
/// Take the bit array types that need to be converted to some sort
/// of decimal and convert them
fn extract_integer_data(exif_entry: RawExifEntry) -> Int {
  case exif_entry.data_type {
    UnsignedShort(size) ->
      bit_array.slice(exif_entry.data, 0, size * exif_entry.component_count)
      |> result.unwrap(<<>>)
      |> utils.bit_array_to_decimal
    UnsignedRational(_) -> {
      let numerator =
        exif_entry.data
        |> bit_array.slice(0, 4)
        |> result.map(utils.bit_array_to_decimal)
        |> result.unwrap(0)
      let denominator =
        exif_entry.data
        |> bit_array.slice(4, 4)
        |> result.map(utils.bit_array_to_decimal)
        |> result.unwrap(0)

      numerator / denominator
    }
    _ -> panic as "unimplemented data type"
  }
}

fn extract_unsigned_rational_to_fraction(data: BitArray) -> exif_tag.Fraction {
  let numerator =
    data
    |> bit_array.slice(0, 4)
    |> result.map(utils.bit_array_to_decimal)
    |> result.unwrap(0)
  let denominator =
    data
    |> bit_array.slice(4, 4)
    |> result.map(utils.bit_array_to_decimal)
    |> result.unwrap(0)

  exif_tag.Fraction(numerator, denominator)
}

fn extract_signed_rational_to_fraction(data: BitArray) -> exif_tag.Fraction {
  let assert Ok(signed) = bit_array.base16_encode(data) |> string.first

  // TODO: I don't remember this stuff anymore! Ugh I feel ashamed
  case signed {
    "0" -> signed
    "1" ->
      todo as "re-learn how the heck to work with signed binary stuff again"
    _ -> panic as "wut?"
  }

  // TODO: For now just treat as unsigned rational since my 
  // test data has this as positive values
  let numerator =
    data
    |> bit_array.slice(0, 4)
    |> result.map(utils.bit_array_to_decimal)
    |> result.unwrap(0)
  let denominator =
    data
    |> bit_array.slice(4, 4)
    |> result.map(utils.bit_array_to_decimal)
    |> result.unwrap(0)

  exif_tag.Fraction(numerator, denominator)
}

fn exif_tag_map() {
  // lookup map from the bit array of the tag to its named type
  dict.from_list([
    #(<<0x01, 0x0f>>, Make),
    #(<<0x01, 0x10>>, Model),
    #(<<0x01, 0x12>>, Orientation),
    #(<<0x01, 0x1a>>, XResolution),
    #(<<0x01, 0x1b>>, YResolution),
    #(<<0x01, 0x28>>, ResolutionUnit),
    #(<<0x01, 0x31>>, Software),
    #(<<0x01, 0x32>>, ModifyDate),
    #(<<0x01, 0x3c>>, HostComputer),
    #(<<0x02, 0x13>>, YCbCrPositioning),
    #(<<0x82, 0x9a>>, ExposureTime),
    #(<<0x82, 0x9d>>, FNumber),
    #(<<0x88, 0x22>>, ExposureProgram),
    #(<<0x88, 0x27>>, ISO),
    #(<<0x90, 0x00>>, ExifVersion),
    #(<<0x90, 0x03>>, DateTimeOriginal),
    #(<<0x90, 0x04>>, CreateDate),
    #(<<0x90, 0x10>>, OffsetTime),
    #(<<0x90, 0x11>>, OffsetTimeOriginal),
    #(<<0x90, 0x12>>, OffsetTimeDigitized),
    #(<<0x91, 0x01>>, ComponentsConfiguration),
    #(<<0x92, 0x01>>, ShutterSpeedValue),
    #(<<0x92, 0x02>>, ApertureValue),
    #(<<0x92, 0x03>>, BrightnessValue),
    #(<<0x92, 0x04>>, ExposureCompensation),
    #(<<0x92, 0x07>>, MeteringMode),
    #(<<0x92, 0x07>>, MeteringMode),
    #(<<0x92, 0x09>>, Flash),
    #(<<0x92, 0x0a>>, FocalLength),
    #(<<0x92, 0x14>>, SubjectArea),
    #(<<0x92, 0x7c>>, MakerData),
    #(<<0x92, 0x91>>, SubSecTimeOriginal),
    #(<<0x92, 0x92>>, SubSecTimeDigitized),
    #(<<0xa0, 0x00>>, FlashpixVersion),
    // Special raw tag to signify an offset to recurse to
    #(<<0x87, 0x69>>, ExifOffset),
  ])
}

fn parse_data_or_offset(
  data_or_offset: BitArray,
  full_segment: BitArray,
  data_type: Result(RawExifType, Nil),
  component_count: Int,
) -> Result(BitArray, Nil) {
  let dt = result.unwrap(data_type, Unknown(0))

  case data_or_offset, dt {
    _, Unknown(_) -> Error(Nil)
    d, _ as t -> {
      let size = t.bytes * component_count
      let offset = utils.bit_array_to_decimal(data_or_offset)
      case t.bytes {
        // data is in the array already
        _bytes if size <= 4 -> Ok(d)
        //otherwise it contains the offset
        _ -> bit_array.slice(full_segment, offset, size)
      }
    }
  }
}

fn flash_tag_map() {
  dict.from_list([
    #(<<0x00, 0x00>>, exif_tag.NoFlash),
    #(<<0x00, 0x01>>, exif_tag.Fired),
    #(<<0x00, 0x05>>, exif_tag.FiredReturnNotDetected),
    #(<<0x00, 0x07>>, exif_tag.FiredReturnDetected),
    #(<<0x00, 0x08>>, exif_tag.OnDidNotFire),
    #(<<0x00, 0x09>>, exif_tag.OnFired),
    #(<<0x00, 0x0d>>, exif_tag.OnReturnNotDetected),
    #(<<0x00, 0x0f>>, exif_tag.OnReturnDetected),
    #(<<0x00, 0x10>>, exif_tag.OffDidNotFire),
    #(<<0x00, 0x14>>, exif_tag.OffDidNotFireReturnNotDetected),
    #(<<0x00, 0x18>>, exif_tag.AutoDidNotFire),
    #(<<0x00, 0x19>>, exif_tag.AutoFired),
    #(<<0x00, 0x1d>>, exif_tag.AutoFiredReturnNotDetected),
    #(<<0x00, 0x1f>>, exif_tag.AutoFiredReturnDetected),
    #(<<0x00, 0x20>>, exif_tag.NoFlashFunction),
    #(<<0x00, 0x30>>, exif_tag.OffNoFlashFunction),
    #(<<0x00, 0x41>>, exif_tag.FiredRedEyeReduction),
    #(<<0x00, 0x45>>, exif_tag.FiredRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x47>>, exif_tag.FiredRedEyeReductionReturnDetected),
    #(<<0x00, 0x49>>, exif_tag.OnRedEyeReduction),
    #(<<0x00, 0x4d>>, exif_tag.OnRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x4f>>, exif_tag.OnRedEyeReductionReturnDetected),
    #(<<0x00, 0x50>>, exif_tag.OffRedEyeReduction),
    #(<<0x00, 0x58>>, exif_tag.AutoDidNotFireRedEyeReduction),
    #(<<0x00, 0x59>>, exif_tag.AutoFiredRedEyeReduction),
    #(<<0x00, 0x5d>>, exif_tag.AutoFiredRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x5f>>, exif_tag.AutoFiredRedEyeReductionReturnDetected),
  ])
}
