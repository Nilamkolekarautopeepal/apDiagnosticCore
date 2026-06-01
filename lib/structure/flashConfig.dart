// Dart uses classes for C# structs
class FlashConfig {
  // Add fields here as you define them in your C# struct
  
  FlashConfig();
}

enum EraseSectorEnum {
  none,
  eraseAllAtOnce,
  eraseBySector,
  eraseAllAtOnceWoAddr,
}

enum ChecksumSectorEnum {
  none,
  compare2ByteSimpleAddBySector,
  compareCrc16CcittBySector,
  computeBySector,
  noChecksumBySector,
  compareBySector,
  noChecksum,
  compareBySectorWoAddrCrcCcitt16,
}