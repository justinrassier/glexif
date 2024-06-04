import gleam/dict

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
  ExposureCompensation(Fraction)
  MeteringMode(MeteringMode)
  Flash(Flash)

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

// 0 = Unknown
// 1 = Average
// 2 = Center-weighted average
// 3 = Spot
// 4 = Multi-spot
// 5 = Multi-segment
// 6 = Partial
// 255 = Other
pub type MeteringMode {
  UnknownMeteringMode
  Average
  CenterWeightedAverage
  Spot
  MultiSpot
  MultiSegement
  Partial
  Other
  InvalidMeteringMode
}

// 0x0	= No Flash
// 0x1	= Fired
// 0x5	= Fired, Return not detected
// 0x7	= Fired, Return detected
// 0x8	= On, Did not fire
// 0x9	= On, Fired
// 0xd	= On, Return not detected
// 0xf	= On, Return detected
// 0x10	= Off, Did not fire
// 0x14	= Off, Did not fire, Return not detected
// 0x18	= Auto, Did not fire
// 0x19	= Auto, Fired
// 0x1d	= Auto, Fired, Return not detected
// 0x1f	= Auto, Fired, Return detected
// 0x20	= No flash function
// 0x30	= Off, No flash function
// 0x41	= Fired, Red-eye reduction
// 0x45	= Fired, Red-eye reduction, Return not detected
// 0x47	= Fired, Red-eye reduction, Return detected
// 0x49	= On, Red-eye reduction
// 0x4d	= On, Red-eye reduction, Return not detected
// 0x4f	= On, Red-eye reduction, Return detected
// 0x50	= Off, Red-eye reduction
// 0x58	= Auto, Did not fire, Red-eye reduction
// 0x59	= Auto, Fired, Red-eye reduction
// 0x5d	= Auto, Fired, Red-eye reduction, Return not detected
// 0x5f	= Auto, Fired, Red-eye reduction, Return detected
pub type Flash {
  NoFlash
  Fired
  FiredReturnNotDetected
  FiredReturnDetected
  OnDidNotFire
  OnFired
  OnReturnNotDetected
  OnReturnDetected
  OffDidNotFire
  OffDidNotFireReturnNotDetected
  AutoDidNotFire
  AutoFired
  AutoFiredReturnNotDetected
  AutoFiredReturnDetected
  NoFlashFunction
  OffNoFlashFunction
  FiredRedEyeReduction
  FiredRedEyeReductionReturnNotDetected
  FiredRedEyeReductionReturnDetected
  OnRedEyeReduction
  OnRedEyeReductionReturnNotDetected
  OnRedEyeReductionReturnDetected
  OffRedEyeReduction
  AutoDidNotFireRedEyeReduction
  AutoFiredRedEyeReduction
  AutoFiredRedEyeReductionReturnNotDetected
  AutoFiredRedEyeReductionReturnDetected
  InvalidFlash
}

fn flash_tag_map() {
  dict.from_list([#(<<0x00>>, NoFlash)])
}
