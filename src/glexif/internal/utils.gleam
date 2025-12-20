import gleam/bit_array
import gleam/int
import gleam/result

pub fn print_bit_array(arr: Result(BitArray, Nil)) -> Nil {
  echo bit_array.inspect(result.unwrap(arr, <<>>))
  Nil
}

pub fn bit_array_to_decimal(arr: BitArray) -> Int {
  arr
  |> bit_array.base16_encode
  |> hex_string_to_decimal
}

pub fn hex_string_to_decimal(hex_string: String) -> Int {
  result.unwrap(int.base_parse(hex_string, 16), 0)
}

/// Trim the zero bits from the end of the bit array
/// not sure if there is a better way to go about this, but it works
/// It pattern matches on the last slice of an array and the recursive calls
/// to trim_trailing_zeros will eventually return the trimmed array
pub fn trim_zero_bits(arr: BitArray) -> BitArray {
  arr
  |> trim_trailing_zeros
}

fn trim_trailing_zeros(str: BitArray) -> BitArray {
  case bit_array.slice(str, bit_array.byte_size(str) - 1, 1) {
    Ok(<<0>>) -> {
      str
      |> bit_array.slice(0, bit_array.byte_size(str) - 1)
      |> result.unwrap(<<>>)
      |> trim_trailing_zeros
    }
    Ok(_a) -> str
    _ -> str
  }
}

pub fn bit_array_reverse(b: BitArray) -> BitArray {
  case b {
    <<a, b:bits>> -> bit_array.concat([bit_array_reverse(b), <<a>>])
    _ -> <<>>
  }
}
