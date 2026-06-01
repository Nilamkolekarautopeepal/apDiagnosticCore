import 'dart:typed_data';

class SectorData {
  int startAddress;    // Equivalent to UInt32 (Dart ints are 64-bit)
  int noOfBytes;       // Equivalent to UInt32
  Uint8List byteArray; // Equivalent to byte[] (More memory efficient in Dart)
  int sectorChecksum;  // Equivalent to UInt16

  SectorData({
    required this.startAddress,
    required this.noOfBytes,
    required this.byteArray,
    required this.sectorChecksum,
  });
}