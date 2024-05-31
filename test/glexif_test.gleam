import gleam/io
import gleam/list
import gleeunit
import gleeunit/should
import glexif
import glexif/exif_tag

pub fn main() {
  gleeunit.main()
}

pub fn full_test() {
  glexif.get_exif_data_for_file("test/fixtures/test.jpeg")
  |> list.take(23)
  |> should.equal([
    exif_tag.Make("Apple"),
    exif_tag.Model("iPhone 14 Pro"),
    exif_tag.Orientation(exif_tag.Rotate90CW),
    exif_tag.XResolution(72),
    exif_tag.YResolution(72),
    exif_tag.ResolutionUnit(exif_tag.Inches),
    exif_tag.Software("17.2.1"),
    exif_tag.ModifyDate("2024:02:18 17:34:57"),
    exif_tag.HostComputer("iPhone 14 Pro"),
    exif_tag.YCbCrPositioning(exif_tag.Centered),
    exif_tag.ExposureTime(exif_tag.Fraction(1, 179)),
    exif_tag.FNumber(exif_tag.Fraction(89, 50)),
    exif_tag.ExposureProgram(exif_tag.ProgramAE),
    exif_tag.ISO(64),
    exif_tag.ExifVersion("0232"),
    exif_tag.DateTimeOriginal("2024:02:18 17:34:57"),
    exif_tag.CreateDate("2024:02:18 17:34:57"),
    exif_tag.OffsetTime("-06:00"),
    exif_tag.OffsetTimeOriginal("-06:00"),
    exif_tag.OffsetTimeDigitized("-06:00"),
    exif_tag.ComponentsConfiguration([
      exif_tag.Y,
      exif_tag.Cb,
      exif_tag.Cr,
      exif_tag.NA,
    ]),
    // TODO: convert this to seconds instead of the raw fraction
    exif_tag.ShutterSpeedValue(exif_tag.Fraction(124_929, 16_690)),
    // TODO: convert this to the human readable value that it should be
    exif_tag.AperatureValue(exif_tag.Fraction(163_775, 98_437)),
  ])
}
