import gleeunit/should
import glexif/internal/utils

pub fn trim_zero_bits_test() {
  <<0x41, 0x70, 0x70, 0x6C, 0x65, 0x00>>
  |> utils.trim_zero_bits
  |> should.equal(<<0x41, 0x70, 0x70, 0x6C, 0x65>>)

  <<0x41, 0x70, 0x70, 0x6C, 0x65, 0x00, 0x00, 0x00>>
  |> utils.trim_zero_bits
  |> should.equal(<<0x41, 0x70, 0x70, 0x6C, 0x65>>)
}