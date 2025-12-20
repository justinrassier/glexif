import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import glexif
import glexif/exif_tag
import glexif/exif_tags/color_space
import glexif/exif_tags/components_configuration
import glexif/exif_tags/composite_image
import glexif/exif_tags/exposure_mode
import glexif/exif_tags/exposure_program
import glexif/exif_tags/flash.{OffDidNotFire}
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
import glexif/units/fraction.{Fraction}
import glexif/units/gps_coordinates

pub fn main() {
  gleeunit.main()
}

pub fn full_intel_test() {
  glexif.get_exif_data_for_file("test/fixtures/intel.jpeg")
  |> should.equal(exif_tag.ExifTagRecord(
    image_description: Some("                               "),
    make: Some("SONY"),
    model: Some("DSC-W350"),
    orientation: Some(orientation.Horizontal),
    x_resolution: Some(72),
    y_resolution: Some(72),
    resolution_unit: Some(resolution_unit.Inches),
    software: None,
    modify_date: Some("2010:01:01 14:20:19"),
    host_computer: None,
    y_cb_cr_positioning: Some(y_cb_cr_positioning.CoSited),
    exposure_time: Some(Fraction(10, 300)),
    f_number: Some(Fraction(27, 10)),
    exposure_program: Some(exposure_program.ProgramAE),
    iso: Some(320),
    exif_version: Some("1220"),
    date_time_original: Some("2010:01:01 14:20:19"),
    create_date: Some("2010:01:01 14:20:19"),
    offset_time: None,
    offset_time_original: None,
    offset_time_digitized: None,
    components_configuration: Some([
      components_configuration.NA,
      components_configuration.Cr,
      components_configuration.Cb,
      components_configuration.Y,
    ]),
    shutter_speed_value: None,
    aperature_value: None,
    brightness_value: None,
    exposure_compensation: Some(Fraction(0, 10)),
    metering_mode: Some(metering_mode.MultiSegement),
    flash: Some(flash.AutoDidNotFire),
    focal_length: Some(4.7),
    subject_area: None,
    maker_data: Some(exif_tag.TBD),
    sub_sec_time_original: None,
    sub_sec_time_digitized: None,
    flash_pix_version: Some("0010"),
    color_space: Some(color_space.SRGB),
    exif_image_width: Some(4320),
    exif_image_height: Some(3240),
    sensing_method: None,
    scene_type: Some(scene_type.DirectlyPhotographed),
    exposure_mode: Some(exposure_mode.Auto),
    white_balance: Some(white_balance.Auto),
    focal_length_in_35_mm_format: None,
    scene_capture_type: Some(scene_capture_type.Standard),
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
  ))
}

pub fn full_motorola_test() {
  glexif.get_exif_data_for_file("test/fixtures/motorola.jpeg")
  |> should.equal(exif_tag.ExifTagRecord(
    image_description: None,
    make: Some("Apple"),
    model: Some("iPhone 14 Pro"),
    orientation: Some(orientation.Rotate90CW),
    x_resolution: Some(72),
    y_resolution: Some(72),
    resolution_unit: Some(resolution_unit.Inches),
    software: Some("17.2.1"),
    modify_date: Some("2024:02:18 17:34:57"),
    host_computer: Some("iPhone 14 Pro"),
    y_cb_cr_positioning: Some(y_cb_cr_positioning.Centered),
    exposure_time: Some(Fraction(1, 179)),
    f_number: Some(Fraction(89, 50)),
    exposure_program: Some(exposure_program.ProgramAE),
    iso: Some(64),
    exif_version: Some("0232"),
    date_time_original: Some("2024:02:18 17:34:57"),
    create_date: Some("2024:02:18 17:34:57"),
    offset_time: Some("-06:00"),
    offset_time_original: Some("-06:00"),
    offset_time_digitized: Some("-06:00"),
    components_configuration: Some([
      components_configuration.Y,
      components_configuration.Cb,
      components_configuration.Cr,
      components_configuration.NA,
    ]),
    // TODO: convert this to seconds instead of the raw fraction
    shutter_speed_value: Some(Fraction(124_929, 16_690)),
    // TODO: convert this to the human readable value that it should be
    aperature_value: Some(Fraction(163_775, 98_437)),
    brightness_value: Some(5.389648033126294),
    exposure_compensation: Some(Fraction(0, 1)),
    metering_mode: Some(metering_mode.MultiSegement),
    flash: Some(OffDidNotFire),
    // TODO: Need units? Or is it always millimeters? ExifTool rounds to 1 decimal, should I do that too?
    focal_length: Some(6.86),
    subject_area: Some([2009, 1505, 2208, 1324]),
    // TODO: parse out maker data. This is a whole ball of wax and I'm kicking the can down the road
    maker_data: Some(exif_tag.TBD),
    sub_sec_time_original: Some("289"),
    sub_sec_time_digitized: Some("289"),
    flash_pix_version: Some("0100"),
    color_space: Some(color_space.Uncalibrated),
    exif_image_width: Some(4032),
    exif_image_height: Some(3024),
    sensing_method: Some(sensing_method.OneChipColorArea),
    scene_type: Some(scene_type.DirectlyPhotographed),
    exposure_mode: Some(exposure_mode.Auto),
    white_balance: Some(white_balance.Auto),
    focal_length_in_35_mm_format: Some(24),
    scene_capture_type: Some(scene_capture_type.Standard),
    //TODO: Convert these 4 rational numbers to something useful
    lens_info: Some([
      Fraction(1_551_800, 699_009),
      Fraction(9, 1),
      Fraction(1_244_236, 699_009),
      Fraction(14, 5),
    ]),
    lens_make: Some("Apple"),
    lens_model: Some("iPhone 14 Pro back triple camera 6.86mm f/1.78"),
    composite_image: Some(composite_image.GeneralCompositeImage),
    gps_latitude_ref: Some("N"),
    gps_latitude: Some(gps_coordinates.GPSCoordinates(44, 58, 29.31)),
    gps_longitude_ref: Some("W"),
    gps_longitude: Some(gps_coordinates.GPSCoordinates(93, 15, 35.93)),
    gps_altitude_ref: Some(gps_altitude_ref.AboveSeaLevel),
    gps_altitude: Some(245.97845468053492),
    gps_timestamp: Some("23:34:56"),
    gps_speed_ref: Some(gps_speed_ref.KilometersPerHour),
    gps_speed: Some(0.0),
  ))
}
