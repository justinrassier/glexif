import file_streams/file_stream
import file_streams/file_stream_error
import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
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
import glexif/exif_tags/gps_speed_ref
import glexif/exif_tags/metering_mode
import glexif/exif_tags/orientation
import glexif/exif_tags/resolution_unit
import glexif/exif_tags/scene_capture_type
import glexif/exif_tags/scene_type
import glexif/exif_tags/sensing_method
import glexif/exif_tags/white_balance
import glexif/exif_tags/y_cb_cr_positioning
import glexif/internal/flash as internal_flash
import glexif/internal/orientation as internal_orientation

import glexif/internal/utils
import glexif/units/fraction.{type Fraction, Fraction}
import glexif/units/gps_coordinates.{GPSCoordinates, InvalidGPSCoordinates}

pub type ExifParseError {
  StreamReadError(error: file_stream_error.FileStreamError)
  ExifMarkerNotFound
  UnexpectedEndOfFile
  InvalidJpegHeader
  InvalidSegmentSize(size: Int)
  InvalidExifHeader
  InvalidTiffHeader
  InvalidEntry(offset: Int)
  InvalidOffset(offset: Int)
  OffsetCycle(offset: Int)
  TraversalLimitExceeded
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
  ImageDescription
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
  GPSTimestamp
  GPSSpeedRef
  GPSSpeed

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

/// Read the first standard EXIF APP1 segment from a JPEG stream.
pub fn read_exif_segment(
  stream: file_stream.FileStream,
) -> Result(ExifSegment, ExifParseError) {
  use soi <- result.try(read_exact(stream, 2))
  case soi {
    <<0xff, 0xd8>> -> find_exif_segment(stream)
    _ -> Error(InvalidJpegHeader)
  }
}

fn find_exif_segment(
  stream: file_stream.FileStream,
) -> Result(ExifSegment, ExifParseError) {
  use marker <- result.try(read_marker(stream))
  case marker {
    // EXIF cannot appear after image data begins.
    0xd9 | 0xda -> Error(ExifMarkerNotFound)
    // Standalone markers do not have a size field.
    marker if marker == 0x01 || marker >= 0xd0 && marker <= 0xd7 ->
      find_exif_segment(stream)
    0xd8 -> Error(InvalidJpegHeader)
    marker -> {
      use size_bytes <- result.try(read_exact(stream, 2))
      let size = case size_bytes {
        <<value:big-unsigned-size(16)>> -> value
        _ -> 0
      }
      use _ <- result.try(case size >= 2 {
        True -> Ok(Nil)
        False -> Error(InvalidSegmentSize(size))
      })
      use payload <- result.try(read_exact(stream, size - 2))

      case marker, payload {
        // The `Exif` identifier makes this the EXIF segment even when its
        // required NUL terminator is malformed.
        0xe1, <<0x45, 0x78, 0x69, 0x66, _rest:bits>> ->
          parse_exif_segment(payload, size)
        _, _ -> find_exif_segment(stream)
      }
    }
  }
}

fn read_marker(stream: file_stream.FileStream) -> Result(Int, ExifParseError) {
  use prefix <- result.try(read_exact(stream, 1))
  case prefix {
    <<0xff>> -> read_marker_code(stream)
    _ -> Error(InvalidJpegHeader)
  }
}

fn read_marker_code(
  stream: file_stream.FileStream,
) -> Result(Int, ExifParseError) {
  use byte <- result.try(read_exact(stream, 1))
  case byte {
    // JPEG permits fill bytes between segments.
    <<0xff>> -> read_marker_code(stream)
    <<0x00>> -> Error(InvalidJpegHeader)
    <<marker>> -> Ok(marker)
    _ -> Error(InvalidJpegHeader)
  }
}

fn read_exact(
  stream: file_stream.FileStream,
  count: Int,
) -> Result(BitArray, ExifParseError) {
  case file_stream.read_bytes_exact(stream, count) {
    Ok(bytes) -> Ok(bytes)
    Error(file_stream_error.Eof) -> Error(UnexpectedEndOfFile)
    Error(error) -> Error(StreamReadError(error))
  }
}

fn parse_exif_segment(
  payload: BitArray,
  size: Int,
) -> Result(ExifSegment, ExifParseError) {
  case payload {
    <<0x45, 0x78, 0x69, 0x66, 0, 0, raw_data:bits>> -> {
      use header_bytes <- result.try(
        bit_array.slice(raw_data, 0, 8)
        |> result.replace_error(InvalidTiffHeader),
      )
      use tiff_header <- result.try(get_tiff_header(header_bytes))
      Ok(ExifSegment(
        size: size,
        exif_header: <<0x45, 0x78, 0x69, 0x66, 0, 0>>,
        tiff_header: tiff_header,
        raw_data: raw_data,
      ))
    }
    _ -> Error(InvalidExifHeader)
  }
}

fn get_tiff_header(
  header_bytes: BitArray,
) -> Result(TiffHeader, ExifParseError) {
  case header_bytes {
    <<0x4d, 0x4d, 0, 42, _offset:big-unsigned-size(32)>> ->
      Ok(Motorola(header_bytes))
    <<0x49, 0x49, 42, 0, _offset:little-unsigned-size(32)>> ->
      Ok(Intel(header_bytes))
    _ -> Error(InvalidTiffHeader)
  }
}

type ParseTask {
  ParseIfd(offset: Int, location: OffsetLocation)
  ParseEntry(ifd_offset: Int, location: OffsetLocation, index: Int, count: Int)
}

type ParsedIfdEntry {
  ParsedEntry(entry: RawExifEntry)
  LinkedIfd(offset: Int, location: OffsetLocation)
  SkippedEntry
}

pub fn parse_exif_data_as_record(
  exif_segment: ExifSegment,
) -> Result(exif_tag.ExifTagRecord, ExifParseError) {
  use first_ifd_offset <- result.try(read_u32(
    exif_segment.raw_data,
    4,
    exif_segment.tiff_header,
    InvalidTiffHeader,
  ))
  use entries <- result.try(walk_ifds(
    exif_segment.raw_data,
    exif_segment.tiff_header,
    [ParseIfd(first_ifd_offset, IFD)],
    dict.new(),
    [],
    bit_array.byte_size(exif_segment.raw_data) * 2,
  ))

  Ok(
    list.fold(entries, exif_tag.new(), fn(record, entry) {
      raw_exif_entry_to_parsed_tag(record, entry, exif_segment.tiff_header)
    }),
  )
}

fn walk_ifds(
  data: BitArray,
  header: TiffHeader,
  tasks: List(ParseTask),
  visited: dict.Dict(Int, Bool),
  entries: List(RawExifEntry),
  budget: Int,
) -> Result(List(RawExifEntry), ExifParseError) {
  case tasks, budget {
    [], _ -> Ok(list.reverse(entries))
    _, budget if budget <= 0 -> Error(TraversalLimitExceeded)
    [ParseIfd(offset, location), ..rest], _ -> {
      use _ <- result.try(validate_ifd_offset(data, offset))
      use _ <- result.try(case dict.has_key(visited, offset) {
        True -> Error(OffsetCycle(offset))
        False -> Ok(Nil)
      })
      use count <- result.try(read_u16(
        data,
        offset,
        header,
        InvalidEntry(offset),
      ))
      let table_size = 2 + count * 12 + 4
      use _ <- result.try(checked_slice(
        data,
        offset,
        table_size,
        InvalidEntry(offset),
      ))
      walk_ifds(
        data,
        header,
        [ParseEntry(offset, location, 0, count), ..rest],
        dict.insert(visited, offset, True),
        entries,
        budget - 1,
      )
    }
    [ParseEntry(ifd_offset, location, index, count), ..rest], _
      if index < count
    -> {
      let entry_offset = ifd_offset + 2 + index * 12
      use parsed <- result.try(parse_ifd_entry(
        data,
        entry_offset,
        location,
        header,
      ))
      let continuation = ParseEntry(ifd_offset, location, index + 1, count)
      case parsed {
        ParsedEntry(entry) ->
          walk_ifds(
            data,
            header,
            [continuation, ..rest],
            visited,
            [entry, ..entries],
            budget - 1,
          )
        LinkedIfd(offset, linked_location) ->
          walk_ifds(
            data,
            header,
            [ParseIfd(offset, linked_location), continuation, ..rest],
            visited,
            entries,
            budget - 1,
          )
        SkippedEntry ->
          walk_ifds(
            data,
            header,
            [continuation, ..rest],
            visited,
            entries,
            budget - 1,
          )
      }
    }
    [ParseEntry(ifd_offset, _, _, count), ..rest], _ -> {
      let next_offset_location = ifd_offset + 2 + count * 12
      use next_offset <- result.try(read_u32(
        data,
        next_offset_location,
        header,
        InvalidEntry(next_offset_location),
      ))
      let tasks = case next_offset {
        0 -> rest
        offset -> [ParseIfd(offset, IFD), ..rest]
      }
      walk_ifds(data, header, tasks, visited, entries, budget - 1)
    }
  }
}

fn validate_ifd_offset(
  data: BitArray,
  offset: Int,
) -> Result(Nil, ExifParseError) {
  case offset >= 8 && offset + 2 <= bit_array.byte_size(data) {
    True -> Ok(Nil)
    False -> Error(InvalidOffset(offset))
  }
}

fn parse_ifd_entry(
  data: BitArray,
  offset: Int,
  location: OffsetLocation,
  header: TiffHeader,
) -> Result(ParsedIfdEntry, ExifParseError) {
  use entry <- result.try(checked_slice(data, offset, 12, InvalidEntry(offset)))
  use tag_id <- result.try(read_u16(entry, 0, header, InvalidEntry(offset)))
  use type_id <- result.try(read_u16(entry, 2, header, InvalidEntry(offset)))
  use component_count <- result.try(read_u32(
    entry,
    4,
    header,
    InvalidEntry(offset),
  ))

  case location, tag_id {
    IFD, 0x8769 ->
      parse_link(entry, type_id, component_count, IFD, header, offset)
    IFD, 0x8825 ->
      parse_link(entry, type_id, component_count, GPS, header, offset)
    _, _ -> {
      let tag = parse_raw_exif_tag(tag_id, location)
      case tag, dict.get(exif_type_map(), type_id) {
        UnknownExifTag(_), _ | _, Error(_) -> Ok(SkippedEntry)
        _, Ok(data_type) -> {
          case
            parse_data_or_offset(
              entry,
              data,
              data_type,
              component_count,
              header,
            )
          {
            Ok(value) ->
              Ok(
                ParsedEntry(RawExifEntry(
                  tag: tag,
                  data_type: data_type,
                  component_count: component_count,
                  data: value,
                )),
              )
            // A malformed optional value does not discard other valid tags.
            Error(_) -> Ok(SkippedEntry)
          }
        }
      }
    }
  }
}

fn parse_link(
  entry: BitArray,
  type_id: Int,
  component_count: Int,
  location: OffsetLocation,
  header: TiffHeader,
  entry_offset: Int,
) -> Result(ParsedIfdEntry, ExifParseError) {
  use _ <- result.try(case type_id == 4 && component_count == 1 {
    True -> Ok(Nil)
    False -> Error(InvalidEntry(entry_offset))
  })
  use offset <- result.try(read_u32(
    entry,
    8,
    header,
    InvalidEntry(entry_offset),
  ))
  use _ <- result.try(case offset > 0 {
    True -> Ok(Nil)
    False -> Error(InvalidOffset(offset))
  })
  Ok(LinkedIfd(offset, location))
}

fn parse_raw_exif_tag(tag_id: Int, location: OffsetLocation) -> RawExifTag {
  let tag_bytes = <<tag_id:size(16)>>
  dict.get(exif_tag_map(location), tag_bytes)
  |> result.unwrap(UnknownExifTag(bit_array.base16_encode(tag_bytes)))
}

/// Convert the sub-optimal raw partially parsed entry into
/// the final consumable tag
pub fn raw_exif_entry_to_parsed_tag(
  record: exif_tag.ExifTagRecord,
  entry: RawExifEntry,
  tiff_header: TiffHeader,
) -> exif_tag.ExifTagRecord {
  use <- bool.guard(when: !entry_is_valid(entry, tiff_header), return: record)
  case entry.tag {
    ImageDescription -> {
      let image_description =
        entry.data
        |> extract_ascii_data
        |> Some

      exif_tag.ExifTagRecord(..record, image_description: image_description)
    }
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
        extract_integer_data(entry, tiff_header)
        |> dict.get(internal_orientation.exif_orientation_map(), _)
        |> result.unwrap(orientation.InvalidOrientation)
        |> Some

      exif_tag.ExifTagRecord(..record, orientation: orientation)
    }
    XResolution -> {
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)
      exif_tag.ExifTagRecord(
        ..record,
        x_resolution: Some(int.to_float(numerator) /. int.to_float(denominator)),
      )
    }
    YResolution -> {
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)
      exif_tag.ExifTagRecord(
        ..record,
        y_resolution: Some(int.to_float(numerator) /. int.to_float(denominator)),
      )
    }
    ResolutionUnit -> {
      let unit = case extract_integer_data(entry, tiff_header) {
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
      let positioning = case extract_integer_data(entry, tiff_header) {
        1 -> y_cb_cr_positioning.Centered
        2 -> y_cb_cr_positioning.CoSited
        _ -> y_cb_cr_positioning.InvalidYCbCrPositioning
      }
      exif_tag.ExifTagRecord(..record, y_cb_cr_positioning: Some(positioning))
    }
    ExposureTime -> {
      let exposure_time =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)
        |> utils.simplify_fraction
      exif_tag.ExifTagRecord(..record, exposure_time: Some(exposure_time))
    }

    FNumber -> {
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)
      exif_tag.ExifTagRecord(
        ..record,
        f_number: Some(int.to_float(numerator) /. int.to_float(denominator)),
      )
    }
    ExposureProgram -> {
      let exposure_program = case extract_integer_data(entry, tiff_header) {
        0 -> exposure_program.NotDefined
        1 -> exposure_program.Manual
        2 -> exposure_program.ProgramAE
        3 -> exposure_program.AperturePriorityAE
        4 -> exposure_program.ShutterSpeedPriorityAE
        5 -> exposure_program.Creative
        6 -> exposure_program.Action
        7 -> exposure_program.Portrait
        8 -> exposure_program.Landscape
        9 -> exposure_program.Bulb
        _ -> exposure_program.InvalidExposureProgram
      }
      exif_tag.ExifTagRecord(..record, exposure_program: Some(exposure_program))
    }

    ISO -> {
      let iso = extract_integer_data(entry, tiff_header)
      exif_tag.ExifTagRecord(..record, iso: Some(iso))
    }

    ExifVersion -> {
      let exif_version =
        entry.data
        |> extract_ascii_data
        |> Some
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
        entry.data
        |> bit_array_to_decimal_list
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

    //TODO: Removing shutter speed value because exiftool looks
    // to be extracting the "exposure time" even though the real underlying
    // rational number. https://photo.stackexchange.com/questions/108817/shutter-speed-from-the-exif-shutterspeedvalue
    // ShutterSpeedValue -> {
    //   io.debug(bit_array.inspect(entry.data))
    //   io.debug(entry)
    //   let shutter_speed_value = extract_signed_rational_to_fraction(entry.data)
    //
    //   exif_tag.ExifTagRecord(
    //     ..record,
    //     shutter_speed_value: Some(shutter_speed_value),
    //   )
    // }
    ApertureValue -> {
      // Convert the APEX aperture value to an F-number using 2^(APEX / 2).
      //https://www.media.mit.edu/pia/Research/deepview/exif.html
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)

      let aperture_decimal =
        int.to_float(numerator) /. int.to_float(denominator)

      let aperture_value =
        float.power(2.0, aperture_decimal /. 2.0)
        |> result.unwrap(0.0)

      exif_tag.ExifTagRecord(..record, aperture_value: Some(aperture_value))
    }

    BrightnessValue -> {
      let Fraction(numerator, denominator) =
        extract_signed_rational_to_fraction(entry.data, tiff_header)
      let brightness_value =
        int.to_float(numerator) /. int.to_float(denominator)

      exif_tag.ExifTagRecord(..record, brightness_value: Some(brightness_value))
    }

    ExposureCompensation -> {
      let Fraction(numerator, denominator) =
        extract_signed_rational_to_fraction(entry.data, tiff_header)

      let exposure_compensation =
        int.to_float(numerator) /. int.to_float(denominator)

      exif_tag.ExifTagRecord(
        ..record,
        exposure_compensation: Some(exposure_compensation),
      )
    }
    //
    MeteringMode -> {
      let metering_mode = case extract_integer_data(entry, tiff_header) {
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
      let value = extract_integer_data(entry, tiff_header)
      let flash =
        dict.get(internal_flash.flash_tag_map(), <<value:size(16)>>)
        |> result.unwrap(flash.InvalidFlash)

      exif_tag.ExifTagRecord(..record, flash: Some(flash))
    }

    FocalLength -> {
      let Fraction(numerator, denominator) =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)

      let focal_length = int.to_float(numerator) /. int.to_float(denominator)

      exif_tag.ExifTagRecord(..record, focal_length: Some(focal_length))
    }

    SubjectArea -> {
      let subject_area =
        extract_unsigned_short_to_int_list(
          entry.data,
          entry.component_count,
          0,
          tiff_header,
        )

      exif_tag.ExifTagRecord(..record, subject_area: Some(subject_area))
    }

    // MakerData ->
    //   exif_tag.ExifTagRecord(..record, maker_data: Some(exif_tag.TBD))
    SubSecTimeOriginal -> {
      let sub_sec_time_original =
        extract_ascii_data(entry.data)
        |> Some
      exif_tag.ExifTagRecord(
        ..record,
        sub_sec_time_original: sub_sec_time_original,
      )
    }

    SubSecTimeDigitized -> {
      let sub_sec_time_digitized =
        extract_ascii_data(entry.data)
        |> Some
      exif_tag.ExifTagRecord(
        ..record,
        sub_sec_time_digitized: sub_sec_time_digitized,
      )
    }

    FlashpixVersion -> {
      let flash_pix_version =
        entry.data
        |> extract_ascii_data
      exif_tag.ExifTagRecord(
        ..record,
        flash_pix_version: Some(flash_pix_version),
      )
    }

    ColorSpace -> {
      let color_space = case extract_integer_data(entry, tiff_header) {
        0x0001 -> color_space.SRGB
        0x0002 -> color_space.AdobeRGB
        0xfffd -> color_space.WideGamutRGB
        0xfffe -> color_space.ICCProfile
        0xffff -> color_space.Uncalibrated
        _ -> color_space.InvalidColorSpace
      }
      exif_tag.ExifTagRecord(..record, color_space: Some(color_space))
    }

    ExifImageWidth -> {
      let exif_image_width =
        extract_integer_data(entry, tiff_header)
        |> Some
      exif_tag.ExifTagRecord(..record, exif_image_width: exif_image_width)
    }

    ExifImageHeight -> {
      let exif_image_height =
        extract_integer_data(entry, tiff_header)
        |> Some
      exif_tag.ExifTagRecord(..record, exif_image_height: exif_image_height)
    }

    SensingMethod -> {
      let int_value = extract_integer_data(entry, tiff_header)

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
      let int_value = extract_integer_data(entry, tiff_header)
      let exposure_mode = case int_value {
        0 -> exposure_mode.Auto
        1 -> exposure_mode.Manual
        2 -> exposure_mode.AutoBracket
        _ -> exposure_mode.InvalidExposureMode
      }
      exif_tag.ExifTagRecord(..record, exposure_mode: Some(exposure_mode))
    }
    WhiteBalance -> {
      let int_value = extract_integer_data(entry, tiff_header)
      let white_balance = case int_value {
        0 -> white_balance.Auto
        1 -> white_balance.Manual
        _ -> white_balance.InvalidWhiteBalance
      }
      exif_tag.ExifTagRecord(..record, white_balance: Some(white_balance))
    }
    FocalLengthIn35mmFormat -> {
      let int_value =
        extract_integer_data(entry, tiff_header)
        |> Some
      exif_tag.ExifTagRecord(..record, focal_length_in_35_mm_format: int_value)
    }
    SceneCaptureType -> {
      let int_value = extract_integer_data(entry, tiff_header)
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
    // LensInfo -> {
    //   let fraction_list = bit_array_to_fraction_list(entry.data)
    //
    //   exif_tag.ExifTagRecord(..record, lens_info: Some(fraction_list))
    // }
    LensMake -> {
      let lens_make = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(..record, lens_make: Some(lens_make))
    }
    LensModel -> {
      let lens_model = extract_ascii_data(entry.data)
      exif_tag.ExifTagRecord(..record, lens_model: Some(lens_model))
    }
    CompositeImage -> {
      let int_value = extract_integer_data(entry, tiff_header)
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
      let fraction_list = bit_array_to_fraction_list(entry.data, tiff_header)
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
      let fraction_list = bit_array_to_fraction_list(entry.data, tiff_header)
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
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)
      let gps_altitude_float = case gps_altitude_fraction {
        Fraction(numerator, denominator) ->
          int.to_float(numerator) /. int.to_float(denominator)
      }

      exif_tag.ExifTagRecord(..record, gps_altitude: Some(gps_altitude_float))
    }
    GPSTimestamp -> {
      let fraction_list = bit_array_to_fraction_list(entry.data, tiff_header)
      let gps_timestamp = case fraction_list {
        [hours, minutes, seconds] ->
          fraction_to_string(hours)
          <> ":"
          <> fraction_to_string(minutes)
          <> ":"
          <> fraction_to_string(seconds)
        _ -> "Invalid"
      }
      exif_tag.ExifTagRecord(..record, gps_timestamp: Some(gps_timestamp))
    }
    GPSSpeedRef -> {
      let gps_speed_ref_string = extract_ascii_data(entry.data)
      let gps_speed_ref = case gps_speed_ref_string {
        "K" -> gps_speed_ref.KilometersPerHour
        "M" -> gps_speed_ref.MilesPerHour
        "N" -> gps_speed_ref.Knots
        _ -> gps_speed_ref.InvalidGPSSpeedRef
      }

      exif_tag.ExifTagRecord(..record, gps_speed_ref: Some(gps_speed_ref))
    }
    GPSSpeed -> {
      let gps_speed_fraction =
        extract_unsigned_rational_to_fraction(entry.data, tiff_header)
      let gps_speed = case gps_speed_fraction {
        Fraction(numerator, denominator) ->
          int.to_float(numerator) /. int.to_float(denominator)
      }

      exif_tag.ExifTagRecord(..record, gps_speed: Some(gps_speed))
    }

    _ -> {
      record
    }
  }
}

fn entry_is_valid(entry: RawExifEntry, header: TiffHeader) -> Bool {
  case entry.tag {
    ImageDescription
    | Make
    | Model
    | Software
    | ModifyDate
    | HostComputer
    | DateTimeOriginal
    | CreateDate
    | OffsetTime
    | OffsetTimeOriginal
    | OffsetTimeDigitized
    | SubSecTimeOriginal
    | SubSecTimeDigitized
    | LensMake
    | LensModel
    | GPSLatitudeRef
    | GPSLongitudeRef
    | GPSSpeedRef ->
      is_type(entry, AsciiString(1))
      && entry.component_count > 0
      && data_size_is_valid(entry)
      && ascii_is_valid(entry.data)
    ExifVersion | FlashpixVersion ->
      is_type(entry, Undefined(1))
      && entry.component_count == 4
      && data_size_is_valid(entry)
      && ascii_is_valid(entry.data)
    ComponentsConfiguration ->
      is_type(entry, Undefined(1))
      && entry.component_count == 4
      && data_size_is_valid(entry)
    SceneType ->
      is_type(entry, Undefined(1))
      && entry.component_count == 1
      && data_size_is_valid(entry)
      && entry.data == <<1>>
    Orientation
    | ResolutionUnit
    | YCbCrPositioning
    | ExposureProgram
    | ISO
    | MeteringMode
    | Flash
    | ColorSpace
    | SensingMethod
    | ExposureMode
    | WhiteBalance
    | FocalLengthIn35mmFormat
    | SceneCaptureType
    | CompositeImage ->
      is_type(entry, UnsignedShort(2))
      && entry.component_count == 1
      && data_size_is_valid(entry)
    ExifImageWidth | ExifImageHeight ->
      is_unsigned_integer(entry)
      && entry.component_count == 1
      && data_size_is_valid(entry)
    XResolution
    | YResolution
    | ExposureTime
    | FNumber
    | FocalLength
    | GPSAltitude
    | GPSSpeed ->
      is_type(entry, UnsignedRational(8))
      && entry.component_count == 1
      && data_size_is_valid(entry)
      && rational_denominators_are_valid(entry.data, 1, header, 0)
    ApertureValue ->
      is_type(entry, UnsignedRational(8))
      && entry.component_count == 1
      && data_size_is_valid(entry)
      && rational_denominators_are_valid(entry.data, 1, header, 0)
      && aperture_is_safe(entry.data, header)
    BrightnessValue | ExposureCompensation ->
      is_type(entry, SignedRational(8))
      && entry.component_count == 1
      && data_size_is_valid(entry)
      && rational_denominators_are_valid(entry.data, 1, header, 0)
    GPSLatitude | GPSLongitude | GPSTimestamp ->
      is_type(entry, UnsignedRational(8))
      && entry.component_count == 3
      && data_size_is_valid(entry)
      && rational_denominators_are_valid(entry.data, 3, header, 0)
    SubjectArea ->
      is_type(entry, UnsignedShort(2))
      && entry.component_count >= 2
      && entry.component_count <= 4
      && data_size_is_valid(entry)
    GPSAltitudeRef ->
      is_type(entry, UnsignedByte(1))
      && entry.component_count == 1
      && data_size_is_valid(entry)
    // These tags are recognized but intentionally not exposed yet.
    ShutterSpeedValue
    | MakerData
    | LensInfo
    | ExifOffset
    | GPSLink(_)
    | IFDLink(_)
    | EndOfIFD
    | UnknownExifTag(_) -> False
  }
}

fn is_type(entry: RawExifEntry, expected: RawExifType) -> Bool {
  entry.data_type == expected
}

fn is_unsigned_integer(entry: RawExifEntry) -> Bool {
  case entry.data_type {
    UnsignedShort(_) | UnsignedLong(_) -> True
    _ -> False
  }
}

fn data_size_is_valid(entry: RawExifEntry) -> Bool {
  bit_array.byte_size(entry.data)
  == entry.data_type.bytes * entry.component_count
}

fn ascii_is_valid(data: BitArray) -> Bool {
  data
  |> utils.trim_zero_bits
  |> bit_array.to_string
  |> result.is_ok
}

fn rational_denominators_are_valid(
  data: BitArray,
  count: Int,
  header: TiffHeader,
  index: Int,
) -> Bool {
  case index >= count {
    True -> True
    False ->
      case read_u32(data, index * 8 + 4, header, InvalidEntry(index)) {
        Ok(denominator) if denominator != 0 ->
          rational_denominators_are_valid(data, count, header, index + 1)
        _ -> False
      }
  }
}

fn aperture_is_safe(data: BitArray, header: TiffHeader) -> Bool {
  case
    read_u32(data, 0, header, InvalidEntry(0)),
    read_u32(data, 4, header, InvalidEntry(0))
  {
    Ok(numerator), Ok(denominator) if denominator != 0 ->
      int.to_float(numerator) /. int.to_float(denominator) <=. 2046.0
    _, _ -> False
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

fn bit_array_to_fraction_list(
  data: BitArray,
  header: TiffHeader,
) -> List(Fraction) {
  bit_array_to_fraction_list_loop(data, header, 0, [])
  |> list.reverse
}

fn bit_array_to_fraction_list_loop(
  data: BitArray,
  header: TiffHeader,
  offset: Int,
  fractions: List(Fraction),
) -> List(Fraction) {
  case
    read_u32(data, offset, header, InvalidEntry(offset)),
    read_u32(data, offset + 4, header, InvalidEntry(offset))
  {
    Ok(numerator), Ok(denominator) ->
      bit_array_to_fraction_list_loop(data, header, offset + 8, [
        Fraction(numerator, denominator),
        ..fractions
      ])
    _, _ -> fractions
  }
}

fn fraction_to_string(fraction: Fraction) -> String {
  let Fraction(numerator, denominator) = fraction
  case numerator % denominator {
    0 -> int.to_string(numerator / denominator)
    _ -> float.to_string(int.to_float(numerator) /. int.to_float(denominator))
  }
}

fn extract_unsigned_short_to_int_list(
  data: BitArray,
  size: Int,
  count: Int,
  header: TiffHeader,
) -> List(Int) {
  case count < size, read_u16(data, count * 2, header, InvalidEntry(count)) {
    True, Ok(value) -> [
      value,
      ..extract_unsigned_short_to_int_list(data, size, count + 1, header)
    ]
    _, _ -> []
  }
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
  |> string.trim
}

/// For an unsigned short of length n, turn it into a list of ints
/// Take the bit array types that need to be converted to some sort
/// of decimal and convert them
fn extract_integer_data(
  exif_entry: RawExifEntry,
  tiff_header: TiffHeader,
) -> Int {
  case exif_entry.data_type {
    UnsignedShort(_) ->
      read_u16(exif_entry.data, 0, tiff_header, InvalidEntry(0))
      |> result.unwrap(0)
    UnsignedLong(_) ->
      read_u32(exif_entry.data, 0, tiff_header, InvalidEntry(0))
      |> result.unwrap(0)
    UnsignedRational(_) -> {
      let numerator =
        read_u32(exif_entry.data, 0, tiff_header, InvalidEntry(0))
        |> result.unwrap(0)
      let denominator =
        read_u32(exif_entry.data, 4, tiff_header, InvalidEntry(0))
        |> result.unwrap(0)

      numerator / denominator
    }
    _ -> 0
  }
}

fn extract_unsigned_rational_to_fraction(
  data: BitArray,
  tiff_header: TiffHeader,
) -> Fraction {
  let numerator =
    read_u32(data, 0, tiff_header, InvalidEntry(0))
    |> result.unwrap(0)
  let denominator =
    read_u32(data, 4, tiff_header, InvalidEntry(0))
    |> result.unwrap(0)

  Fraction(numerator, denominator)
}

fn extract_signed_rational_to_fraction(
  data: BitArray,
  tiff_header: TiffHeader,
) -> Fraction {
  let numerator =
    read_i32(data, 0, tiff_header, InvalidEntry(0))
    |> result.unwrap(0)
  let denominator =
    read_i32(data, 4, tiff_header, InvalidEntry(0))
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
        #(<<0x01, 0x0e>>, ImageDescription),
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
        #(<<0x00, 0x07>>, GPSTimestamp),
        #(<<0x00, 0x0c>>, GPSSpeedRef),
        #(<<0x00, 0x0d>>, GPSSpeed),
      ])
  }
}

fn parse_data_or_offset(
  entry: BitArray,
  full_segment: BitArray,
  data_type: RawExifType,
  component_count: Int,
  tiff_header: TiffHeader,
) -> Result(BitArray, ExifParseError) {
  let size = data_type.bytes * component_count
  case component_count > 0 && size <= 4 {
    True -> checked_slice(entry, 8, size, InvalidEntry(8))
    False if component_count <= 0 -> Error(InvalidEntry(8))
    False -> {
      use offset <- result.try(read_u32(entry, 8, tiff_header, InvalidEntry(8)))
      case offset >= 8 {
        True -> checked_slice(full_segment, offset, size, InvalidOffset(offset))
        False -> Error(InvalidOffset(offset))
      }
    }
  }
}

fn checked_slice(
  data: BitArray,
  offset: Int,
  length: Int,
  error: ExifParseError,
) -> Result(BitArray, ExifParseError) {
  case
    offset >= 0 && length >= 0 && offset + length <= bit_array.byte_size(data)
  {
    True -> bit_array.slice(data, offset, length) |> result.replace_error(error)
    False -> Error(error)
  }
}

fn read_u16(
  data: BitArray,
  offset: Int,
  header: TiffHeader,
  error: ExifParseError,
) -> Result(Int, ExifParseError) {
  use bytes <- result.try(checked_slice(data, offset, 2, error))
  case header, bytes {
    Motorola(_), <<value:big-unsigned-size(16)>> -> Ok(value)
    Intel(_), <<value:little-unsigned-size(16)>> -> Ok(value)
    _, _ -> Error(error)
  }
}

fn read_u32(
  data: BitArray,
  offset: Int,
  header: TiffHeader,
  error: ExifParseError,
) -> Result(Int, ExifParseError) {
  use bytes <- result.try(checked_slice(data, offset, 4, error))
  case header, bytes {
    Motorola(_), <<value:big-unsigned-size(32)>> -> Ok(value)
    Intel(_), <<value:little-unsigned-size(32)>> -> Ok(value)
    _, _ -> Error(error)
  }
}

fn read_i32(
  data: BitArray,
  offset: Int,
  header: TiffHeader,
  error: ExifParseError,
) -> Result(Int, ExifParseError) {
  use bytes <- result.try(checked_slice(data, offset, 4, error))
  case header, bytes {
    Motorola(_), <<value:big-signed-size(32)>> -> Ok(value)
    Intel(_), <<value:little-signed-size(32)>> -> Ok(value)
    _, _ -> Error(error)
  }
}
