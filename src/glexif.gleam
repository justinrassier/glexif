import file_streams/read_stream
import glexif/exif_tag.{type ExifTag}
import glexif/internal/raw

pub fn get_exif_data_for_file(file_path) -> List(ExifTag) {
  let assert Ok(rs) = read_stream.open(file_path)
  // Move the stream up until you hit the exif marker
  let _ = raw.read_until_marker(rs)
  // Get the size of the exif segment
  let size = raw.read_exif_size(rs)
  // close up the stream as we don't need it anymore (for now at least)
  let _ = read_stream.close(rs)

  // read in the exif segment and then parse out the final results
  // I am not sure at this point if there are multiple exif segments to a file
  // so this may need to be updated to advance the read stream to the next segment 
  case raw.read_exif_segment(rs, size) {
    Ok(segment) -> raw.parse_exif_data(segment)
    _ -> []
  }
}
