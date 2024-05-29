pub type ExifTag {
  Make(String)
  Model(String)
  Orientation(Orientation)
  XResolution(Int)
  YResolution(Int)
  ResolutionUnit(ResolutionUnit)
  Software(String)
  ModifyDate(String)
  HostComputer(String)
  YCbCrPositioning(YCbCrPositioning)
  ExposureTime(Fraction)
  Unknown
}

// 1 = Horizontal (normal)
// 2 = Mirror horizontal
// 3 = Rotate 180
// 4 = Mirror vertical
// 5 = Mirror horizontal and rotate 270 CW
// 6 = Rotate 90 CW
// 7 = Mirror horizontal and rotate 90 CW
// 8 = Rotate 270 CW
pub type Orientation {
  Horizontal
  MirrorHorizontal
  Rotate180
  MirrorVertical
  MirrorHorizontalAndRotate270CW
  Rotate90CW
  MirrorHorizontalAndRotate90CW
  Rotate270CW
  InvalidOrientation
}

pub type ResolutionUnit {
  None
  Inches
  Centimeters
  InvalidResolutionUnit
}

pub type YCbCrPositioning {
  Centered
  CoSited
  InvalidYCbCrPositioning
}

pub type Fraction {
  Fraction(numerator: Int, denominator: Int)
}
