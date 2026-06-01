enum ReadDTCIndex {

  // ignore: constant_identifier_names
  UDS_3BYTE_DTC,
  UDS_2BYTE12_DTC,
  UDS_2BYTE13_DTC,
  KWP_2BYTE_DTC,
  GENERIC_OBD,
  UDS,
  KWP_PRIMITIVE,
  UDS_J1939,
  UDS_GCU,
}

enum ClearDTCIndex {
  
  // ignore: constant_identifier_names
  UDS_4BYTES,
  UDS_3BYTES,
  GENERIC_OBD,
  KWP,
  KWP_PRIMITIVE,
  UDS_4BYTES_EXTENDED,
  UDS_3BYTES_EXTENDED,
}
