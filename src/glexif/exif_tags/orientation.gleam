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
