//// Read standard EXIF metadata from JPEG APP1 segments.

import file_streams/file_stream
import file_streams/file_stream_error
import gleam/int
import glexif/exif_tag
import glexif/internal/raw

/// A file-level failure that prevented EXIF metadata from being read safely.
///
/// Unsupported or malformed optional tags are skipped when the surrounding
/// JPEG, TIFF header, and IFD structure remain valid.
pub type ExifError {
  /// The file could not be opened.
  FileOpenError(message: String)
  /// The opened file could not be read.
  FileReadError(message: String)
  /// Parsing succeeded, but the opened file could not be closed.
  FileCloseError(message: String)
  /// The file does not start with a JPEG start-of-image marker.
  InvalidJpegHeader
  /// No `Exif`-prefixed APP1 candidate was present before image data.
  ExifMarkerNotFound
  /// The file ended while a complete JPEG segment was being read.
  UnexpectedEndOfFile
  /// A JPEG segment declared an invalid size.
  InvalidSegmentSize(size: Int)
  /// A standard EXIF APP1 segment had an invalid EXIF header.
  InvalidExifHeader
  /// The TIFF byte order, magic value, or header was invalid.
  InvalidTiffHeader
  /// An IFD table or structural entry was invalid.
  InvalidEntry(offset: Int)
  /// A structural TIFF offset was outside the EXIF segment.
  InvalidOffset(offset: Int)
  /// Linked IFDs revisited an offset that had already been parsed.
  OffsetCycle(offset: Int)
  /// Parsing exceeded the work permitted by the EXIF segment size.
  TraversalLimitExceeded
}

/// Read EXIF metadata from a JPEG file without panicking for invalid input.
///
/// A readable JPEG with no `Exif`-prefixed APP1 candidate returns
/// `Error(ExifMarkerNotFound)`. A malformed candidate returns the applicable
/// EXIF or TIFF error instead.
pub fn get_exif_data_for_file(
  file_path: String,
) -> Result(exif_tag.ExifTagRecord, ExifError) {
  case file_stream.open_read(file_path) {
    Error(error) -> Error(FileOpenError(file_stream_error.describe(error)))
    Ok(stream) -> {
      let outcome = case raw.read_exif_segment(stream) {
        Error(error) -> Error(parse_error(error))
        Ok(segment) ->
          raw.parse_exif_data_as_record(segment)
          |> result_map_parse_error
      }
      let close_outcome = file_stream.close(stream)

      case outcome, close_outcome {
        Error(error), _ -> Error(error)
        Ok(_), Error(error) ->
          Error(FileCloseError(file_stream_error.describe(error)))
        Ok(record), Ok(Nil) -> Ok(record)
      }
    }
  }
}

fn result_map_parse_error(
  result: Result(exif_tag.ExifTagRecord, raw.ExifParseError),
) -> Result(exif_tag.ExifTagRecord, ExifError) {
  case result {
    Ok(record) -> Ok(record)
    Error(error) -> Error(parse_error(error))
  }
}

fn parse_error(error: raw.ExifParseError) -> ExifError {
  case error {
    raw.StreamReadError(error) ->
      FileReadError(file_stream_error.describe(error))
    raw.ExifMarkerNotFound -> ExifMarkerNotFound
    raw.UnexpectedEndOfFile -> UnexpectedEndOfFile
    raw.InvalidJpegHeader -> InvalidJpegHeader
    raw.InvalidSegmentSize(size) -> InvalidSegmentSize(size)
    raw.InvalidExifHeader -> InvalidExifHeader
    raw.InvalidTiffHeader -> InvalidTiffHeader
    raw.InvalidEntry(offset) -> InvalidEntry(offset)
    raw.InvalidOffset(offset) -> InvalidOffset(offset)
    raw.OffsetCycle(offset) -> OffsetCycle(offset)
    raw.TraversalLimitExceeded -> TraversalLimitExceeded
  }
}

/// Format an EXIF error for logs or user-facing diagnostics.
pub fn error_to_string(error: ExifError) -> String {
  case error {
    FileOpenError(message) -> "Could not open file: " <> message
    FileReadError(message) -> "Could not read file: " <> message
    FileCloseError(message) -> "Could not close file: " <> message
    InvalidJpegHeader -> "Invalid JPEG header"
    ExifMarkerNotFound -> "No EXIF APP1 segment was found"
    UnexpectedEndOfFile -> "Unexpected end of file"
    InvalidSegmentSize(size) ->
      "Invalid JPEG segment size: " <> int.to_string(size)
    InvalidExifHeader -> "Invalid EXIF header"
    InvalidTiffHeader -> "Invalid TIFF header"
    InvalidEntry(offset) ->
      "Invalid TIFF entry at offset " <> int.to_string(offset)
    InvalidOffset(offset) -> "Invalid TIFF offset: " <> int.to_string(offset)
    OffsetCycle(offset) ->
      "TIFF offset cycle detected at " <> int.to_string(offset)
    TraversalLimitExceeded -> "TIFF traversal limit exceeded"
  }
}
