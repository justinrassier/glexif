import gleam/dict
import glexif/exif_tags/flash

pub fn flash_tag_map() {
  dict.from_list([
    #(<<0x00, 0x00>>, flash.NoFlash),
    #(<<0x00, 0x01>>, flash.Fired),
    #(<<0x00, 0x05>>, flash.FiredReturnNotDetected),
    #(<<0x00, 0x07>>, flash.FiredReturnDetected),
    #(<<0x00, 0x08>>, flash.OnDidNotFire),
    #(<<0x00, 0x09>>, flash.OnFired),
    #(<<0x00, 0x0d>>, flash.OnReturnNotDetected),
    #(<<0x00, 0x0f>>, flash.OnReturnDetected),
    #(<<0x00, 0x10>>, flash.OffDidNotFire),
    #(<<0x00, 0x14>>, flash.OffDidNotFireReturnNotDetected),
    #(<<0x00, 0x18>>, flash.AutoDidNotFire),
    #(<<0x00, 0x19>>, flash.AutoFired),
    #(<<0x00, 0x1d>>, flash.AutoFiredReturnNotDetected),
    #(<<0x00, 0x1f>>, flash.AutoFiredReturnDetected),
    #(<<0x00, 0x20>>, flash.NoFlashFunction),
    #(<<0x00, 0x30>>, flash.OffNoFlashFunction),
    #(<<0x00, 0x41>>, flash.FiredRedEyeReduction),
    #(<<0x00, 0x45>>, flash.FiredRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x47>>, flash.FiredRedEyeReductionReturnDetected),
    #(<<0x00, 0x49>>, flash.OnRedEyeReduction),
    #(<<0x00, 0x4d>>, flash.OnRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x4f>>, flash.OnRedEyeReductionReturnDetected),
    #(<<0x00, 0x50>>, flash.OffRedEyeReduction),
    #(<<0x00, 0x58>>, flash.AutoDidNotFireRedEyeReduction),
    #(<<0x00, 0x59>>, flash.AutoFiredRedEyeReduction),
    #(<<0x00, 0x5d>>, flash.AutoFiredRedEyeReductionReturnNotDetected),
    #(<<0x00, 0x5f>>, flash.AutoFiredRedEyeReductionReturnDetected),
  ])
}
