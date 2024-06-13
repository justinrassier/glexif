import gleam/dict
import glexif/exif_tags/orientation

pub fn exif_orientation_map() {
  dict.from_list([
    #(1, orientation.Horizontal),
    #(2, orientation.MirrorHorizontal),
    #(3, orientation.Rotate180),
    #(4, orientation.MirrorVertical),
    #(5, orientation.MirrorHorizontalAndRotate270CW),
    #(6, orientation.Rotate90CW),
    #(7, orientation.MirrorHorizontalAndRotate90CW),
    #(8, orientation.Rotate270CW),
  ])
}
