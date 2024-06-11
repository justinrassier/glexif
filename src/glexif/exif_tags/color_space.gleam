// 0x1 = sRGB
// 0x2 = Adobe RGB
// 0xfffd = Wide Gamut RGB
// 0xfffe = ICC Profile
// 0xffff = Uncalibrated
pub type ColorSpace {
  SRGB
  AdobeRGB
  WideGamutRGB
  ICCProfile
  Uncalibrated
  InvalidColorSpace
}
