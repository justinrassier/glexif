import file_streams/read_stream.{type ReadStream}
import file_streams/read_stream_error.{type ReadStreamError}
import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import glexif/exif_tag
import glexif/exif_tags/color_space
import glexif/exif_tags/components_configuration
import glexif/exif_tags/composite_image
import glexif/exif_tags/exposure_mode
import glexif/exif_tags/exposure_program
import glexif/exif_tags/flash
import glexif/exif_tags/gps_altitude_ref
import glexif/exif_tags/metering_mode
import glexif/exif_tags/orientation
import glexif/exif_tags/resolution_unit
import glexif/exif_tags/scene_capture_type
import glexif/exif_tags/scene_type
import glexif/exif_tags/sensing_method
import glexif/exif_tags/white_balance
import glexif/exif_tags/y_cb_cr_positioning

import glexif/internal/utils
import glexif/units/fraction.{type Fraction, Fraction}
import glexif/units/gps_coordinates.{
  type GPSCoordinates, GPSCoordinates, InvalidGPSCoordinates,
}

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
  ColorSpace
  ExifImageWidth
  ExifImageHeight
  SensingMethod
  SceneType
  ExposureMode
  WhiteBalance
  FocalLengthIn35mmFormat
  SceneCaptureType
  LensInfo
  LensMake
  LensModel
  CompositeImage
  GPSLatitudeRef
  GPSLatitude
  GPSLongitudeRef
  GPSLongitude
  GPSAltitudeRef
  GPSAltitude

  GPSLink(Int)
  IFDLink(Int)
  // No more offset. End of everything
  EndOfIFD
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
      case tiff_header {
        Intel(_) -> panic as "Unimplemented parsing for Intel header"
        Motorola(_) -> {
          Ok(ExifSegment(
            size: exif_full_size,
            exif_header: <<69, 120, 105, 102, 0, 0>>,
            tiff_header: tiff_header,
            raw_data: raw_data,
          ))
        }
      }
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

pub fn parse_exif_data_as_record(
  exif_segment: ExifSegment,
) -> exif_tag.ExifTagRecord {
  // entries are 12 bytes long. They start at an offset of 8, but including the "MM" header bytes means we start at 10
  let entry_count =
    bit_array.slice(exif_segment.raw_data, 8, 2)
    |> result.unwrap(<<0, 0>>)
    |> utils.bit_array_to_decimal

  get_raw_entries(exif_segment.raw_data, 10, entry_count, 1, IFD)
  |> list.fold(exif_tag.new(), fn(record, tag) {
    raw_exif_entry_to_parsed_tag(record, tag)
  })
}

pub fn get_raw_entries(
  segment_bytes: BitArray,
  start: Int,
  total_segment_count: Int,
  current_entry: Int,
  offset_location: OffsetLocation,
) -> List(RawExifEntry) {
  let entry_bits = bit_array.slice(segment_bytes, start, 12)

  let tag =
    parse_raw_exif_tag(
      entry_bits,
      current_entry,
      total_segment_count,
      offset_location,
    )

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
        get_raw_entries(segment_bytes, offset + 2, entry_count, 1, IFD),
        // continue recursing the current segment
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
          offset_location,
        ),
      )
    }
    // link off to the next IFD
    IFDLink(offset), _, _, _ -> {
      let entry_count =
        bit_array.slice(segment_bytes, offset, 2)
        |> result.unwrap(<<0, 0>>)
        |> utils.bit_array_to_decimal
      list.append(
        get_raw_entries(segment_bytes, offset + 2, entry_count, 1, IFD),
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
          offset_location,
        ),
      )
    }
    GPSLink(offset), _, _, _ -> {
      let entry_count =
        bit_array.slice(segment_bytes, offset, 2)
        |> result.unwrap(<<0, 0>>)
        |> utils.bit_array_to_decimal

      list.append(
        get_raw_entries(segment_bytes, offset + 2, entry_count, 1, GPS),
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
          offset_location,
        ),
      )
    }
    t, Ok(data_type), Ok(component_count), Ok(data)
      if current_entry <= total_segment_count
    -> {
      let base_element = [
        RawExifEntry(
          tag: t,
          data_type: data_type,
          component_count: component_count,
          data: data,
        ),
      ]
      list.append(
        base_element,
        get_raw_entries(
          segment_bytes,
          start + 12,
          total_segment_count,
          current_entry + 1,
          offset_location,
        ),
      )
    }
    _, _, _, _ -> {
      []
    }
  }
}

/// Takes the entry and tries to map it to a known RawExifTag
fn parse_raw_exif_tag(
  entry: Result(BitArray, Nil),
  current_entry_count: Int,
  total_segment_count: Int,
  offset_location: OffsetLocation,
) -> RawExifTag {
  // the one segment past the last segment is either offset to a new link or the end of things
  let end_or_offset_index = total_segment_count + 1
  entry
  |> result.try(bit_array.slice(_, 0, 2))
  |> result.try(dict.get(exif_tag_map(offset_location), _))
  |> result.try_recover(fn(_) {
    case entry {
      Ok(<<0x88, 0x25, 0, 4, 0, 0, 0, 1, rest:bits>>) -> {
        Ok(GPSLink(utils.bit_array_to_decimal(rest)))
      }
      _ -> Error(Nil)
    }
  })
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
pub fn raw_exif_entry_to_parsed_tag(
  record: exif_tag.ExifTagRecord,
  entry: RawExifEntry,
) -> exif_tag.ExifTagRecord {
  case entry.tag {
    Make -> {
      let make =
        entry.data
        |> extract_ascii_data
        |> Some

      exif_tag.ExifTagRecord(..record, make: make)
    }

    Model -> {
      let model =
        entry.data
        |> extract_ascii_data
        |> Some
      exif_tag.ExifTagRecord(..record, model: model)
    }
    Orientation -> {
      let orientation =
        entry
        |> extract_integer_data
        |> dict.get(exif_orientation_map(), _)
        |> result.unwrap(orientation.InvalidOrientation)
        |> Some

      exif_tag.ExifTagRecord(..record, orientation: orientation)
    }
    XResolution ->
      exif_tag.ExifTagRecord(
        ..record,
        x_resolution: Some(extract_integer_data(entry)),
      )
    YResolution ->
      exif_tag.ExifTagRecord(
        ..record,
        y_resolution: Some(extract_integer_data(entry)),
      )
    ResolutionUnit -> {
      let unit = case extract_integer_data(entry) {
        1 -> resolution_unit.NoResolutionTagUnit
        2 -> resolution_unit.Inches
        3 -> resolution_unit.Centimeters
        _ -> resolution_unit.InvalidResolutionUnit
      }

      exif_tag.ExifTagRecord(..record, resolution_unit: Some(unit))
    }
    Software -> {
      let software =
        entry.data
        |> extract_ascii_data
        |> Some
      exif_tag.ExifTagRecord(..record, software: software)
    }
    ModifyDate -> {
      let date =
        entry.data
        |> extract_ascii_data
        |> Some

      exif_tag.ExifTagRecord(..record, modify_date: date)
    }

    HostComputer -> {
      let host_computer =
        entry.data
        |> extract_ascii_data
        |> Some

      exif_tag.ExifTagRecord(..record, host_computer: host_computer)
    }

    YCbCrPositioning -> {
      let positioning = case extract_integer_data(entry) {
        1 -> y_cb_cr_positioning.Centered
        2 -> y_cb_cr_positioning.CoSited
        _ -> y_cb_cr_positioning.InvalidYCbCrPositioning
      }
      exif_tag.ExifTagRecord(..record, y_cb_cr_positioning: Some(positioning))
    }
    ExposureTime -> {
      let exposure_time = extract_unsigned_rational_to_fraction(entry.data)
      exif_tag.ExifTagRecord(..record, exposure_time: Some(exposure_time))
    }

    FNumber -> {
      let f_number = extract_unsigned_rational_to_fraction(entry.data)
      exif_tag.ExifTagRecord(..record, f_number: Some(f_number))
    }
    ExposureProgram -> {
      let exposure_program = case extract_integer_data(entry) {
        0 -> exposure_program.NotDefined
        1 -> exposure_program.Manual
        2 -> exposure_program.ProgramAE
        3 -> exposure_program.AperturePriorityAE
        4 -> exposure_program.ShutterSpeedPriorityAE
        5 -> exposure_program.Creative
        6 -> exposure_program.Action
        7 -> exposure_program.Portrait
        8 -> exposure_program.Landscape
        _ -> exposure_program.InvalidExposureProgram
      }
      exif_tag.ExifTagRecord(..record, exposure_program: Some(exposure_program))
    }

    ISO -> {
      let iso = extract_integer_data(entry)
      exif_tag.ExifTagRecord(..record, iso: Some(iso))
    }

    ExifVersion -> {
      let exif_version = extract_ascii_data(entry.data) |> Some
      exif_tag.ExifTagRecord(..record, exif_version: exif_version)
    }

    DateTimeOriginal -> {
      let date_time_original = extract_ascii_data(entry.data) |> Some

      exif_tag.ExifTagRecord(..record, date_time_original: date_time_original)
    }

    CreateDate -> {
      let create_date = extract_ascii_data(entry.data) |> Some

      exif_tag.ExifTagRecord(..record, create_date: create_date)
    }

    OffsetTime -> {
      let offset_time = extract_ascii_data(entry.data) |> Some

      exif_tag.ExifTagRecord(..record, offset_time: offset_time)
    }

    OffsetTimeOriginal -> {
      let offset_time_original = extract_ascii_data(entry.data) |> Some

      exif_tag.ExifTagRecord(
        ..record,
        offset_time_original: offset_time_original,
      )
    }

    OffsetTimeDigitized -> {
      let offset_time_digitized = extract_ascii_data(entry.data) |> Some

      exif_tag.ExifTagRecord(
        ..record,
        offset_time_digitized: offset_time_digitized,
      )
    }

    ComponentsConfiguration -> {
      let components_configuration =
        bit_array_to_decimal_list(entry.data)
        |> list.map(fn(v) {
          case v {
            0 -> components_configuration.NA
            1 -> components_configuration.Y
            2 -> components_configuration.Cb
            3 -> components_configuration.Cr
            4 -> components_configuration.R
            5 -> components_configuration.G
            6 -> components_configuration.B
            _ -> components_configuration.InvalidComponentsConfiguration
          }
        })
      exif_tag.ExifTagRecord(
        ..record,
        components_configuration: Some(components_configuration),
      )
    }

    ShutterSpeedValue -> {
      let shutter_speed_value = extract_signed_rational_to_fraction(entry.data)

      exif_tag.ExifTagRecord(
        ..record,
        shutter_speed_value: Some(shutter_speed_value),
      )
    }
    ApertureValue -> {
      let aperature_value = extract_signed_rational_to_fraction(entry.data)

      exif_tag.ExifTagRecord(..record, aperature_value: Some(aperature_value))
    }

    BrightnessValue -> {
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data)
      let brightness_value =
        int.to_float(numerator) /. int.to_float(denominator)

      exif_tag.ExifTagRecord(..record, brightness_value: Some(brightness_value))
    }

    ExposureCompensation -> {
      let exposure_compensation =
        extract_unsigned_rational_to_fraction(entry.data)
      exif_tag.ExifTagRecord(
        ..record,
        exposure_compensation: Some(exposure_compensation),
      )
    }
    //
    MeteringMode -> {
      let metering_mode = case extract_integer_data(entry) {
        0 -> metering_mode.UnknownMeteringMode
        1 -> metering_mode.Average
        2 -> metering_mode.CenterWeightedAverage
        3 -> metering_mode.Spot
        4 -> metering_mode.MultiSpot
        5 -> metering_mode.MultiSegement
        6 -> metering_mode.Partial
        255 -> metering_mode.Other
        _ -> metering_mode.InvalidMeteringMode
      }
      exif_tag.ExifTagRecord(..record, metering_mode: Some(metering_mode))
    }
    //
    Flash -> {
      let flash =
        bit_array.slice(entry.data, 0, 2)
        |> result.try(dict.get(flash_tag_map(), _))
        |> result.unwrap(flash.InvalidFlash)

      exif_tag.ExifTagRecord(..record, flash: Some(flash))
    }

    FocalLength -> {
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data)

      let focal_length = int.to_float(numerator) /. int.to_float(denominator)

      exif_tag.ExifTagRecord(..record, focal_length: Some(focal_length))
    }

    SubjectArea -> {
      let subject_area =
        extract_unsigned_short_to_int_list(entry.data, entry.component_count, 0)

      exif_tag.ExifTagRecord(..record, subject_area: Some(subject_area))
    }

    MakerData ->
      exif_tag.ExifTagRecord(..record, maker_data: Some(exif_tag.TBD))

    SubSecTimeOriginal -> {
      let sub_sec_time_original = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(
        ..record,
        sub_sec_time_original: Some(sub_sec_time_original),
      )
    }

    SubSecTimeDigitized -> {
      let sub_sec_time_digitized = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(
        ..record,
        sub_sec_time_digitized: Some(sub_sec_time_digitized),
      )
    }

    FlashpixVersion -> {
      let flash_pix_version = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(
        ..record,
        flash_pix_version: Some(flash_pix_version),
      )
    }

    ColorSpace -> {
      let color_space = case bit_array.slice(entry.data, 0, 2) {
        Ok(<<0x00, 0x01>>) -> color_space.SRGB
        Ok(<<0x00, 0x02>>) -> color_space.AdobeRGB
        Ok(<<0xff, 0xfd>>) -> color_space.ICCProfile
        Ok(<<0xff, 0xff>>) -> color_space.Uncalibrated
        _ -> color_space.InvalidColorSpace
      }
      exif_tag.ExifTagRecord(..record, color_space: Some(color_space))
    }

    ExifImageWidth -> {
      let exif_image_width =
        entry
        |> extract_integer_data
        |> Some
      exif_tag.ExifTagRecord(..record, exif_image_width: exif_image_width)
    }

    ExifImageHeight -> {
      let exif_image_height =
        entry
        |> extract_integer_data
        |> Some
      exif_tag.ExifTagRecord(..record, exif_image_height: exif_image_height)
    }

    SensingMethod -> {
      let int_value =
        entry
        |> extract_integer_data

      let sensing_method = case int_value {
        1 -> sensing_method.SensingMethodNotDefined
        2 -> sensing_method.OneChipColorArea
        3 -> sensing_method.TwoChipColorArea
        4 -> sensing_method.ThreeChipColorArea
        5 -> sensing_method.ColorSequentialArea
        7 -> sensing_method.Trilinear
        8 -> sensing_method.ColorSequentialLinear
        _ -> sensing_method.InvalidSensingMethod
      }
      exif_tag.ExifTagRecord(..record, sensing_method: Some(sensing_method))
    }

    SceneType -> {
      exif_tag.ExifTagRecord(
        ..record,
        scene_type: Some(scene_type.DirectlyPhotographed),
      )
    }
    ExposureMode -> {
      let int_value =
        entry
        |> extract_integer_data
      let exposure_mode = case int_value {
        0 -> exposure_mode.Auto
        1 -> exposure_mode.Manual
        2 -> exposure_mode.AutoBracket
        _ -> exposure_mode.InvalidExposureMode
      }
      exif_tag.ExifTagRecord(..record, exposure_mode: Some(exposure_mode))
    }
    WhiteBalance -> {
      let int_value =
        entry
        |> extract_integer_data
      let white_balance = case int_value {
        0 -> white_balance.Auto
        1 -> white_balance.Manual
        _ -> white_balance.InvalidWhiteBalance
      }
      exif_tag.ExifTagRecord(..record, white_balance: Some(white_balance))
    }
    FocalLengthIn35mmFormat -> {
      let int_value =
        entry
        |> extract_integer_data
        |> Some
      exif_tag.ExifTagRecord(..record, focal_length_in_35_mm_format: int_value)
    }
    SceneCaptureType -> {
      let int_value =
        entry
        |> extract_integer_data
      let scene_capture_type = case int_value {
        0 -> scene_capture_type.Standard
        1 -> scene_capture_type.Landscape
        2 -> scene_capture_type.Portrait
        3 -> scene_capture_type.Night
        4 -> scene_capture_type.Other
        _ -> scene_capture_type.InvalidSceneCaptureType
      }
      exif_tag.ExifTagRecord(
        ..record,
        scene_capture_type: Some(scene_capture_type),
      )
    }
    LensInfo -> {
      let fraction_list = bit_array_to_fraction_list(entry.data)

      exif_tag.ExifTagRecord(..record, lens_info: Some(fraction_list))
    }
    LensMake -> {
      let lens_make = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(..record, lens_make: Some(lens_make))
    }
    LensModel -> {
      let lens_model = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(..record, lens_model: Some(lens_model))
    }
    CompositeImage -> {
      let int_value = extract_integer_data(entry)
      let composite_image = case int_value {
        0 -> composite_image.Unknown
        1 -> composite_image.NotACompositeImage
        2 -> composite_image.GeneralCompositeImage
        3 -> composite_image.CompositeImageCapturedWhileShooting
        _ -> composite_image.InvalidCompositeImage
      }

      exif_tag.ExifTagRecord(..record, composite_image: Some(composite_image))
    }
    GPSLatitudeRef -> {
      let gps_latitude_ref = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(..record, gps_latitude_ref: Some(gps_latitude_ref))
    }
    GPSLatitude -> {
      let fraction_list = bit_array_to_fraction_list(entry.data)
      let gps_coordinates = case fraction_list {
        [
          Fraction(degrees_numerator, degrees_denominator),
          Fraction(minutes_numerator, minutes_denominator),
          Fraction(seconds_numerator, seconds_denominator),
        ] -> {
          GPSCoordinates(
            degrees: degrees_numerator / degrees_denominator,
            minutes: minutes_numerator / minutes_denominator,
            seconds: int.to_float(seconds_numerator)
              /. int.to_float(seconds_denominator),
          )
        }
        _ -> {
          InvalidGPSCoordinates
        }
      }
      exif_tag.ExifTagRecord(..record, gps_latitude: Some(gps_coordinates))
    }
    GPSLongitudeRef -> {
      let gps_longitude_ref = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(
        ..record,
        gps_longitude_ref: Some(gps_longitude_ref),
      )
    }
    GPSLongitude -> {
      let fraction_list = bit_array_to_fraction_list(entry.data)
      let gps_coordinates = case fraction_list {
        [
          Fraction(degrees_numerator, degrees_denominator),
          Fraction(minutes_numerator, minutes_denominator),
          Fraction(seconds_numerator, seconds_denominator),
        ] -> {
          GPSCoordinates(
            degrees: degrees_numerator / degrees_denominator,
            minutes: minutes_numerator / minutes_denominator,
            seconds: int.to_float(seconds_numerator)
              /. int.to_float(seconds_denominator),
          )
        }
        _ -> {
          InvalidGPSCoordinates
        }
      }
      exif_tag.ExifTagRecord(..record, gps_longitude: Some(gps_coordinates))
    }
    GPSAltitudeRef -> {
      let altitude_ref = case entry.data {
        <<val, _rest:bits>> -> {
          case val {
            0 -> gps_altitude_ref.AboveSeaLevel
            1 -> gps_altitude_ref.BelowSeaLevel
            _ -> gps_altitude_ref.InvalidGPSAltitudeRef
          }
        }
        _ -> gps_altitude_ref.InvalidGPSAltitudeRef
      }

      exif_tag.ExifTagRecord(..record, gps_altitude_ref: Some(altitude_ref))
    }
    GPSAltitude -> {
      let gps_altitude_fraction =
        extract_unsigned_rational_to_fraction(entry.data)
      let gps_altitude_float = case gps_altitude_fraction {
        Fraction(numerator, denominator) ->
          int.to_float(numerator) /. int.to_float(denominator)
      }

      exif_tag.ExifTagRecord(..record, gps_altitude: Some(gps_altitude_float))
    }

    u -> {
      io.debug(u)
      record
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

fn bit_array_to_fraction_list(b: BitArray) -> List(Fraction) {
  case b {
    <<numerator:size(32), denominator:size(32), rest:bits>> -> {
      [Fraction(numerator, denominator), ..bit_array_to_fraction_list(rest)]
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
    #(1, orientation.Horizontal),
    #(2, orientation.MirrorHorizontal),
    #(3, orientation.Rotate180),
    #(4, orientation.MirrorVertical),
    #(5, orientation.MirrorHorizontalAndRotate270CW),
    #(6, orientation.Rotate90CW),
    #(7, orientation.MirrorHorizontalAndRotate90CW),
    #(8, orientation.Rotate270CW),
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
    UnsignedLong(size) ->
      bit_array.slice(exif_entry.data, 0, size * exif_entry.component_count)
      |> result.unwrap(<<>>)
      |> utils.bit_array_to_decimal
    _ -> panic as "unimplemented data type"
  }
}

fn extract_unsigned_rational_to_fraction(data: BitArray) -> Fraction {
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

  Fraction(numerator, denominator)
}

fn extract_signed_rational_to_fraction(data: BitArray) -> Fraction {
  let assert Ok(signed) = bit_array.base16_encode(data) |> string.first

  // TODO: I don't remember this stuff anymore! Ugh I feel ashamed
  case signed {
    "0" -> signed
    "1" ->
      panic as "re-learn how the heck to work with signed binary stuff again"
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

  Fraction(numerator, denominator)
}

type OffsetLocation {
  IFD
  // regular
  GPS
}

fn exif_tag_map(offset_location: OffsetLocation) {
  case offset_location {
    IFD ->
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
        #(<<0xa0, 0x01>>, ColorSpace),
        #(<<0xa0, 0x02>>, ExifImageWidth),
        #(<<0xa0, 0x03>>, ExifImageHeight),
        #(<<0xa2, 0x17>>, SensingMethod),
        #(<<0xa3, 0x01>>, SceneType),
        #(<<0xa4, 0x02>>, ExposureMode),
        #(<<0xa4, 0x03>>, WhiteBalance),
        #(<<0xa4, 0x05>>, FocalLengthIn35mmFormat),
        #(<<0xa4, 0x06>>, SceneCaptureType),
        #(<<0xa4, 0x32>>, LensInfo),
        #(<<0xa4, 0x33>>, LensMake),
        #(<<0xa4, 0x34>>, LensModel),
        #(<<0xa4, 0x60>>, CompositeImage),
        // Special raw tag to signify an offset to recurse to
        #(<<0x87, 0x69>>, ExifOffset),
      ])
    GPS ->
      dict.from_list([
        #(<<0x00, 0x01>>, GPSLatitudeRef),
        #(<<0x00, 0x02>>, GPSLatitude),
        #(<<0x00, 0x03>>, GPSLongitudeRef),
        #(<<0x00, 0x04>>, GPSLongitude),
        #(<<0x00, 0x05>>, GPSAltitudeRef),
        #(<<0x00, 0x06>>, GPSAltitude),
      ])
  }
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
    #(<<0x00, 0x00>>, flash.NoFlash),
    #(<<0x00, 0x01>>, flash.Fired),
    #(<<0x00, 0x05>>, flash.FiredReturnNotDetected),
    #(<<0x00, 0x07>>, flash.FiredReturnDetected),
    #(<<0x00, 0x08>>, flash.OnDidNotFire),
    #(<<0x00, 0x09>>, flash.OnFired),
    #(<<0x00, 0x0d>>, flash.OnReturnNotDetected),
    #(<<0x00, 0x0f>>, flash.OnReturnDetected),
    #(<<0x00, 0x10>>, flash.OffDidNotFire),
    #(<<0x00, 0x14>>, flash.OffDidNotFireReturnNotDetected),
    #(<<0x00, 0x18>>, flash.AutoDidNotFire),
    #(<<0x00, 0x19>>, flash.AutoFired),
    #(<<0x00, 0x1d>>, flash.AutoFiredReturnNotDetected),
    #(<<0x00, 0x1f>>, flash.AutoFiredReturnDetected),
    #(<<0x00, 0x20>>, flash.NoFlashFunction),
    #(<<0x00, 0x30>>, flash.OffNoFlashFunction),
    #(<<0x00, 0x41>>, flash.FiredRedEyeReduction),
    #(<<0x00, 0x45>>, flash.FiredRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x47>>, flash.FiredRedEyeReductionReturnDetected),
    #(<<0x00, 0x49>>, flash.OnRedEyeReduction),
    #(<<0x00, 0x4d>>, flash.OnRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x4f>>, flash.OnRedEyeReductionReturnDetected),
    #(<<0x00, 0x50>>, flash.OffRedEyeReduction),
    #(<<0x00, 0x58>>, flash.AutoDidNotFireRedEyeReduction),
    #(<<0x00, 0x59>>, flash.AutoFiredRedEyeReduction),
    #(<<0x00, 0x5d>>, flash.AutoFiredRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x5f>>, flash.AutoFiredRedEyeReductionReturnDetected),
  ])
}
