import gleeunit/should
import glexif/internal/utils
import glexif/units/fraction.{type Fraction, Fraction}

pub fn trim_zero_bits_test() {
  <<0x41, 0x70, 0x70, 0x6C, 0x65, 0x00>>
  |> utils.trim_zero_bits
  |> should.equal(<<0x41, 0x70, 0x70, 0x6C, 0x65>>)

  <<0x41, 0x70, 0x70, 0x6C, 0x65, 0x00, 0x00, 0x00>>
  |> utils.trim_zero_bits
  |> should.equal(<<0x41, 0x70, 0x70, 0x6C, 0x65>>)
}

pub fn greatest_common_denominator_test() {
  utils.greatest_common_denominator(24, 36)
  |> should.equal(12)
}

pub fn simplify_fraction_test() {
  utils.simplify_fraction(Fraction(24, 36))
  |> should.equal(Fraction(2, 3))

  utils.simplify_fraction(Fraction(10, 100))
  |> should.equal(Fraction(1, 10))
}
