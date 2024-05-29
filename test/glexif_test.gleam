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
  |> list.take(11)
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
  ])
}
