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
  |> list.take(2)
  |> should.equal([exif_tag.Make("Apple"), exif_tag.Model("iPhone 14 Pro")])

  let res =
    glexif.get_exif_data_for_file("test/fixtures/test.jpeg")
    |> list.find(fn(r) {
      case r {
        exif_tag.Model(_) -> True
        _ -> False
      }
    })

  io.debug(res)
}
