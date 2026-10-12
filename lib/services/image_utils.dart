import 'dart:io';
import 'dart:typed_data';

class ImageUtils {
  /// Reads EXIF orientation from a JPEG file.
  /// Returns orientation value:
  /// 1: Normal (0 deg)
  /// 3: 180 deg
  /// 6: 90 deg CW (needs 90 deg rotation to be upright)
  /// 8: 270 deg CW (needs 270 deg rotation to be upright)
  /// Returns 1 if no EXIF orientation found or on error.
  static Future<int> getExifOrientation(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 1;

      // Only read the first 64KB, which contains all EXIF headers
      final length = await file.length();
      final readLength = length > 65536 ? 65536 : length;
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(readLength);
      await raf.close();

      return parseExifOrientation(bytes);
    } catch (_) {
      return 1;
    }
  }

  /// Synchronous parser for bytes
  static int parseExifOrientation(Uint8List bytes) {
    if (bytes.length < 4) return 1;

    // Check SOI marker 0xFFD8
    if (bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;

    int offset = 2;
    while (offset + 4 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final marker = bytes[offset + 1];
      offset += 2;

      // SOS (Start of Scan) or EOI (End of Image)
      if (marker == 0xDA || marker == 0xD9) break;

      if (offset + 2 > bytes.length) break;
      final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
      if (segmentLength < 2) break;

      // APP1 marker (0xE1)
      if (marker == 0xE1) {
        final exifOffset = offset + 2;
        if (exifOffset + 6 <= bytes.length) {
          // Check "Exif\0\0"
          if (bytes[exifOffset] == 0x45 && // E
              bytes[exifOffset + 1] == 0x78 && // x
              bytes[exifOffset + 2] == 0x69 && // i
              bytes[exifOffset + 3] == 0x66 && // f
              bytes[exifOffset + 4] == 0x00 &&
              bytes[exifOffset + 5] == 0x00) {
            final tiffOffset = exifOffset + 6;
            return _parseTiffOrientation(bytes, tiffOffset);
          }
        }
      }

      offset += segmentLength;
    }

    return 1;
  }

  static int _parseTiffOrientation(Uint8List bytes, int tiffOffset) {
    if (tiffOffset + 8 > bytes.length) return 1;

    final isLittleEndian = bytes[tiffOffset] == 0x49 && bytes[tiffOffset + 1] == 0x49; // 'II'
    final isBigEndian = bytes[tiffOffset] == 0x4D && bytes[tiffOffset + 1] == 0x4D; // 'MM'

    if (!isLittleEndian && !isBigEndian) return 1;

    int read16(int pos) {
      if (pos + 2 > bytes.length) return 0;
      return isLittleEndian
          ? (bytes[pos] | (bytes[pos + 1] << 8))
          : ((bytes[pos] << 8) | bytes[pos + 1]);
    }

    int read32(int pos) {
      if (pos + 4 > bytes.length) return 0;
      return isLittleEndian
          ? (bytes[pos] | (bytes[pos + 1] << 8) | (bytes[pos + 2] << 16) | (bytes[pos + 3] << 24))
          : ((bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3]);
    }

    final magic = read16(tiffOffset + 2);
    if (magic != 42) return 1;

    final ifd0Offset = read32(tiffOffset + 4);
    int currentOffset = tiffOffset + ifd0Offset;

    if (currentOffset + 2 > bytes.length) return 1;
    final numEntries = read16(currentOffset);
    currentOffset += 2;

    for (int i = 0; i < numEntries; i++) {
      if (currentOffset + 12 > bytes.length) break;
      final tag = read16(currentOffset);
      if (tag == 0x0112) {
        // Orientation tag
        final orientation = read16(currentOffset + 8);
        return orientation;
      }
      currentOffset += 12;
    }

    return 1;
  }

  /// Converts EXIF orientation to clockwise degrees needed to display image upright.
  static int exifToClockwiseDegrees(int orientation) {
    switch (orientation) {
      case 3:
        return 180;
      case 6:
        return 90;
      case 8:
        return 270;
      default:
        return 0;
    }
  }
}
