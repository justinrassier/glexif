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
  FNumber(Fraction)
  ExposureProgram(ExposureProgram)
  ISO(Int)
  ExifVersion(String)
  DateTimeOriginal(String)
  CreateDate(String)
  OffsetTime(String)
  OffsetTimeOriginal(String)
  OffsetTimeDigitized(String)
  ComponentsConfiguration(List(ComponentsConfiguration))
  ShutterSpeedValue(Fraction)
  ApertureValue(Fraction)
  BrightnessValue(Float)

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

// 0 = Not Defined
// 1 = Manual
// 2 = Program AE
// 3 = Aperture-priority AE
// 4 = Shutter speed priority AE
// 5 = Creative (Slow speed)
// 6 = Action (High speed)
// 7 = Portrait
// 8 = Landscape
// 9 = Bulb
pub type ExposureProgram {
  NotDefined
  Manual
  ProgramAE
  AperturePriorityAE
  ShutterSpeedPriorityAE
  Creative
  Action
  Portrait
  Landscape
  Bulb
  InvalidExposureProgram
}

// 	
// 0 = -
// 1 = Y
// 2 = Cb
// 3 = Cr	  	4 = R
// 5 = G
// 6 = B
pub type ComponentsConfiguration {
  Y
  Cb
  Cr
  R
  G
  B
  NA
  InvalidComponentsConfiguration
}
