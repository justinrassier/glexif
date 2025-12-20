import gleam/option.{type Option, None}
import glexif/exif_tags/color_space.{type ColorSpace}
import glexif/exif_tags/components_configuration.{type ComponentsConfiguration}
import glexif/exif_tags/composite_image.{type CompositeImage}
import glexif/exif_tags/exposure_mode.{type ExposureMode}
import glexif/exif_tags/exposure_program.{type ExposureProgram}
import glexif/exif_tags/flash.{type Flash}
import glexif/exif_tags/gps_altitude_ref.{type GPSAltitudeRef}
import glexif/exif_tags/gps_speed_ref.{type GPSSpeedRef}
import glexif/exif_tags/metering_mode.{type MeteringMode}
import glexif/exif_tags/orientation.{type Orientation}
import glexif/exif_tags/resolution_unit.{type ResolutionUnit}
import glexif/exif_tags/scene_capture_type.{type SceneCaptureType}
import glexif/exif_tags/scene_type.{type SceneType}
import glexif/exif_tags/sensing_method.{type SensingMethod}
import glexif/exif_tags/white_balance.{type WhiteBalance}
import glexif/exif_tags/y_cb_cr_positioning.{type YCbCrPositioning}
import glexif/units/fraction.{type Fraction}
import glexif/units/gps_coordinates.{type GPSCoordinates}

pub type ExifTagRecord {
  ExifTagRecord(
    image_description: Option(String),
    make: Option(String),
    model: Option(String),
    orientation: Option(Orientation),
    x_resolution: Option(Int),
    y_resolution: Option(Int),
    resolution_unit: Option(ResolutionUnit),
    software: Option(String),
    modify_date: Option(String),
    host_computer: Option(String),
    y_cb_cr_positioning: Option(YCbCrPositioning),
    exposure_time: Option(Fraction),
    f_number: Option(Fraction),
    exposure_program: Option(ExposureProgram),
    iso: Option(Int),
    exif_version: Option(String),
    date_time_original: Option(String),
    create_date: Option(String),
    offset_time: Option(String),
    offset_time_original: Option(String),
    offset_time_digitized: Option(String),
    components_configuration: Option(List(ComponentsConfiguration)),
    shutter_speed_value: Option(Fraction),
    aperature_value: Option(Fraction),
    brightness_value: Option(Float),
    exposure_compensation: Option(Fraction),
    metering_mode: Option(MeteringMode),
    flash: Option(Flash),
    focal_length: Option(Float),
    subject_area: Option(List(Int)),
    maker_data: Option(TBD),
    sub_sec_time_original: Option(String),
    sub_sec_time_digitized: Option(String),
    flash_pix_version: Option(String),
    color_space: Option(ColorSpace),
    exif_image_width: Option(Int),
    exif_image_height: Option(Int),
    sensing_method: Option(SensingMethod),
    scene_type: Option(SceneType),
    exposure_mode: Option(ExposureMode),
    white_balance: Option(WhiteBalance),
    focal_length_in_35_mm_format: Option(Int),
    scene_capture_type: Option(SceneCaptureType),
    lens_info: Option(List(Fraction)),
    lens_make: Option(String),
    lens_model: Option(String),
    composite_image: Option(CompositeImage),
    gps_latitude_ref: Option(String),
    gps_latitude: Option(GPSCoordinates),
    gps_longitude_ref: Option(String),
    gps_longitude: Option(GPSCoordinates),
    gps_altitude_ref: Option(GPSAltitudeRef),
    gps_altitude: Option(Float),
    gps_timestamp: Option(String),
    gps_speed_ref: Option(GPSSpeedRef),
    gps_speed: Option(Float),
  )
}

pub fn new() -> ExifTagRecord {
  ExifTagRecord(
    image_description: None,
    make: None,
    model: None,
    orientation: None,
    x_resolution: None,
    y_resolution: None,
    resolution_unit: None,
    software: None,
    modify_date: None,
    host_computer: None,
    y_cb_cr_positioning: None,
    exposure_time: None,
    f_number: None,
    exposure_program: None,
    iso: None,
    exif_version: None,
    date_time_original: None,
    create_date: None,
    offset_time: None,
    offset_time_original: None,
    offset_time_digitized: None,
    components_configuration: None,
    shutter_speed_value: None,
    aperature_value: None,
    brightness_value: None,
    exposure_compensation: None,
    metering_mode: None,
    flash: None,
    focal_length: None,
    subject_area: None,
    maker_data: None,
    sub_sec_time_original: None,
    sub_sec_time_digitized: None,
    flash_pix_version: None,
    color_space: None,
    exif_image_width: None,
    exif_image_height: None,
    sensing_method: None,
    scene_type: None,
    exposure_mode: None,
    white_balance: None,
    focal_length_in_35_mm_format: None,
    scene_capture_type: None,
    lens_info: None,
    lens_make: None,
    lens_model: None,
    composite_image: None,
    gps_latitude_ref: None,
    gps_latitude: None,
    gps_longitude_ref: None,
    gps_longitude: None,
    gps_altitude_ref: None,
    gps_altitude: None,
    gps_timestamp: None,
    gps_speed_ref: None,
    gps_speed: None,
  )
}

/// Unparsed data that has to be figured out
pub type TBD {
  TBD
}
