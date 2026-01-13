import gleam/dynamic/decode.{type Decoder}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import glexif/exif_tag
import glexif/exif_tags/color_space
import glexif/exif_tags/components_configuration.{type ComponentsConfiguration}
import glexif/exif_tags/composite_image
import glexif/exif_tags/exposure_mode
import glexif/exif_tags/exposure_program
import glexif/exif_tags/flash
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

fn decode_trimmed_string() -> Decoder(String) {
  decode.string
  |> decode.map(string.trim)
}

pub fn exif_tag_decoder() -> Decoder(exif_tag.ExifTagRecordSimple) {
  use image_description <- decode.optional_field(
    "ImageDescription",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use make <- decode.optional_field(
    "Make",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use model <- decode.optional_field(
    "Model",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use orientation <- decode.optional_field(
    "Orientation",
    None,
    decode.optional(decode_orientation()),
  )
  use x_resolution <- decode.optional_field(
    "XResolution",
    None,
    decode.optional(decode.int),
  )
  use y_resolution <- decode.optional_field(
    "YResolution",
    None,
    decode.optional(decode.int),
  )
  use resolution_unit <- decode.optional_field(
    "ResolutionUnit",
    None,
    decode.optional(decode_resolution_unit()),
  )
  use software <- decode.optional_field(
    "Software",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use modify_date <- decode.optional_field(
    "ModifyDate",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use host_computer <- decode.optional_field(
    "HostComputer",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use y_cb_cr_positioning <- decode.optional_field(
    "YCbCrPositioning",
    None,
    decode.optional(decode_y_cb_cr_positioning()),
  )
  use exposure_time <- decode.optional_field(
    "ExposureTime",
    None,
    decode.optional(decode_fraction()),
  )
  use f_number <- decode.optional_field(
    "FNumber",
    None,
    decode.optional(decode.float),
  )
  use exposure_program <- decode.optional_field(
    "ExposureProgram",
    None,
    decode.optional(decode_exposure_program()),
  )
  use iso <- decode.optional_field("ISO", None, decode.optional(decode.int))
  use exif_version <- decode.optional_field(
    "ExifVersion",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use date_time_original <- decode.optional_field(
    "DateTimeOriginal",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use create_date <- decode.optional_field(
    "CreateDate",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use offset_time <- decode.optional_field(
    "OffsetTime",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use offset_time_original <- decode.optional_field(
    "OffsetTimeOriginal",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use offset_time_digitized <- decode.optional_field(
    "OffsetTimeDigitized",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use components_configuration <- decode.optional_field(
    "ComponentsConfiguration",
    None,
    decode.optional(decode_components_configuration()),
  )
  use aperture_value <- decode.optional_field(
    "ApertureValue",
    None,
    decode.optional(decode.float),
  )
  use brightness_value <- decode.optional_field(
    "BrightnessValue",
    None,
    decode.optional(decode.float),
  )
  use exposure_compensation <- decode.optional_field(
    "ExposureCompensation",
    None,
    decode.optional(decode_int_to_float()),
  )
  use metering_mode <- decode.optional_field(
    "MeteringMode",
    None,
    decode.optional(decode_metering_mode()),
  )
  use flash <- decode.optional_field(
    "Flash",
    None,
    decode.optional(decode_flash()),
  )
  use focal_length <- decode.optional_field(
    "FocalLength",
    None,
    decode.optional(decode_focal_length()),
  )
  use subject_area <- decode.optional_field(
    "SubjectArea",
    None,
    decode.optional(decode_subject_area()),
  )
  use sub_sec_time_original <- decode.optional_field(
    "SubSecTimeOriginal",
    None,
    decode.optional(decode.int),
  )
  use sub_sec_time_digitized <- decode.optional_field(
    "SubSecTimeDigitized",
    None,
    decode.optional(decode.int),
  )
  use flash_pix_version <- decode.optional_field(
    "FlashpixVersion",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use color_space <- decode.optional_field(
    "ColorSpace",
    None,
    decode.optional(decode_color_space()),
  )
  use exif_image_width <- decode.optional_field(
    "ExifImageWidth",
    None,
    decode.optional(decode.int),
  )
  use exif_image_height <- decode.optional_field(
    "ExifImageHeight",
    None,
    decode.optional(decode.int),
  )
  use sensing_method <- decode.optional_field(
    "SensingMethod",
    None,
    decode.optional(decode_sensing_method()),
  )
  use scene_type <- decode.optional_field(
    "SceneType",
    None,
    decode.optional(decode_scene_type()),
  )
  use exposure_mode <- decode.optional_field(
    "ExposureMode",
    None,
    decode.optional(decode_exposure_mode()),
  )
  use white_balance <- decode.optional_field(
    "WhiteBalance",
    None,
    decode.optional(decode_white_balance()),
  )
  use focal_length_in_35_mm_format <- decode.optional_field(
    "FocalLengthIn35mmFormat",
    None,
    decode.optional(decode_focal_length_35_mm_format()),
  )
  use scene_capture_type <- decode.optional_field(
    "SceneCaptureType",
    None,
    decode.optional(decode_scene_capture_type()),
  )
  use lens_make <- decode.optional_field(
    "LensMake",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use lens_model <- decode.optional_field(
    "LensModel",
    None,
    decode.optional(decode_trimmed_string()),
  )
  use composite_image <- decode.optional_field(
    "CompositeImage",
    None,
    decode.optional(decode_composite_image()),
  )
  use gps_latitude_ref <- decode.optional_field(
    "GPSLatitudeRef",
    None,
    decode.optional(decode_gps_latitude_ref()),
  )

  decode.success(exif_tag.ExifTagRecordSimple(
    image_description:,
    make:,
    model:,
    orientation:,
    x_resolution:,
    y_resolution:,
    resolution_unit:,
    software:,
    modify_date:,
    host_computer:,
    y_cb_cr_positioning:,
    exposure_time:,
    f_number:,
    exposure_program:,
    iso:,
    exif_version:,
    date_time_original:,
    create_date:,
    offset_time:,
    offset_time_original:,
    offset_time_digitized:,
    components_configuration:,
    aperture_value:,
    brightness_value:,
    exposure_compensation:,
    metering_mode:,
    flash:,
    focal_length:,
    subject_area:,
    sub_sec_time_original:,
    sub_sec_time_digitized:,
    flash_pix_version:,
    color_space:,
    exif_image_width:,
    exif_image_height:,
    sensing_method:,
    scene_type:,
    exposure_mode:,
    white_balance:,
    focal_length_in_35_mm_format:,
    scene_capture_type:,
    lens_make:,
    lens_model:,
    composite_image:,
    gps_latitude_ref:,
  ))
}

fn decode_gps_latitude_ref() -> Decoder(String) {
  decode.string
  |> decode.then(fn(s) {
    let trimmed = string.trim(s)
    case trimmed {
      "North" -> decode.success("N")
      "South" -> decode.success("S")
      _ -> decode.failure("N", "GPS Latitude Ref")
    }
  })
}

fn decode_composite_image() -> Decoder(composite_image.CompositeImage) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "General Composite Image" ->
        decode.success(composite_image.GeneralCompositeImage)
      _ ->
        decode.failure(composite_image.GeneralCompositeImage, "CompositeImage")
    }
  })
}

fn decode_scene_capture_type() -> Decoder(scene_capture_type.SceneCaptureType) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Standard" -> decode.success(scene_capture_type.Standard)
      _ -> decode.failure(scene_capture_type.Standard, "SceneCaptureType")
    }
  })
}

fn decode_white_balance() -> Decoder(white_balance.WhiteBalance) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Auto" -> decode.success(white_balance.Auto)
      _ -> decode.failure(white_balance.Auto, "WhiteBalance")
    }
  })
}

fn decode_exposure_mode() -> Decoder(exposure_mode.ExposureMode) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Auto" -> decode.success(exposure_mode.Auto)
      _ -> decode.failure(exposure_mode.Auto, "ExposureMode")
    }
  })
}

fn decode_scene_type() -> Decoder(scene_type.SceneType) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Directly photographed" -> decode.success(scene_type.DirectlyPhotographed)
      _ -> decode.failure(scene_type.DirectlyPhotographed, "SceneType")
    }
  })
}

fn decode_sensing_method() -> Decoder(sensing_method.SensingMethod) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "One-chip color area" -> decode.success(sensing_method.OneChipColorArea)
      _ -> decode.failure(sensing_method.OneChipColorArea, "SensingMethod")
    }
  })
}

fn decode_color_space() -> Decoder(color_space.ColorSpace) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Uncalibrated" -> decode.success(color_space.Uncalibrated)
      "sRGB" -> decode.success(color_space.SRGB)
      _ -> decode.failure(color_space.SRGB, "ColorSpace")
    }
  })
}

fn decode_subject_area() -> Decoder(List(Int)) {
  decode.string
  |> decode.then(fn(s) {
    let ints =
      s
      |> string.split(" ")
      |> list.map(int.parse)
      |> list.map(result.unwrap(_, 0))
    decode.success(ints)
  })
}

fn decode_focal_length_35_mm_format() -> Decoder(Int) {
  decode.string
  |> decode.then(fn(s) {
    let result =
      s
      |> string.split(" ")
      |> list.first
      |> result.try(int.parse)
      |> result.unwrap(0)
    decode.success(result)
  })
}

fn decode_focal_length() -> Decoder(Float) {
  decode.string
  |> decode.then(fn(s) {
    let result =
      s
      |> string.split(" ")
      |> list.first
      |> result.try(float.parse)
      |> result.unwrap(0.0)
    decode.success(result)
  })
}

fn decode_flash() -> Decoder(flash.Flash) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Off, Did not fire" -> decode.success(flash.OffDidNotFire)
      "Auto, Did not fire" -> decode.success(flash.AutoDidNotFire)
      _ -> decode.failure(flash.OffDidNotFire, "Flash")
    }
  })
}

fn decode_metering_mode() -> Decoder(metering_mode.MeteringMode) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Multi-segment" -> decode.success(metering_mode.MultiSegement)
      _ -> decode.failure(metering_mode.MultiSegement, "MeteringMode")
    }
  })
}

fn decode_int_to_float() -> Decoder(Float) {
  decode.int
  |> decode.map(int.to_float)
}

fn decode_components_configuration() -> Decoder(List(ComponentsConfiguration)) {
  decode.string
  |> decode.then(fn(s) {
    let components =
      s
      |> string.split(",")
      |> list.map(string.trim)
      |> list.map(fn(v) {
        case v {
          "Y" -> components_configuration.Y
          "Cb" -> components_configuration.Cb
          "Cr" -> components_configuration.Cr
          "R" -> components_configuration.R
          "G" -> components_configuration.G
          "B" -> components_configuration.B
          "-" -> components_configuration.NA
          _ -> components_configuration.InvalidComponentsConfiguration
        }
      })
    decode.success(components)
  })
}

fn decode_fraction() -> Decoder(Fraction) {
  decode.string
  |> decode.then(fn(s) {
    case string.split_once(s, "/") {
      Ok(#(num_str, denom_str)) -> {
        case int.parse(num_str), int.parse(denom_str) {
          Ok(numerator), Ok(denominator) ->
            decode.success(
              utils.simplify_fraction(Fraction(numerator, denominator)),
            )
          _, _ -> decode.failure(Fraction(0, 1), "Fraction")
        }
      }
      Error(_) -> decode.failure(Fraction(0, 1), "Fraction")
    }
  })
}

fn decode_exposure_program() -> Decoder(exposure_program.ExposureProgram) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Program AE" -> decode.success(exposure_program.ProgramAE)
      _ -> decode.failure(exposure_program.ProgramAE, "ExposureProgram")
    }
  })
}

fn decode_y_cb_cr_positioning() -> Decoder(y_cb_cr_positioning.YCbCrPositioning) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Co-sited" -> decode.success(y_cb_cr_positioning.CoSited)
      "Centered" -> decode.success(y_cb_cr_positioning.Centered)
      _ -> decode.failure(y_cb_cr_positioning.CoSited, "YCbCrPositioning")
    }
  })
}

fn decode_resolution_unit() -> Decoder(resolution_unit.ResolutionUnit) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "inches" -> decode.success(resolution_unit.Inches)
      "centimeters" -> decode.success(resolution_unit.Centimeters)
      _ -> decode.failure(resolution_unit.Inches, "ResolutionUnit")
    }
  })
}

fn decode_orientation() -> Decoder(orientation.Orientation) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "Horizontal (normal)" -> decode.success(orientation.Horizontal)
      "Rotate 90 CW" -> decode.success(orientation.Rotate90CW)
      "Rotate 180" -> decode.success(orientation.Rotate180)
      "Rotate 270 CW" -> decode.success(orientation.Rotate270CW)
      "Mirror Vertical" -> decode.success(orientation.MirrorVertical)
      "Mirror Horizontal" -> decode.success(orientation.MirrorHorizontal)
      _ -> decode.failure(orientation.Horizontal, "Orientation")
    }
  })
}
