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

/// Decodes JSON produced by `exiftool -j -n -api StructFormat=JSONQ -EXIF:all`.
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
    decode.optional(decode_numeric_float()),
  )
  use y_resolution <- decode.optional_field(
    "YResolution",
    None,
    decode.optional(decode_numeric_float()),
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
    decode.optional(decode_numeric_float()),
  )
  use exposure_program <- decode.optional_field(
    "ExposureProgram",
    None,
    decode.optional(decode_exposure_program()),
  )
  use iso <- decode.optional_field(
    "ISO",
    None,
    decode.optional(decode_numeric_int()),
  )
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
    decode.optional(decode_numeric_float()),
  )
  use brightness_value <- decode.optional_field(
    "BrightnessValue",
    None,
    decode.optional(decode_numeric_float()),
  )
  use exposure_compensation <- decode.optional_field(
    "ExposureCompensation",
    None,
    decode.optional(decode_numeric_float()),
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
    decode.optional(decode_trimmed_string()),
  )
  use sub_sec_time_digitized <- decode.optional_field(
    "SubSecTimeDigitized",
    None,
    decode.optional(decode_trimmed_string()),
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
    decode.optional(decode_numeric_int()),
  )
  use exif_image_height <- decode.optional_field(
    "ExifImageHeight",
    None,
    decode.optional(decode_numeric_int()),
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
  decode_trimmed_string()
}

fn decode_composite_image() -> Decoder(composite_image.CompositeImage) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> composite_image.Unknown
      "1" -> composite_image.NotACompositeImage
      "2" -> composite_image.GeneralCompositeImage
      "3" -> composite_image.CompositeImageCapturedWhileShooting
      _ -> composite_image.InvalidCompositeImage
    }
  })
}

fn decode_scene_capture_type() -> Decoder(scene_capture_type.SceneCaptureType) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> scene_capture_type.Standard
      "1" -> scene_capture_type.Landscape
      "2" -> scene_capture_type.Portrait
      "3" -> scene_capture_type.Night
      "4" -> scene_capture_type.Other
      _ -> scene_capture_type.InvalidSceneCaptureType
    }
  })
}

fn decode_white_balance() -> Decoder(white_balance.WhiteBalance) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> white_balance.Auto
      "1" -> white_balance.Manual
      _ -> white_balance.InvalidWhiteBalance
    }
  })
}

fn decode_exposure_mode() -> Decoder(exposure_mode.ExposureMode) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> exposure_mode.Auto
      "1" -> exposure_mode.Manual
      "2" -> exposure_mode.AutoBracket
      _ -> exposure_mode.InvalidExposureMode
    }
  })
}

fn decode_scene_type() -> Decoder(scene_type.SceneType) {
  decode_trimmed_string()
  |> decode.then(fn(s) {
    case s {
      "1" -> decode.success(scene_type.DirectlyPhotographed)
      _ -> decode.failure(scene_type.DirectlyPhotographed, "SceneType")
    }
  })
}

fn decode_sensing_method() -> Decoder(sensing_method.SensingMethod) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "1" -> sensing_method.SensingMethodNotDefined
      "2" -> sensing_method.OneChipColorArea
      "3" -> sensing_method.TwoChipColorArea
      "4" -> sensing_method.ThreeChipColorArea
      "5" -> sensing_method.ColorSequentialArea
      "7" -> sensing_method.Trilinear
      "8" -> sensing_method.ColorSequentialLinear
      _ -> sensing_method.InvalidSensingMethod
    }
  })
}

fn decode_color_space() -> Decoder(color_space.ColorSpace) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "1" -> color_space.SRGB
      "2" -> color_space.AdobeRGB
      "65533" -> color_space.WideGamutRGB
      "65534" -> color_space.ICCProfile
      "65535" -> color_space.Uncalibrated
      _ -> color_space.InvalidColorSpace
    }
  })
}

fn decode_subject_area() -> Decoder(List(Int)) {
  decode_int_list()
}

fn decode_focal_length_35_mm_format() -> Decoder(Int) {
  decode_numeric_int()
}

fn decode_focal_length() -> Decoder(Float) {
  decode_numeric_float()
}

fn decode_flash() -> Decoder(flash.Flash) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> flash.NoFlash
      "1" -> flash.Fired
      "5" -> flash.FiredReturnNotDetected
      "7" -> flash.FiredReturnDetected
      "8" -> flash.OnDidNotFire
      "9" -> flash.OnFired
      "13" -> flash.OnReturnNotDetected
      "15" -> flash.OnReturnDetected
      "16" -> flash.OffDidNotFire
      "20" -> flash.OffDidNotFireReturnNotDetected
      "24" -> flash.AutoDidNotFire
      "25" -> flash.AutoFired
      "29" -> flash.AutoFiredReturnNotDetected
      "31" -> flash.AutoFiredReturnDetected
      "32" -> flash.NoFlashFunction
      "48" -> flash.OffNoFlashFunction
      "65" -> flash.FiredRedEyeReduction
      "69" -> flash.FiredRedEyeReductionReturnNotDetected
      "71" -> flash.FiredRedEyeReductionReturnDetected
      "73" -> flash.OnRedEyeReduction
      "77" -> flash.OnRedEyeReductionReturnNotDetected
      "79" -> flash.OnRedEyeReductionReturnDetected
      "80" -> flash.OffRedEyeReduction
      "88" -> flash.AutoDidNotFireRedEyeReduction
      "89" -> flash.AutoFiredRedEyeReduction
      "93" -> flash.AutoFiredRedEyeReductionReturnNotDetected
      "95" -> flash.AutoFiredRedEyeReductionReturnDetected
      _ -> flash.InvalidFlash
    }
  })
}

fn decode_metering_mode() -> Decoder(metering_mode.MeteringMode) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> metering_mode.UnknownMeteringMode
      "1" -> metering_mode.Average
      "2" -> metering_mode.CenterWeightedAverage
      "3" -> metering_mode.Spot
      "4" -> metering_mode.MultiSpot
      "5" -> metering_mode.MultiSegement
      "6" -> metering_mode.Partial
      "255" -> metering_mode.Other
      _ -> metering_mode.InvalidMeteringMode
    }
  })
}

fn decode_numeric_float() -> Decoder(Float) {
  decode_trimmed_string()
  |> decode.then(fn(value) {
    case float.parse(value) {
      Ok(number) -> decode.success(number)
      Error(_) ->
        case int.parse(value) {
          Ok(number) -> decode.success(int.to_float(number))
          Error(_) -> decode.failure(0.0, "Float")
        }
    }
  })
}

fn decode_numeric_int() -> Decoder(Int) {
  decode_trimmed_string()
  |> decode.then(fn(value) {
    case int.parse(value) {
      Ok(number) -> decode.success(number)
      Error(_) -> decode.failure(0, "Int")
    }
  })
}

fn decode_components_configuration() -> Decoder(List(ComponentsConfiguration)) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    value
    |> string.split(" ")
    |> list.map(fn(component) {
      case component {
        "0" -> components_configuration.NA
        "1" -> components_configuration.Y
        "2" -> components_configuration.Cb
        "3" -> components_configuration.Cr
        "4" -> components_configuration.R
        "5" -> components_configuration.G
        "6" -> components_configuration.B
        _ -> components_configuration.InvalidComponentsConfiguration
      }
    })
  })
}

fn decode_fraction() -> Decoder(Fraction) {
  decode_numeric_float()
  |> decode.map(fn(value) {
    Fraction(float.round(value *. 1_000_000_000_000.0), 1_000_000_000_000)
    |> utils.simplify_fraction
  })
}

fn decode_int_list() -> Decoder(List(Int)) {
  decode_trimmed_string()
  |> decode.then(fn(value) {
    let values =
      value
      |> string.split(" ")
      |> list.map(int.parse)

    case list.all(values, result.is_ok) {
      True -> decode.success(list.map(values, result.unwrap(_, 0)))
      False -> decode.failure([], "List(Int)")
    }
  })
}

fn decode_exposure_program() -> Decoder(exposure_program.ExposureProgram) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "0" -> exposure_program.NotDefined
      "1" -> exposure_program.Manual
      "2" -> exposure_program.ProgramAE
      "3" -> exposure_program.AperturePriorityAE
      "4" -> exposure_program.ShutterSpeedPriorityAE
      "5" -> exposure_program.Creative
      "6" -> exposure_program.Action
      "7" -> exposure_program.Portrait
      "8" -> exposure_program.Landscape
      "9" -> exposure_program.Bulb
      _ -> exposure_program.InvalidExposureProgram
    }
  })
}

fn decode_y_cb_cr_positioning() -> Decoder(y_cb_cr_positioning.YCbCrPositioning) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "1" -> y_cb_cr_positioning.Centered
      "2" -> y_cb_cr_positioning.CoSited
      _ -> y_cb_cr_positioning.InvalidYCbCrPositioning
    }
  })
}

fn decode_resolution_unit() -> Decoder(resolution_unit.ResolutionUnit) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "1" -> resolution_unit.NoResolutionTagUnit
      "2" -> resolution_unit.Inches
      "3" -> resolution_unit.Centimeters
      _ -> resolution_unit.InvalidResolutionUnit
    }
  })
}

fn decode_orientation() -> Decoder(orientation.Orientation) {
  decode_trimmed_string()
  |> decode.map(fn(value) {
    case value {
      "1" -> orientation.Horizontal
      "2" -> orientation.MirrorHorizontal
      "3" -> orientation.Rotate180
      "4" -> orientation.MirrorVertical
      "5" -> orientation.MirrorHorizontalAndRotate270CW
      "6" -> orientation.Rotate90CW
      "7" -> orientation.MirrorHorizontalAndRotate90CW
      "8" -> orientation.Rotate270CW
      _ -> orientation.InvalidOrientation
    }
  })
}
