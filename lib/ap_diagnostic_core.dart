// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:ap_dongle_commcore/ap_dongle_commcore.dart';
// import 'package:ap_dongle_commcore/model/responseArrayStatusModel.dart';
// import 'package:ap_dongle_diagnostic_core/enums/readDTCIndex.dart';
// import 'package:ap_dongle_diagnostic_core/enums/readParameterIndex.dart';
// import 'package:ap_dongle_diagnostic_core/enums/writeParameterIndex.dart';
// import 'package:ap_dongle_diagnostic_core/model/flashingMatrixModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/freezeFrameModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/loopModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/readDtcResponseModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/readMappedPidModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/readParameterPidModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/readParameterResponse.dart';
// import 'package:ap_dongle_diagnostic_core/model/writeParameterPidModel.dart';
// import 'package:ap_dongle_diagnostic_core/model/writeParameterResponse.dart';
// import 'package:ap_dongle_diagnostic_core/structure/flashConfig.dart';
// import 'package:ecu_seedkeypcl_core/ecu_seedkeypcl_core.dart';

// class UDSDiagnostic {
//   DongleCommWin? dongleComm;
//   ECUCalculateSeedkey? calculateSeedkey;

//   UDSDiagnostic({this.dongleComm, this.calculateSeedkey});

//   Future<ApReadDtcResponseModel> readDTC(ReadDTCIndex readDtcIndex) async {
//     String returnStatus = "ECU_ERROR";
//     List<List<String>> dtcArray = [];
//     int dtcCounter = 0;

//     try {
//       dongleComm!.saveLog("------Start Read Dtc: $readDtcIndex------\n");

//       // ─── CASE 1: UDS & KWP 2-BYTE/3-BYTE ──────────────────────────────────────
//       if ([
//         ReadDTCIndex.KWP_2BYTE_DTC,
//         ReadDTCIndex.UDS_2BYTE12_DTC,
//         ReadDTCIndex.UDS_2BYTE13_DTC,
//         ReadDTCIndex.UDS_3BYTE_DTC,
//       ].contains(readDtcIndex)) {
//         int frameLength = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC) ? 4 : 3;
//         String dtcFunction = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC)
//             ? "1800FFFF"
//             : "1902FF";

//         final response = await dongleComm!.canTxRx(frameLength, dtcFunction);
//         String responseStatus = response.ecuResponseStatus ?? "";
//         final rxArray = response.actualDataBytes;

//         if ((responseStatus == "NOERROR" || responseStatus == "NO_ERROR") &&
//             rxArray != null) {
//           returnStatus = "NO_ERROR";

//           // ✅ FIX: UDS always 4 bytes per DTC (3 code + 1 status)
//           int step = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC) ? 3 : 4;
//           int startIdx = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC) ? 2 : 3;

//           if (rxArray.length > startIdx) {
//             int noOfDtcCalculated = (rxArray.length - startIdx) ~/ step;

//             for (int i = 0; i < noOfDtcCalculated; i++) {
//               int p = startIdx + (i * step);
//               if (p + 3 >= rxArray.length) break;

//               // ✅ FIX: Skip padding/null entries
//               if (rxArray[p] == 0x00 &&
//                   rxArray[p + 1] == 0x00 &&
//                   rxArray[p + 2] == 0x00)
//                 continue;

//               int typeBits = (rxArray[p] & 0xC0) >> 6;
//               String type = ["P", "C", "B", "U"][typeBits];

//               String h0 = (rxArray[p] & 0x3F)
//                   .toRadixString(16)
//                   .padLeft(2, '0')
//                   .toUpperCase();
//               String h1 = rxArray[p + 1]
//                   .toRadixString(16)
//                   .padLeft(2, '0')
//                   .toUpperCase();
//               String h2 = rxArray[p + 2]
//                   .toRadixString(16)
//                   .padLeft(2, '0')
//                   .toUpperCase();

//               String fullCode = "";
//               if (readDtcIndex == ReadDTCIndex.UDS_3BYTE_DTC) {
//                 fullCode = "$type$h0$h1-$h2";
//               } else if (readDtcIndex == ReadDTCIndex.UDS_2BYTE13_DTC) {
//                 fullCode = "$type$h0$h2";
//               } else {
//                 fullCode = "$type$h0$h1";
//               }

//               // ✅ FIX: 0x50 status byte handling (stored/confirmed not currently failing)
//               int sByte = rxArray[p + 3];
//               String dtcStatusDesc;

//               if ((sByte & 0x01) != 0) {
//                 dtcStatusDesc = "Active";
//               } else if ((sByte & 0x08) != 0) {
//                 dtcStatusDesc = "History";
//               } else if ((sByte & 0x04) != 0) {
//                 dtcStatusDesc = "Pending";
//               } else if ((sByte & 0x20) != 0) {
//                 // 0x50 = testNotCompletedSinceLastClear — treat as History
//                 dtcStatusDesc = "History";
//               } else if (sByte == 0x00) {
//                 continue; // skip null status
//               } else {
//                 dtcStatusDesc = "History"; // any other stored status
//               }

//               dtcArray.add([fullCode, dtcStatusDesc]);
//               dtcCounter++;
//             }
//           }
//         } else {
//           returnStatus = responseStatus.isEmpty
//               ? "ECUERROR_NORESPONSEFROMECU"
//               : responseStatus;
//         }
//       }
//       // ─── CASE 2: GENERIC OBD ──────────────────────────────────────────────────
//       else if (readDtcIndex == ReadDTCIndex.GENERIC_OBD) {
//         var resp03 = await dongleComm!.canTxRx(1, "03");
//         if (resp03.ecuResponseStatus == "NOERROR") {
//           var resp07 = await dongleComm!.canTxRx(1, "07");
//           if (resp07.ecuResponseStatus == "NOERROR") {
//             returnStatus = "NO_ERROR";

//             void processOBD(List<int>? d, String label) {
//               if (d == null || d.length < 2) return;
//               int count = d[1];
//               for (int i = 0; i < count; i++) {
//                 int p = (i * 2) + 2;
//                 if (p + 1 >= d.length) break;
//                 int high = d[p];
//                 String t = ["P", "C", "B", "U"][(high & 0xC0) >> 6];
//                 String code =
//                     (high & 0x3F)
//                         .toRadixString(16)
//                         .padLeft(2, '0')
//                         .toUpperCase() +
//                     d[p + 1].toRadixString(16).padLeft(2, '0').toUpperCase();
//                 dtcArray.add(["$t$code", label]);
//                 dtcCounter++;
//               }
//             }

//             processOBD(resp03.actualDataBytes, "Current");
//             processOBD(resp07.actualDataBytes, "Pending");
//           }
//         }
//       }
//       // ─── CASE 3: J1939 (SPN/FMI) ──────────────────────────────────────────────
//       else if (readDtcIndex == ReadDTCIndex.UDS_J1939) {
//         var resp = await dongleComm!.canTxRx(3, "1902FF");
//         if (resp.ecuResponseStatus == "NOERROR" &&
//             resp.actualDataBytes != null) {
//           returnStatus = "NO_ERROR";
//           var data = resp.actualDataBytes!;
//           int count = (data.length - 3) ~/ 4;
//           for (int i = 0; i < count; i++) {
//             int p = 3 + (i * 4);
//             if (p + 3 >= data.length) break;
//             int spn =
//                 data[p] | (data[p + 1] << 8) | ((data[p + 2] & 0xE0) << 11);
//             int fmi = data[p + 2] & 0x1F;
//             int s = data[p + 3];
//             String statusTxt = (s & 0x01 != 0)
//                 ? "Active"
//                 : ((s & 0x08 != 0) ? "History" : "Stored");

//             dtcArray.add([spn.toString(), statusTxt, fmi.toString()]);
//             dtcCounter++;
//           }
//         }
//       }
//       // ─── CASE 4: UDS GCU (Decimal ID) ─────────────────────────────────────────
//       else if (readDtcIndex == ReadDTCIndex.UDS_GCU) {
//         var resp = await dongleComm!.canTxRx(3, "1902FF");
//         if (resp.ecuResponseStatus == "NOERROR" &&
//             resp.actualDataBytes != null) {
//           returnStatus = "NO_ERROR";
//           var data = resp.actualDataBytes!;
//           int count = (data.length - 3) ~/ 4;
//           for (int i = 0; i < count; i++) {
//             int p = 3 + (i * 4);
//             if (p + 3 >= data.length) break;
//             int id = (data[p] << 16) | (data[p + 1] << 8) | data[p + 2];
//             String desc = "Unknown";
//             switch (data[p + 3]) {
//               case 0xF1:
//                 desc = "Active Warning";
//                 break;
//               case 0xF2:
//                 desc = "Inactive Warning";
//                 break;
//               case 0xF3:
//                 desc = "Active Shutdown";
//                 break;
//               case 0xF4:
//                 desc = "Inactive Shutdown";
//                 break;
//             }
//             dtcArray.add([id.toString(), desc]);
//             dtcCounter++;
//           }
//         }
//       }
//       // ─── CASE 5: KWP PRIMITIVE ────────────────────────────────────────────────
//       else if (readDtcIndex == ReadDTCIndex.KWP_PRIMITIVE) {
//         var resp = await dongleComm!.canTxRx(1, "13");
//         if (resp.ecuResponseStatus == "NOERROR" &&
//             resp.actualDataBytes != null) {
//           returnStatus = "NO_ERROR";
//           int count = resp.actualDataBytes![1];
//           for (int i = 0; i < count; i++) {
//             int p = (i * 2) + 2;
//             if (p + 1 >= resp.actualDataBytes!.length) break;
//             int b1 = resp.actualDataBytes![p];
//             String t = ["P", "C", "B", "U"][(b1 & 0xC0) >> 6];
//             String code =
//                 (b1 & 0x3F).toRadixString(16).padLeft(2, '0').toUpperCase() +
//                 resp.actualDataBytes![p + 1]
//                     .toRadixString(16)
//                     .padLeft(2, '0')
//                     .toUpperCase();
//             dtcArray.add(["$t$code", "Stored"]);
//             dtcCounter++;
//           }
//         }
//       }
//     } catch (ex) {
//       print("Error decoding DTC: $ex");
//       returnStatus = "DECODING_ERROR";
//     }

//     return ApReadDtcResponseModel(
//       dtcs: dtcArray,
//       noOfDtc: dtcCounter,
//       status: returnStatus,
//     );
//   }

//   Future<FreezeFrameResponseModel> getFreezeFrame(
//     String dtcCode,
//     FreezeFrameModel freezeFrame,
//     List<ReadParameterPID>? envSnapshotList,
//   ) async {
//     FreezeFrameResponseModel freezeFrameResponseModel =
//         FreezeFrameResponseModel();
//     List<FreezeFrame> dummyList = [];

//     try {
//       dongleComm!.saveLog("------Start Read Dtc ($dtcCode)------\n");

//       String completeCode = "";
//       if (dtcCode.contains("-")) {
//         var parts = dtcCode.split('-');
//         completeCode = parts[0] + parts[1];
//       } else {
//         completeCode = dtcCode;
//       }

//       int dtcTypeBits = 0;
//       if (completeCode.startsWith('P')) {
//         dtcTypeBits = 0x00;
//       } else if (completeCode.startsWith('C')) {
//         dtcTypeBits = 0x01;
//       } else if (completeCode.startsWith('B')) {
//         dtcTypeBits = 0x02;
//       } else if (completeCode.startsWith('U')) {
//         dtcTypeBits = 0x03;
//       }

//       // Remove the prefix character (P, C, B, or U)
//       String hexCodeOnly = completeCode.substring(1);

//       // Convert hex string to byte list
//       Uint8List frame = hexToBytes(hexCodeOnly);

//       // Apply DTC type bits to the first byte
//       frame[0] = (frame[0] | (dtcTypeBits << 6));

//       // Request SID 19 04 (ReadDTCFreezeFrameData)
//       var responseBytes = await dongleComm!.canTxRx(
//         frame.length + 3,
//         "1904${byteArrayToHex(frame)}FF",
//       );

//       String? ecuStatus = responseBytes.ecuResponseStatus;

//       if (ecuStatus == null || ecuStatus.isEmpty) {
//         freezeFrameResponseModel.status = "Status not found.";
//       } else if (ecuStatus == "NOERROR") {
//         int index = 8; // Starting index based on your printic
//         Uint8List? actualData = responseBytes.actualDataBytes;
//         // 1. Check if the list exists before starting
//         if (freezeFrame.freezeFrameCode != null) {
//           for (var item in freezeFrame.freezeFrameCode!) {
//             FreezeFrame freeze = FreezeFrame(
//               code: item.code,
//               priority: item.priority,
//             );

//             try {
//               int itemCode = int.parse(item.code ?? '', radix: 16);
//               int highByte = (itemCode & 0xFF00) >> 8;
//               int lowByte = (itemCode & 0x00FF);

//               // Ensure actualData isn't null before entering nested loops
//               if (actualData != null) {
//                 bool found = false;

//                 // First search pass
//                 for (; index < actualData.length - 1; index++) {
//                   if (actualData[index] == highByte &&
//                       actualData[index + 1] == lowByte) {
//                     freeze.value = _getFreezeValue(responseBytes, item, index);
//                     found = true;
//                     break;
//                   }
//                 }

//                 // Second search pass from start if not found
//                 if (!found) {
//                   for (index = 0; index < actualData.length - 1; index++) {
//                     if (actualData[index] == highByte &&
//                         actualData[index + 1] == lowByte) {
//                       freeze.value = _getFreezeValue(
//                         responseBytes,
//                         item,
//                         index,
//                       );
//                       break;
//                     }
//                   }
//                 }
//               }
//             } catch (ex) {
//               freeze.value = "Exception";
//             }

//             // Advance index safely
//             index += (2 + (item.length ?? 0));
//             dummyList.add(freeze);
//           }
//         }

//         // Process Environmental Snapshots
//         if (envSnapshotList != null && envSnapshotList.isNotEmpty) {
//           for (var pid in envSnapshotList) {
//             try {
//               int receivedCode = 0;
//               int itemCode = int.parse(pid.pid ?? '', radix: 16);
//               int highByte = (itemCode & 0xFF00) >> 8;
//               int lowByte = (itemCode & 0x00FF);

//               for (; index < actualData!.length - 1; index++) {
//                 if (actualData[index] == highByte &&
//                     actualData[index + 1] == lowByte) {
//                   receivedCode =
//                       (actualData[index] << 8) | actualData[index + 1];
//                   break;
//                 }
//               }

//               if (receivedCode == 0) index = 0;

//               if (receivedCode == itemCode) {
//                 // Prepare subset of data for conversion
//                 // The (pid.totalLen ?? 0) ensures that if totalLen is null, it treats it as 0.
//                 Uint8List subArray = actualData.sublist(
//                   index,
//                   index + (pid.totalLen ?? 0) + 2,
//                 );
//                 ResponseArrayStatus statusObj = ResponseArrayStatus(
//                   actualDataBytes: subArray,
//                   ecuResponseStatus: "NOERROR",
//                 );

//                 var pidResponse = await pidConvertResponse(statusObj, pid);

//                 if (pidResponse.status == "NOERROR") {
//                   for (var variable in pidResponse.variables ?? []) {
//                     dummyList.add(
//                       FreezeFrame(code: pid.pid, value: variable.responseValue),
//                     );
//                   }
//                 } else {
//                   // Adding ?? [] ensures that if pid.variables is null, the loop simply doesn't run.
//                   for (var _ in pid.variables ?? []) {
//                     dummyList.add(
//                       FreezeFrame(code: pid.pid, value: pidResponse.status),
//                     );
//                   }
//                 }
//               } else {
//                 for (var _ in pid.variables ?? []) {
//                   dummyList.add(FreezeFrame(code: pid.pid, value: "NA"));
//                 }
//               }
//             } catch (ex) {
//               for (var _ in pid.variables ?? []) {
//                 dummyList.add(FreezeFrame(code: pid.pid, value: "Exception"));
//               }
//             }
//           }
//         }

//         freezeFrameResponseModel.status = ecuStatus;
//         freezeFrameResponseModel.dtcs = dummyList;
//       } else {
//         freezeFrameResponseModel.status = ecuStatus;
//       }
//     } catch (ex) {
//       freezeFrameResponseModel.status = ex.toString();
//     }

//     return freezeFrameResponseModel;
//   }

//   String byteArrayToHex(Uint8List bytes) {
//     return bytes
//         .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
//         .join('');
//   }

//   String _getFreezeValue(
//     ResponseArrayStatus responseBytes,
//     FreezeFrameCode item,
//     int index,
//   ) {
//     String retValue = "";

//     // Get received code (PID) from the first two bytes at index
//     int receivedCode =
//         (responseBytes.actualDataBytes![index] << 8) |
//         responseBytes.actualDataBytes![index + 1];

//     // Parse the expected item code from hex string
//     int itemCode = int.parse(item.code ?? "0", radix: 16);

//     if (receivedCode == itemCode) {
//       int len = item.length ?? 0;
//       int startPos = index + 2 + (item.bytePosition ?? 1) - 1;

//       // Extract the raw value bytes
//       Uint8List value = Uint8List.fromList(
//         responseBytes.actualDataBytes!.sublist(startPos, startPos + len),
//       );

//       if (item.messageType == "CONTINUOUS" ||
//           item.messageType == "IEEE754_FLOAT") {
//         if (len <= 4) {
//           // Create a 4-byte buffer for conversion (equivalent to Resize in C#)
//           Uint8List buffer = Uint8List(4);

//           // C# uses Array.Reverse + BitConverter (which is Little Endian)
//           // In Dart, we can just read Big Endian directly or fill the buffer
//           for (int i = 0; i < value.length; i++) {
//             buffer[3 - i] = value[value.length - 1 - i];
//           }

//           ByteData bd = ByteData.sublistView(buffer);
//           int unsignedPidIntValue = bd.getUint32(0, Endian.little);

//           if (item.messageType == "CONTINUOUS") {
//             double floatPidValue =
//                 (unsignedPidIntValue * (item.resolution ?? 1.0)) +
//                 (item.offset ?? 0.0);
//             retValue = floatPidValue
//                 .toStringAsFixed(3)
//                 .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
//             // Note: replaceAll printic above mimics the "0.###" format
//           } else {
//             // IEEE754 Float
//             double floatValue = bd.getFloat32(0, Endian.little);
//             double floatPidValue =
//                 (floatValue * (item.resolution ?? 1.0)) + (item.offset ?? 0.0);
//             retValue = floatPidValue
//                 .toStringAsFixed(3)
//                 .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
//           }
//         }
//       } else if (item.messageType == "ASCII") {
//         retValue = utf8.decode(value, allowMalformed: true);
//       } else if (item.messageType == "BCD" || item.messageType == "HEX") {
//         retValue = value
//             .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
//             .join("");
//       } else if (item.messageType == "ENUMRATED") {
//         Uint8List buffer = Uint8List(4);
//         for (int i = 0; i < value.length; i++) {
//           buffer[3 - i] = value[value.length - 1 - i];
//         }
//         ByteData bd = ByteData.sublistView(buffer);
//         int unsignedPidIntValue = bd.getUint32(0, Endian.little);

//         if (item.bitcoded == true) {
//           int lsbStartBit = item.startBit ?? 1;
//           int mask = 0;
//           for (int x = 0; x < (item.noofBits ?? 0); x++) {
//             mask |= (0x01 << (lsbStartBit - 1));
//             lsbStartBit++;
//           }
//           unsignedPidIntValue =
//               (unsignedPidIntValue & mask) >> ((item.startBit ?? 1) - 1);
//         }

//         retValue = unsignedPidIntValue.toString();

//         if (item.freezeFrameMessages != null) {
//           for (var msg in item.freezeFrameMessages!) {
//             double? code = double.tryParse(msg.code ?? "");
//             if (code != null && code.toInt() == unsignedPidIntValue) {
//               retValue = msg.message ?? "";
//               break;
//             }
//           }
//         }
//       }
//     } else {
//       retValue = "NA";
//     }

//     return retValue;
//   }

//   Future<List<ReadParameterResponseIvn>> ivnReadParameters(
//     int noOfParameters,
//     List<IVNSelectedPID> readParameterCollection,
//   ) async {
//     List<ReadParameterResponseIvn> databyteArray = [];

//     try {
//       String dataValue = "";

//       // Outer loop through collection
//       for (int i = 0; i < readParameterCollection.length; i++) {
//         // Accessing first element's frame_ids as per C# printic
//         var frameIds = readParameterCollection.first.frameIds ?? [];

//         for (var item in frameIds) {
//           var getivnframe = await dongleComm!.canIvnRxFrame(item.framId ?? '');

//           if (getivnframe.ecuResponseStatus == "NOERROR") {
//             var pidName = item.pidDescription;
//             var unit = item.unit;
//             String pidType = item.messageType.toString();
//             int pidStartByte = int.parse(item.startByte.toString());
//             int pidNoOfBytes = int.parse(item.byte.toString());
//             var pidBitcoded = item.bitCoded;

//             int pidStartBit = 0;
//             int pidNoOfBits = 0;

//             if (item.bitCoded != "0") {
//               pidStartBit = int.parse(item.startBit.toString());
//               pidNoOfBits = int.parse(item.noOfBits.toString());
//             }

//             double pidResolution = double.parse(item.resolution.toString());
//             double pidOffset = double.parse(item.offset.toString());
//             Uint8List actualFrameBytes = Uint8List.fromList(
//               getivnframe.actualFrameBytes as List<int>,
//             );

//             if (pidType.contains("CONTINUOUS")) {
//               print("---START CONTINUOUS--");
//               int unsignedPidIntValue = 0;

//               // Handle Endianness
//               if (item.endian.toString().contains("LITTLE")) {
//                 // Reverse the specific range in the byte array
//                 List<int> subList = actualFrameBytes.sublist(
//                   pidStartByte - 1,
//                   pidStartByte - 1 + pidNoOfBytes,
//                 );
//                 List<int> reversed = subList.reversed.toList();
//                 actualFrameBytes.setRange(
//                   pidStartByte - 1,
//                   pidStartByte - 1 + pidNoOfBytes,
//                   reversed,
//                 );
//               }

//               // Construct Integer from Bytes
//               for (int l = 0; l < pidNoOfBytes; l++) {
//                 unsignedPidIntValue |=
//                     (actualFrameBytes[pidStartByte - 1 + l] <<
//                     ((pidNoOfBytes - 1 - l) * 8));
//               }

//               // Bitwise Masking
//               if (pidBitcoded == "1") {
//                 if (pidNoOfBytes == 1) {
//                   int mask = 0;
//                   int tempStartBit = pidStartBit;
//                   for (int x = 0; x < pidNoOfBits; x++) {
//                     mask |= (1 << (8 - tempStartBit));
//                     tempStartBit++;
//                   }
//                   unsignedPidIntValue =
//                       (unsignedPidIntValue & mask) >>
//                       ((pidNoOfBytes * 8) - pidStartBit - pidNoOfBits + 1);
//                 } else {
//                   int mask =
//                       ((pow(16, pidNoOfBytes * 2).toInt() - 1)) >>
//                       ((pidNoOfBytes * 8) - pidNoOfBits - pidStartBit + 1);
//                   unsignedPidIntValue =
//                       (unsignedPidIntValue >>
//                           ((pidNoOfBytes * 8) -
//                               pidNoOfBits -
//                               pidStartBit +
//                               1)) &
//                       mask;
//                 }
//               }

//               double floatPidValue = 0.0;

//               // Handle Signed vs Unsigned (2's Complement)
//               if (pidType == "CONTINUOUS_2S_COMPLEMENT" ||
//                   item.numType == "SIGNED") {
//                 int signedValue = unsignedPidIntValue;

//                 // Manual sign extension based on byte count
//                 if (pidNoOfBytes == 1) {
//                   signedValue = Int8List.fromList([unsignedPidIntValue])[0];
//                 } else if (pidNoOfBytes == 2) {
//                   signedValue = Int16List.fromList([unsignedPidIntValue])[0];
//                 } else {
//                   // For 3 or 4 bytes, treat as 32-bit signed
//                   signedValue = Int32List.fromList([unsignedPidIntValue])[0];
//                 }
//                 floatPidValue = (signedValue * pidResolution) + pidOffset;
//               } else {
//                 floatPidValue =
//                     (unsignedPidIntValue * pidResolution) + pidOffset;
//               }

//               dataValue = floatPidValue.toString();
//               print("---END CONTINUOUS--");
//             } else if (pidType == "ASCII") {
//               print("---START ASCII--");
//               List<int> outputlivepararray = [];
//               for (int k = 0; k < pidNoOfBytes; k++) {
//                 outputlivepararray.add(actualFrameBytes[pidStartByte - 1 + k]);
//               }
//               // Reverse to match C# printic: outputlivepararray[pidNoOfBytes - 1 - k]
//               dataValue = utf8.decode(
//                 outputlivepararray.reversed.toList(),
//                 allowMalformed: true,
//               );
//               if (dataValue.contains('\x00')) dataValue = "0";
//               print("---END ASCII--");
//             } else if (pidType == "BCD") {
//               print("---START BCD--");
//               List<int> outputlivepararray = [];
//               for (int k = 0; k < pidNoOfBytes; k++) {
//                 outputlivepararray.add(actualFrameBytes[pidStartByte - 1 + k]);
//               }
//               // Convert to Hex String as BCD replacement
//               dataValue = outputlivepararray.reversed
//                   .map((b) => b.toRadixString(16).padLeft(2, '0'))
//                   .join("");
//               print("---END BCD--");
//             } else if (pidType == "ENUMRATED") {
//               int unsignedPidIntValue = 0;
//               for (int m = 0; m < pidNoOfBytes; m++) {
//                 unsignedPidIntValue |=
//                     (actualFrameBytes[pidStartByte - 1 + m] <<
//                     ((pidNoOfBytes - 1 - m) * 8));
//               }

//               if (pidBitcoded == "1") {
//                 int startBit = pidStartBit;
//                 int mask = 0;
//                 for (int x = 0; x < pidNoOfBits; x++) {
//                   mask |= (1 << (8 - startBit));
//                   if (item.endian.toString().contains("LITTLE")) {
//                     startBit--;
//                   } else {
//                     startBit++;
//                   }
//                 }
//                 unsignedPidIntValue =
//                     (unsignedPidIntValue & mask) >>
//                     ((pidNoOfBytes * 8) - pidStartBit - pidNoOfBits + 1);
//               }

//               dataValue = unsignedPidIntValue.toString();

//               // Map code to message if available
//               var messages = item.frameOfPidMessage ?? [];
//               for (var msg in messages) {
//                 if (int.tryParse(msg.code.toString()) == unsignedPidIntValue) {
//                   dataValue = msg.message ?? '';
//                 }
//               }
//             }

//             databyteArray.add(
//               ReadParameterResponseIvn(
//                 pidName: pidName,
//                 responseValue: dataValue,
//                 status: "NO_ERROR",
//                 unit: unit,
//               ),
//             );
//           } else if (getivnframe.ecuResponseStatus ==
//               "ECUERROR_NORESPONSEFROMECU") {
//             databyteArray.add(
//               ReadParameterResponseIvn(
//                 pidName: item.pidDescription,
//                 responseValue: "ERR",
//                 status: "NoResponse",
//                 unit: "",
//               ),
//             );
//           } else {
//             databyteArray.add(
//               ReadParameterResponseIvn(
//                 pidName: item.pidDescription,
//                 responseValue: "ERR",
//                 status: "ERROR",
//                 unit: "",
//               ),
//             );
//           }
//         }
//       }
//     } catch (e) {
//       print("Error in IVN_ReadParameters: $e");
//     }

//     return databyteArray;
//   }

//   String byteArrayToString(Uint8List ba) {
//     return ba
//         .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
//         .join('');
//   }

//   /// Converts a Hex String to a byte array, handling odd lengths by padding
//   Uint8List hexStringToByteArray(String hex) {
//     // Remove spaces equivalent to hex.Replace(" ", "")
//     String cleanHex = hex.replaceAll(' ', '');

//     // Handle odd lengths by padding with a leading zero
//     if (cleanHex.length % 2 != 0) {
//       cleanHex = '0' + cleanHex;
//     }

//     int numberChars = cleanHex.length;
//     Uint8List bytes = Uint8List(numberChars ~/ 2);

//     for (int i = 0; i < numberChars; i += 2) {
//       bytes[i ~/ 2] = int.parse(cleanHex.substring(i, i + 2), radix: 16);
//     }

//     return bytes;
//   }

//   /// A strict Hex to Bytes converter (expects even length)
//   Uint8List hexToBytes(String input) {
//     Uint8List result = Uint8List(input.length ~/ 2);
//     for (int i = 0; i < result.length; i++) {
//       result[i] = int.parse(input.substring(2 * i, 2), radix: 16);
//     }
//     return result;
//   }

//   ClearDTCIndex _currentClearDTCIndex = ClearDTCIndex.KWP;

//   /// Clears Diagnostic Trouble Codes based on the provided index
//   Future<dynamic> clearDTC(
//     ClearDTCIndex readDtcIndex,
//     SeedKeyIndexType seedKeyIndex,
//     WriteParameterIndex writeParameterIndex,
//   ) async {
//     _currentClearDTCIndex = readDtcIndex;
//     dynamic responseBytes;

//     dongleComm!.saveLog("------Start Clear Dtc------\n");

//     if (_currentClearDTCIndex == ClearDTCIndex.UDS_4BYTES) {
//       int frameLength = 4;
//       responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFFFF");
//     } else if (_currentClearDTCIndex == ClearDTCIndex.UDS_3BYTES) {
//       int frameLength = 3;
//       responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFF");
//     } else if (_currentClearDTCIndex == ClearDTCIndex.GENERIC_OBD) {
//       int frameLength = 1;
//       responseBytes = await dongleComm!.canTxRx(frameLength, "04");
//     } else if (_currentClearDTCIndex == ClearDTCIndex.KWP_PRIMITIVE) {
//       int frameLength = 1;
//       responseBytes = await dongleComm!.canTxRx(frameLength, "14");
//     } else if (_currentClearDTCIndex == ClearDTCIndex.UDS_3BYTES_EXTENDED) {
//       responseBytes = await enterExtendedSession(
//         writeParameterIndex,
//         seedKeyIndex,
//       );

//       // Dart uses 'is' for type checking. If true, 'responseBytes' is promoted to ResponseArrayStatus
//       if (responseBytes is ResponseArrayStatus &&
//           responseBytes.ecuResponseStatus == "NOERROR") {
//         int frameLength = 3;
//         responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFF");
//       }
//     } else if (_currentClearDTCIndex == ClearDTCIndex.UDS_4BYTES_EXTENDED) {
//       responseBytes = await enterExtendedSession(
//         writeParameterIndex,
//         seedKeyIndex,
//       );

//       if (responseBytes is ResponseArrayStatus &&
//           responseBytes.ecuResponseStatus == "NOERROR") {
//         int frameLength = 4;
//         responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFFFF");
//       }
//     }

//     return responseBytes;
//   }

//   Future<List<String>?> genericOBDSupportedPidList() async {
//     try {
//       // In Dart, we use a List<String> which can grow dynamically
//       List<String> supportedPid = [];

//       // Loop through the PID range (0x00 to 0x0B as per your C# loop)
//       for (int i = 0; i < 0x0c; i++) {
//         int frameLength = 2;

//         // Convert i to a 2-character Hex string
//         String pidHex = i.toRadixString(16).padLeft(2, '0').toUpperCase();

//         var response = await dongleComm!.canTxRx(frameLength, "01$pidHex");

//         // Check for positive response (Service 01 response is 0x41)
//         if (response.ecuResponseStatus == "NOERROR" &&
//             response.actualDataBytes!.isNotEmpty &&
//             response.actualDataBytes![0] == 0x41) {
//           int cmpResp = 0;
//           Uint8List? data = response.actualDataBytes;
//           int len = data!.length;

//           // Construct a 32-bit integer from the variable length response bytes
//           // Note: Data typically starts at index 2 for OBD PIDs (Mode 01, PID i)
//           if (len == 2) {
//             /* Do Nothing */
//           } else if (len == 3) {
//             cmpResp = (data[2] << 24);
//           } else if (len == 4) {
//             cmpResp = (data[2] << 24) | (data[3] << 16);
//           } else if (len == 5) {
//             cmpResp = (data[2] << 24) | (data[3] << 16) | (data[4] << 8);
//           } else if (len >= 6) {
//             cmpResp =
//                 (data[2] << 24) | (data[3] << 16) | (data[4] << 8) | data[5];
//           }

//           // Masking printic to find supported PIDs (32 bits per availability PID)
//           for (int j = 31; j >= 0; j--) {
//             // Check if the specific bit is set
//             if ((cmpResp & (1 << j)) != 0) {
//               // Calculate the PID number: i * 0x20 provides the base for the block
//               // (e.g., 0100 returns support for 01-20)
//               int pidVal = (i * 0x20) + (32 - j);

//               String supportedHex = pidVal
//                   .toRadixString(16)
//                   .padLeft(2, '0')
//                   .toUpperCase();
//               supportedPid.add("01$supportedHex");
//             }
//           }
//         }
//       }

//       return supportedPid.isEmpty ? null : supportedPid;
//     } catch (ex) {
//       return null;
//     }
//   }

//   Future<List<ReadParameterResponse>> readParameters(
//     int noOfParameters,
//     List<ReadParameterPID> readParameterCollection,
//   ) async {
//     List<ReadParameterResponse> databyteArray = [];
//     dongleComm!.saveLog("------Start Read Pid------\n");

//     for (int i = 0; i < readParameterCollection.length; i++) {
//       var pidItem = readParameterCollection[i];

//       // Total length of command
//       var frameLength = pidItem.pid!.length ~/ 2;
//       String dataValue = "";

//       print(
//         "---------------------START LOOP PID NAME-------------------------------------${pidItem.pid}\n",
//       );
//       dongleComm!.saveLog("------Start Read Pid (${pidItem.pid})------");

//       // Send the parameter ID to the ECU
//       var pidResponse = await dongleComm!.canTxRx(
//         frameLength,
//         pidItem.pid ?? '',
//       );

//       try {
//         if (pidResponse.ecuResponseStatus == "NOERROR") {
//           var pidBytesResponseString = byteArrayToString(
//             pidResponse.actualDataBytes!,
//           );
//           print("Response received = $pidBytesResponseString");

//           var status = pidResponse.ecuResponseStatus;
//           Uint8List rxArray = pidResponse.actualDataBytes!;
//           var inputLiveParaArray = readParameterCollection;

//           double? floatPidValue = 0;
//           var txFrameLength = frameLength;

//           // Initialize output array
//           Uint8List outputLiveParArray = Uint8List(
//             txFrameLength - 2 > 0 ? txFrameLength - 2 : 0,
//           );

//           if (status == "NOERROR") {
//             print("---NOERROR LOOP");
//             List<ReadParameterVariableResponse> variableResponses = [];

//             for (int k = 0; k < inputLiveParaArray[i].variables!.length; k++) {
//               var currentVar = inputLiveParaArray[i].variables![k];
//               print(
//                 "---------------------START LOOP VARIABLE NAME-------------------------------------${currentVar.pidName}",
//               );

//               if (currentVar.datatype == "CONTINUOUS" ||
//                   currentVar.datatype == "IEEE754_FLOAT") {
//                 print("---START CONTINUOUS--");
//                 int unsignedPidIntValue = 0;

//                 // 1. Provide a default for the loop condition
//                 for (int j = 0; j < (currentVar.noOfBytes ?? 0); j++) {
//                   // 2. Provide a default for the math (or use ! since the loop condition ensures it exists)
//                   int totalBytes = currentVar.noOfBytes ?? 0;
//                   int startByte = currentVar.startByte ?? 0;

//                   int shift = (totalBytes - 1 - j) * 8;
//                   int byteVal = rxArray[startByte + txFrameLength - 1 + j];

//                   unsignedPidIntValue |= (byteVal << shift);
//                 }
//                 if (currentVar.isBitcoded == true) {
//                   // Capture values safely at the start
//                   int startBit = currentVar.startBit ?? 0;
//                   int noofBits = currentVar.noofBits ?? 0;

//                   int lsbStartBit = startBit;
//                   int mask = 0;

//                   // Use the local 'noofBits' which is guaranteed to be a non-nullable 'int'
//                   for (int x = 0; x < noofBits; x++) {
//                     mask |= (0x01 << (lsbStartBit - 1));
//                     lsbStartBit++;
//                   }

//                   // Use the local 'startBit' here too
//                   unsignedPidIntValue =
//                       (unsignedPidIntValue & mask) >> (startBit - 1);
//                 }

//                 if (currentVar.readParameterIndex ==
//                         ReadParameterIndex.uds2sCompliment &&
//                     currentVar.offset == 1) {
//                   // Use ?? 1.0 as a fallback for resolution to avoid multiplying by null
//                   floatPidValue =
//                       (unsignedPidIntValue * (currentVar.resolution ?? 1.0));
//                 } else if (currentVar.datatype == "IEEE754_FLOAT") {
//                   // 1. Declare floatValue as a double
//                   var bd = ByteData(4)..setUint32(0, unsignedPidIntValue);
//                   double floatValue = bd.getFloat32(0);

//                   // 2. Use fallbacks for resolution (1.0) and offset (0.0)
//                   floatPidValue =
//                       (floatValue * (currentVar.resolution ?? 1.0)) +
//                       (currentVar.offset ?? 0.0);
//                 } else if (currentVar.numType == "SIGNED") {
//                   // Sign extension logic for 1, 2, or 3 bytes into a 32-bit signed int
//                   int signedPidIntValue = unsignedPidIntValue;

//                   // Use ?? 0 to ensure bitWidth isn't calculated on a null
//                   int noOfBytes = currentVar.noOfBytes ?? 0;
//                   int bitWidth = noOfBytes * 8;

//                   // Check if the sign bit is set (if bitWidth is 0, this skips correctly)
//                   if (bitWidth > 0 &&
//                       (unsignedPidIntValue & (1 << (bitWidth - 1))) != 0) {
//                     signedPidIntValue = unsignedPidIntValue - (1 << bitWidth);
//                   }

//                   // Handle null resolution and offset
//                   floatPidValue =
//                       (signedPidIntValue * (currentVar.resolution ?? 1.0)) +
//                       (currentVar.offset ?? 0.0);
//                 } else {
//                   // Logic for UNSIGNED
//                   floatPidValue =
//                       (unsignedPidIntValue * (currentVar.resolution ?? 1.0)) +
//                       (currentVar.offset ?? 0.0);
//                 }

//                 // Equivalent to ToString("0.###")
//                 String treePlace = floatPidValue
//                     .toStringAsFixed(3)
//                     .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
//                 dataValue = treePlace;
//                 print("---END CONTINUOUS--");
//               } else if (currentVar.datatype == "ASCII") {
//                 print("---START ASCII--");

//                 // Use ?? 0 or ?? 1 to ensure these aren't null before math operations
//                 int startOffset = currentVar.startByte ?? 1;
//                 int count = currentVar.noOfBytes ?? 0;

//                 int start = startOffset + txFrameLength - 1;

//                 // sublist(start, end) where end is start + count
//                 // We use Uint8List.fromList to ensure type consistency if sublist returns a standard List
//                 Uint8List subArray = rxArray.sublist(start, start + count);

//                 try {
//                   // ascii.decode comes from 'import dart:convert'
//                   // .replaceAll("\x00", "") removes null terminators common in automotive buffers
//                   dataValue = ascii
//                       .decode(subArray)
//                       .replaceAll("\x00", "")
//                       .trim();
//                 } catch (e) {
//                   dataValue = "Format Error";
//                 }

//                 print("---END ASCII--");
//               } else if (currentVar.datatype == "BCD" ||
//                   currentVar.datatype == "HEX") {
//                 print("---START BCD--");

//                 // 1. Safely handle potential nulls
//                 int startOffset = currentVar.startByte ?? 1;
//                 int byteCount = currentVar.noOfBytes ?? 0;

//                 int start = startOffset + txFrameLength - 1;

//                 // 2. Extract the sub-buffer
//                 Uint8List subArray = rxArray.sublist(start, start + byteCount);

//                 // 3. Remove trailing zeros (equivalent to TakeWhile in LINQ)
//                 // We use Uint8List.fromList to convert the Iterable back to the expected type
//                 var newData = Uint8List.fromList(
//                   subArray.takeWhile((value) => value != 0x00).toList(),
//                 );

//                 // 4. Convert the bytes to a Hex string
//                 dataValue = byteArrayToString(newData);

//                 print("---END BCD--");
//               } else if (currentVar.datatype == "ENUMRATED") {
//                 int pidIntValue = 0;

//                 // 1. Safe handling of nullable metadata
//                 int numBytes = currentVar.noOfBytes ?? 0;
//                 int startPos = currentVar.startByte ?? 1;

//                 for (int j = 0; j < numBytes; j++) {
//                   // Calculate index and shift safely
//                   int arrayIndex = startPos + txFrameLength - 1 + j;
//                   int shiftAmount = (numBytes - 1 - j) * 8;

//                   pidIntValue |= (rxArray[arrayIndex] << shiftAmount);
//                 }

//                 if (currentVar.isBitcoded == true) {
//                   // 2. Safe local copies for bitmasking
//                   int startBit = currentVar.startBit ?? 1;
//                   int bitCount = currentVar.noofBits ?? 0;

//                   int lsbStartBit = startBit;
//                   int mask = 0;

//                   for (int x = 0; x < bitCount; x++) {
//                     mask |= (0x01 << (lsbStartBit - 1));
//                     lsbStartBit++;
//                   }

//                   // Shift the masked value back to the LSB
//                   pidIntValue = (pidIntValue & mask) >> (startBit - 1);
//                 }

//                 dataValue = pidIntValue.toString();

//                 // 3. Map numeric code to its human-readable message
//                 if (currentVar.messages != null &&
//                     currentVar.messages!.isNotEmpty) {
//                   for (var msgItem in currentVar.messages!) {
//                     // Use double.tryParse to handle potential hex or numeric strings in the code field
//                     double? parsedCode = double.tryParse(msgItem.code ?? "");
//                     if (parsedCode != null &&
//                         parsedCode.toInt() == pidIntValue) {
//                       dataValue = msgItem.message ?? "";
//                       break; // Stop once the matching message is found
//                     }
//                   }
//                 }
//               } else if (currentVar.datatype == "IQA") {
//                 // Ensure we don't sublist past the array length
//                 if (rxArray.length > 3) {
//                   dataValue = decodeIQA(rxArray.sublist(3));
//                 } else {
//                   dataValue = "Invalid IQA Data";
//                 }
//               }

//               variableResponses.add(
//                 ReadParameterVariableResponse(
//                   pidName: currentVar.pidName,
//                   pidNumber: currentVar.pidNumber,
//                   responseValue: dataValue,
//                 ),
//               );
//               print(" END LOOP VARIABLE NAME = ${currentVar.pidName}");
//             }

//             databyteArray.add(
//               ReadParameterResponse(
//                 pidId: pidItem.pidId,
//                 status: pidResponse.ecuResponseStatus,
//                 dataArray: outputLiveParArray,
//                 pidName: "",
//                 variables: variableResponses,
//               ),
//             );
//           } else {
//             // ECU Error Case
//             List<ReadParameterVariableResponse> variableResponses = [];
//             // Adding ?? [] ensures the loop has a valid list to iterate over
//             for (var item in inputLiveParaArray[i].variables ?? []) {
//               variableResponses.add(
//                 ReadParameterVariableResponse(
//                   pidName: item.pidName,
//                   pidNumber: item.pidNumber,
//                   responseValue: dataValue,
//                 ),
//               );
//             }
//             databyteArray.add(
//               ReadParameterResponse(
//                 status: pidResponse.ecuResponseStatus,
//                 dataArray: outputLiveParArray,
//                 pidId: pidItem.pidId,
//                 pidName: "",
//                 variables: variableResponses,
//               ),
//             );
//           }
//         } else {
//           // ECU Positive Response Check failed
//           List<ReadParameterVariableResponse> variableResponses = [];
//           for (var item in readParameterCollection[i].variables ?? []) {
//             variableResponses.add(
//               ReadParameterVariableResponse(
//                 pidName: item.pidName,
//                 pidNumber: item.pidNumber,
//                 responseValue: dataValue,
//               ),
//             );
//           }
//           databyteArray.add(
//             ReadParameterResponse(
//               status: pidResponse.ecuResponseStatus,
//               pidId: pidItem.pidId,
//               pidName: "",
//               variables: variableResponses,
//             ),
//           );
//         }
//       } catch (e) {
//         databyteArray.add(ReadParameterResponse(status: e.toString()));
//       }
//       print(" END LOOP PID NAME = ${pidItem.pid}");
//     }
//     return databyteArray;
//   }

//   String decodeIQA(Uint8List rxData) {
//     try {
//       // IQA lookup table for alphanumeric characters
//       const String iqaLookup = "ABCDEFGHIKLMNOPTRSTUVWXYZ12345678";

//       // We expect at least 5 bytes to extract 7 characters
//       if (rxData.length < 5) return "Invalid Data";

//       List<int> iqaY = List.filled(7, 0);
//       Uint8List iqaX = Uint8List(7);

//       // Use 'rxData' (the parameter), not 'rxArray'
//       iqaY[0] = (rxData[0] & 0xF8) >> 3;
//       iqaY[1] =
//           (((rxData[0] & 0x07) << 8) | (rxData[1] & 0xC0)) >>
//           6; // Fixed: rxData[1]
//       iqaY[2] = (rxData[1] & 0x3E) >> 1;
//       iqaY[3] = (((rxData[1] & 0x01) << 8) | (rxData[2] & 0xF0)) >> 4;
//       iqaY[4] = (((rxData[2] & 0x0F) << 8) | (rxData[3] & 0x80)) >> 7;
//       iqaY[5] = (rxData[3] & 0x7C) >> 2;
//       iqaY[6] = (rxData[4] & 0xF8) >> 3;

//       // Map the unpacked 5-bit values to the lookup table
//       for (int i = 0; i < 7; i++) {
//         int index = iqaY[i];
//         if (index < iqaLookup.length) {
//           iqaX[i] = iqaLookup.codeUnitAt(index);
//         } else {
//           iqaX[i] = 63; // ASCII '?' for out of bounds
//         }
//       }

//       // Convert the mapped bytes back to a string
//       return ascii.decode(iqaX);
//     } catch (e) {
//       return "Error";
//     }
//   }

//   Future<List<MappedPIDResponse>> readMappedParameters(
//     List<ReadMappedPID> readParameterCollection,
//   ) async {
//     List<MappedPIDResponse> mappedPIDResponseList = [];

//     for (int i = 0; i < readParameterCollection.length; i++) {
//       var pidItem = readParameterCollection[i];

//       MappedPIDResponse mappedPIDResponse = MappedPIDResponse(
//         id: pidItem.id,
//         name: pidItem.name,
//         pidCode: pidItem.pidCode,
//         unit: pidItem.unit,
//       );

//       try {
//         // frameLength is PID hex length / 2
//         int frameLength = (pidItem.pidCode ?? "").length ~/ 2;
//         var pidResponse = await dongleComm!.canTxRx(
//           frameLength,
//           pidItem.pidCode ?? "",
//         );

//         if (pidResponse.ecuResponseStatus == "NOERROR") {
//           Uint8List? rxArray = pidResponse.actualDataBytes;

//           mappedPIDResponse.status = pidResponse.ecuResponseStatus;
//           mappedPIDResponse.values = [];

//           int totalLen = pidItem.totalLen ?? 0;
//           int itemLength = pidItem.length ?? 0;

//           for (int j = 0; j < totalLen; j += 2) {
//             try {
//               double? floatPidValue = 0;
//               int unsignedPidIntValue = 0;

//               // Construct integer from bytes
//               for (int k = 0; k < itemLength; k++) {
//                 int byteIndex = j + k + frameLength;
//                 if (byteIndex < rxArray!.length) {
//                   int shift = (itemLength - 1 - k) * 8;
//                   unsignedPidIntValue |= (rxArray[byteIndex] << shift);
//                 }
//               }

//               if (pidItem.numType == "SIGNED") {
//                 int signedPidIntValue = unsignedPidIntValue;
//                 int bitWidth = itemLength * 8;

//                 // Sign extension for 1, 2, or 3 byte signed integers
//                 if (bitWidth > 0 &&
//                     bitWidth < 64 &&
//                     (unsignedPidIntValue & (1 << (bitWidth - 1))) != 0) {
//                   signedPidIntValue = unsignedPidIntValue - (1 << bitWidth);
//                 }

//                 floatPidValue =
//                     (signedPidIntValue * (pidItem.resolution ?? 1.0)) +
//                     (pidItem.offset ?? 0.0);
//               } else {
//                 floatPidValue =
//                     (unsignedPidIntValue * (pidItem.resolution ?? 1.0)) +
//                     (pidItem.offset ?? 0.0);
//               }

//               // Formatting equivalent to ToString("0.###")
//               String formattedValue = floatPidValue
//                   .toStringAsFixed(3)
//                   .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");

//               mappedPIDResponse.values!.add(formattedValue);
//             } catch (ex) {
//               mappedPIDResponse.values!.add("Exception");
//             }
//           }
//           mappedPIDResponseList.add(mappedPIDResponse);
//         } else {
//           mappedPIDResponse.status = pidResponse.ecuResponseStatus;
//           mappedPIDResponseList.add(mappedPIDResponse);
//         }
//       } catch (exception) {
//         mappedPIDResponse.status = "Exception";
//         mappedPIDResponseList.add(mappedPIDResponse);
//       }
//     }
//     return mappedPIDResponseList;
//   }

//   Future<ReadParameterResponse> pidConvertResponse(
//     ResponseArrayStatus pidResponse,
//     ReadParameterPID pidItem,
//   ) async {
//     ReadParameterResponse databyteArray = ReadParameterResponse();

//     try {
//       String dataValue = "";

//       if (pidResponse.ecuResponseStatus == "NOERROR") {
//         var pidBytesResponseString = byteArrayToString(
//           pidResponse.actualDataBytes!,
//         );
//         print("Response received = $pidBytesResponseString");

//         Uint8List rxArray = pidResponse.actualDataBytes!;
//         var inputLiveParaArray = pidItem;

//         double? floatPidValue = 0;

//         // Note: Dart uses ~/ for integer division
//         var txFrameLen = 2;
//         Uint8List outputLiveParArray = Uint8List(
//           txFrameLen - 2 > 0 ? txFrameLen - 2 : 0,
//         );

//         print("---NOERROR LOOP");
//         List<ReadParameterVariableResponse> variableResponses = [];

//         for (int k = 0; k < (inputLiveParaArray.variables?.length ?? 0); k++) {
//           try {
//             var currentVar = inputLiveParaArray.variables![k];
//             print(
//               "---------------------START LOOP VARIABLE NAME-------------------------------------${currentVar.pidName}",
//             );

//             if (currentVar.datatype == "CONTINUOUS" ||
//                 currentVar.datatype == "IEEE754_FLOAT") {
//               print("---START CONTINUOUS--");
//               int unsignedPidIntValue = 0;
//               int noOfBytes = currentVar.noOfBytes ?? 0;

//               for (int j = 0; j < noOfBytes; j++) {
//                 int startByte = currentVar.startByte ?? 0;
//                 int byteVal = rxArray[startByte + txFrameLen - 1 + j];
//                 unsignedPidIntValue |= (byteVal << ((noOfBytes - 1 - j) * 8));
//               }

//               if (currentVar.isBitcoded == true) {
//                 int startBit = currentVar.startBit ?? 0;
//                 int noOfBits = currentVar.noofBits ?? 0;

//                 // C# logic: (unsignedpidintvalue >> (totalbits - noofbits - startbit + 1)) & mask
//                 int shiftAmount = (noOfBytes * 8) - noOfBits - startBit + 1;
//                 int mask =
//                     (pow(16, noOfBytes * 2).toInt() - 1) >>
//                     ((noOfBytes * 8) - noOfBits - startBit + 1);

//                 unsignedPidIntValue =
//                     (unsignedPidIntValue >> shiftAmount) & mask;
//               }

//               if (currentVar.readParameterIndex ==
//                       ReadParameterIndex.uds2sCompliment &&
//                   currentVar.offset == 1) {
//                 // Using .toDouble() to ensure precision before multiplication
//                 floatPidValue =
//                     unsignedPidIntValue.toDouble() *
//                     (currentVar.resolution ?? 1.0);
//               } else if (currentVar.datatype == "IEEE754_FLOAT") {
//                 var bd = ByteData(4)..setUint32(0, unsignedPidIntValue);
//                 double floatValue = bd.getFloat32(0);
//                 floatPidValue =
//                     (floatValue * (currentVar.resolution ?? 1.0)) +
//                     (currentVar.offset ?? 0.0);
//               } else {
//                 floatPidValue =
//                     (unsignedPidIntValue * (currentVar.resolution ?? 1.0)) +
//                     (currentVar.offset ?? 0.0);
//               }

//               // ToString("0.000") equivalent in Dart
//               dataValue = floatPidValue.toStringAsFixed(3);
//               print("---END CONTINUOUS--");
//             } else if (currentVar.datatype == "ASCII") {
//               print("---START ASCII--");
//               int noOfBytes = currentVar.noOfBytes ?? 0;
//               int startByte = currentVar.startByte ?? 0;

//               outputLiveParArray = rxArray.sublist(
//                 startByte + txFrameLen - 1,
//                 startByte + txFrameLen - 1 + noOfBytes,
//               );

//               dataValue = ascii
//                   .decode(outputLiveParArray)
//                   .replaceAll("\x00", "");
//               print("---END ASCII--");
//             } else if (currentVar.datatype == "BCD" ||
//                 currentVar.datatype == "HEX") {
//               print("---START BCD--");
//               int noOfBytes = currentVar.noOfBytes ?? 0;
//               int startByte = currentVar.startByte ?? 0;

//               Uint8List subArray = rxArray.sublist(
//                 startByte + txFrameLen - 1,
//                 startByte + txFrameLen - 1 + noOfBytes,
//               );

//               // takeWhile equivalent
//               var filteredBytes = subArray
//                   .takeWhile((value) => value != 0x00)
//                   .toList();
//               dataValue = byteArrayToString(Uint8List.fromList(filteredBytes));
//               print("---END BCD--");
//             } else if (currentVar.datatype == "ENUMRATED") {
//               int pidIntValue = 0;
//               int noOfBytes = currentVar.noOfBytes ?? 0;
//               int startByte = currentVar.startByte ?? 0;

//               for (int j = 0; j < noOfBytes; j++) {
//                 pidIntValue |=
//                     (rxArray[startByte + txFrameLen - 1 + j] <<
//                     ((noOfBytes - 1 - j) * 8));
//               }

//               if (currentVar.isBitcoded == true) {
//                 int noOfBits = currentVar.noofBits ?? 0;
//                 int startBit = currentVar.startBit ?? 0;
//                 int shiftAmount = (noOfBytes * 8) - noOfBits - startBit + 1;
//                 int mask = (pow(16, noOfBytes * 2).toInt() - 1) >> shiftAmount;

//                 pidIntValue = (pidIntValue >> shiftAmount) & mask;
//               }

//               dataValue = pidIntValue.toString();

//               if (currentVar.messages != null &&
//                   currentVar.messages!.isNotEmpty) {
//                 for (var item in currentVar.messages!) {
//                   if (int.tryParse(item.code ?? "") == pidIntValue) {
//                     dataValue = item.message ?? "";
//                   }
//                 }
//               }
//             } else if (currentVar.datatype == "IQA") {
//               dataValue = decodeIQA1(
//                 rxArray,
//                 k,
//               ); // Logic abstracted into the helper below
//             }

//             variableResponses.add(
//               ReadParameterVariableResponse(
//                 pidName: currentVar.pidName,
//                 pidNumber: currentVar.pidNumber,
//                 responseValue: dataValue,
//               ),
//             );
//           } catch (e) {
//             variableResponses.add(
//               ReadParameterVariableResponse(
//                 pidName: inputLiveParaArray.variables![k].pidName,
//                 pidNumber: inputLiveParaArray.variables![k].pidNumber,
//                 responseValue: "Exception",
//               ),
//             );
//           }
//           print(
//             " END LOOP VARIABLE NAME = ${inputLiveParaArray.variables![k].pidName}",
//           );
//         }

//         databyteArray = ReadParameterResponse(
//           pidId: pidItem.pidId,
//           status: pidResponse.ecuResponseStatus,
//           dataArray: outputLiveParArray,
//           pidName: "",
//           variables: variableResponses,
//         );
//       } else {
//         List<ReadParameterVariableResponse> variableResponses = [];
//         for (var item in (pidItem.variables ?? [])) {
//           variableResponses.add(
//             ReadParameterVariableResponse(
//               pidName: item.pidName,
//               pidNumber: item.pidNumber,
//               responseValue: dataValue,
//             ),
//           );
//         }
//         databyteArray = ReadParameterResponse(
//           status: pidResponse.ecuResponseStatus,
//           pidId: pidItem.pidId,
//           pidName: "",
//           variables: variableResponses,
//         );
//       }
//     } catch (e) {
//       databyteArray = ReadParameterResponse(status: "Exception");
//     }

//     return databyteArray;
//   }

//   // IQA Helper function based on your logic
//   String decodeIQA1(Uint8List rxArray, int k) {
//     const String iqaLookupX = "ABCDEFGHIKLMNOPTRSTUVWXYZ12345678";
//     Uint8List iqaEcuArray = Uint8List(48);

//     // Array.Copy(Rxarray, 3, iqaecuarray, 0, Rxarray.Length - 3)
//     if (rxArray.length > 3) {
//       List<int> sub = rxArray.sublist(3);
//       iqaEcuArray.setRange(0, sub.length > 48 ? 48 : sub.length, sub);
//     }

//     Uint8List rxData = Uint8List(8);
//     rxData.setRange(0, 8, iqaEcuArray.sublist(k * 8, (k * 8) + 8));

//     List<int> iqaY = List.filled(7, 0);
//     iqaY[0] = (rxData[0] & 0xF8) >> 3;
//     iqaY[1] = (((rxData[0] & 0x07) << 8) | (rxData[1] & 0xC0)) >> 6;
//     iqaY[2] = (rxData[1] & 0x3E) >> 1;
//     iqaY[3] = (((rxData[1] & 0x01) << 8) | (rxData[2] & 0xF0)) >> 4;
//     iqaY[4] = (((rxData[2] & 0x0F) << 8) | (rxData[3] & 0x80)) >> 7;
//     iqaY[5] = (rxData[3] & 0x7C) >> 2;
//     iqaY[6] = (rxData[4] & 0xF8) >> 3;

//     String result = "";
//     for (int y in iqaY) {
//       result += iqaLookupX[y];
//     }
//     return result;
//   }

//   Future<ReadParameterResponse> readParametersFromAddr(
//     ReadParameterPID readParameter,
//     String pidByAddrSeq,
//   ) async {
//     List<String> lineData = pidByAddrSeq.split('\n');

//     ResponseArrayStatus? reprogrammingResponse;
//     ReadParameterResponse readParameterResponse = ReadParameterResponse();
//     Uint8List seedKey = Uint8List(0);

//     try {
//       bool isReadStarted = false;
//       for (int i = 0; i < lineData.length; i++) {
//         String formattedLine = lineData[i].replaceAll('\r', '').trim();

//         if (formattedLine.startsWith("//") || formattedLine == "") {
//           continue;
//         }

//         if (formattedLine.contains("startread")) isReadStarted = true;

//         if (isReadStarted && formattedLine.contains("endread")) {
//           isReadStarted = false;
//         }

//         if (!isReadStarted) continue;

//         List<String> parts = formattedLine.split(':');
//         String command = parts[0];
//         String info = parts.length > 1 ? parts[1] : "";

//         if (command == "send") {
//           List<String> splitData = info.split('+');
//           List<int> txFrameList = [];

//           for (var item in splitData) {
//             if (!item.contains("<")) {
//               txFrameList.addAll(hexStringToByteArray(item));
//             } else {
//               int endIndex = item.indexOf('>');
//               // item.substring(1, endIndex) gets content between < and >
//               String bracketString = item.substring(1, endIndex);
//               List<String> bracketParts = bracketString.split(',');
//               String reference = bracketParts[0];

//               // Convert hex length string to int
//               int copyLength = int.parse(bracketParts[1], radix: 16);
//               List<int> copyArray = [];

//               if (reference.contains("key")) {
//                 copyArray = List<int>.from(seedKey);
//               } else if (reference.contains("pid_addr")) {
//                 copyArray = hexStringToByteArray(readParameter.pid ?? "");

//                 if (copyArray.length > copyLength) {
//                   copyArray = copyArray.sublist(copyArray.length - copyLength);
//                 }
//               } else if (reference.contains("pid_len")) {
//                 // Convert totalLen to bytes (Big Endian logic like C# Array.Reverse)
//                 int totalLen = readParameter.totalLen ?? 0;
//                 ByteData bdata = ByteData(4)
//                   ..setUint32(0, totalLen, Endian.big);
//                 copyArray = bdata.buffer.asUint8List().toList();

//                 if (copyArray.length > copyLength) {
//                   copyArray = copyArray.sublist(copyArray.length - copyLength);
//                 }
//               }

//               // Ensure the copyArray matches the requested copyLength
//               if (copyArray.length > copyLength) {
//                 copyArray = copyArray.sublist(0, copyLength);
//               } else if (copyArray.length < copyLength) {
//                 // Pad with zeros if too short
//                 copyArray = List<int>.from(copyArray)
//                   ..addAll(List.filled(copyLength - copyArray.length, 0));
//               }

//               txFrameList.addAll(copyArray);
//             }
//           }

//           String txHexString = byteArrayToString(
//             Uint8List.fromList(txFrameList),
//           );
//           print("send : Sending Command $txHexString");

//           reprogrammingResponse = await dongleComm!.canTxRx(
//             txFrameList.length,
//             txHexString,
//           );

//           // Handle "Required Time Delay Not Expired" loop
//           while (reprogrammingResponse?.ecuResponseStatus ==
//               "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
//             await Future.delayed(Duration(milliseconds: 300));
//             reprogrammingResponse = await dongleComm!.canTxRx(
//               txFrameList.length,
//               txHexString,
//             );
//           }

//           if (reprogrammingResponse?.ecuResponseStatus != "NOERROR") {
//             print(
//               "ELMZ : --------- reprogrammingResponse ERROR------------==${reprogrammingResponse?.ecuResponseStatus}",
//             );
//             readParameterResponse = ReadParameterResponse()
//               ..pidId = readParameter.pidId
//               ..status = reprogrammingResponse?.ecuResponseStatus;
//             return readParameterResponse;
//           }
//         } else if (command == "sleep") {
//           await Future.delayed(Duration(milliseconds: int.parse(info)));
//         } else if (command == "function") {
//           if (info.contains("CalculateKeyFromSeed")) {
//             int startIdx = info.indexOf('[') + 1;
//             int endIdx = info.indexOf(']');
//             String sqrBktInfo = info.substring(startIdx, endIdx);
//             List<String> params = sqrBktInfo.split(',');

//             String seedKeyIndexStr = params[0].replaceAll(
//               '-',
//               '_',
//             ); // e.g., "UDS_LEVEL_1"

//             // 1. Convert String to Enum
//             // We look for a match in SeedKeyIndexType.values
//             SeedKeyIndexType? selectedIndex;
//             try {
//               selectedIndex = SeedKeyIndexType.values.firstWhere(
//                 (e) => e.toString().split('.').last == seedKeyIndexStr,
//               );
//             } catch (e) {
//               print("Error: $seedKeyIndexStr is not a valid SeedKeyIndexType");
//             }

//             if (selectedIndex != null) {
//               Uint8List actualBytes = reprogrammingResponse!.actualDataBytes!;
//               // Skip the first 2 bytes (usually service ID and sub-function)
//               Uint8List seedArray = actualBytes.sublist(2);

//               print(
//                 "-------seed array = ${byteArrayToString(seedArray)}-------",
//               );
//               print("-------get key-------");

//               // 2. Pass the Enum 'selectedIndex', not the String
//               // Also ensuring we initialize the keyOutput list if your method requires it
//               List<int> keyBuffer = [];
//               await calculateSeedkey!.calculateSeedkey(
//                 index: selectedIndex,
//                 seed: seedArray,
//                 keyOutput: keyBuffer,
//               );

//               // 3. Convert the result back to Uint8List
//               seedKey = Uint8List.fromList(keyBuffer);
//               print(
//                 "-------get key response = ${byteArrayToString(seedKey)}-------",
//               );
//             }
//           }
//         } else if (command == "readpid") {
//           if (reprogrammingResponse != null) {
//             readParameterResponse = await pidConvertResponse(
//               reprogrammingResponse,
//               readParameter,
//             );
//           }
//         }
//       }
//     } catch (ex, stack) {
//       print("Exception : $ex $stack");
//       readParameterResponse.status = "Exception";
//     }

//     return readParameterResponse;
//   }

//   Future<List<ReadParameterResponse>> setRoutineValue(
//     int noOfParameters,
//     List<ReadParameterPID> readParameterCollection,
//     Uint8List actualResponse,
//   ) async {
//     List<ReadParameterResponse> databyteArray = [];
//     dongleComm!.saveLog("------Start Read Pid------\n");
//     // ignore: unused_local_variable
//     int index = 0;

//     for (int i = 0; i < readParameterCollection.length; i++) {
//       var pidItem = readParameterCollection[i];
//       int frameLength = 0;
//       String dataValue = "";

//       print(
//         "---------------------START LOOP PID NAME-------------------------------------${pidItem.pid}\n",
//       );
//       dongleComm!.saveLog("------Start Read Pid (${pidItem.pid})------");

//       // Manually creating the response object as per your C# logic
//       var pidResponseStatus = "NOERROR";
//       Uint8List rxArray = actualResponse;

//       try {
//         if (pidResponseStatus == "NOERROR") {
//           var pidBytesResponseString = byteArrayToString(rxArray);
//           print("Response received = $pidBytesResponseString");
//           print("IORTEST : Actual Response $pidBytesResponseString");

//           var status = pidResponseStatus;
//           var inputLiveParaArray = readParameterCollection;
//           var txFrameLen = frameLength;

//           // Initializing empty byte array
//           Uint8List outputLiveParArray = Uint8List(0);

//           if (status == "NOERROR") {
//             print("---NOERROR LOOP");
//             List<ReadParameterVariableResponse> variableResponses = [];

//             for (
//               int k = 0;
//               k < (inputLiveParaArray[i].variables?.length ?? 0);
//               k++
//             ) {
//               var currentVar = inputLiveParaArray[i].variables![k];
//               print(
//                 "---------------------START LOOP VARIABLE NAME-------------------------------------${currentVar.pidName}",
//               );

//               try {
//                 if (currentVar.datatype == "CONTINUOUS" ||
//                     currentVar.datatype == "IEEE754_FLOAT") {
//                   print("---START CONTINUOUS--");
//                   int unsignedPidIntValue = 0;
//                   int noOfBytes = currentVar.noOfBytes ?? 0;

//                   for (int j = 0; j < noOfBytes; j++) {
//                     index++;
//                     // Note the +5 offset from your C# code: (startByte + 5)
//                     int byteIndex =
//                         (currentVar.startByte ?? 0) + 5 + txFrameLen - 1 + j;

//                     if (byteIndex < rxArray.length) {
//                       unsignedPidIntValue |=
//                           (rxArray[byteIndex] << ((noOfBytes - 1 - j) * 8));
//                     }

//                     print("IORTEST : Start byte ${currentVar.startByte}");
//                     print("IORTEST : Lenth $txFrameLen");
//                     print("IORTEST : No Of Byte $noOfBytes");
//                   }

//                   print("IORTEST : Shifted Value Value = $unsignedPidIntValue");

//                   if (currentVar.isBitcoded == true) {
//                     int lsbStartBit = currentVar.startBit ?? 1;
//                     int mask = 0;
//                     for (int x = 0; x < (currentVar.noofBits ?? 0); x++) {
//                       mask |= (0x01 << (lsbStartBit - 1));
//                       lsbStartBit++;
//                     }
//                     unsignedPidIntValue =
//                         (unsignedPidIntValue & mask) >>
//                         ((currentVar.startBit ?? 1) - 1);
//                   }

//                   double floatPidValue = 0;
//                   if (currentVar.readParameterIndex ==
//                           ReadParameterIndex.uds2sCompliment &&
//                       currentVar.offset == 1) {
//                     floatPidValue =
//                         unsignedPidIntValue.toDouble() *
//                         (currentVar.resolution ?? 1.0);
//                   } else if (currentVar.datatype == "IEEE754_FLOAT") {
//                     var bd = ByteData(4)..setUint32(0, unsignedPidIntValue);
//                     floatPidValue =
//                         (bd.getFloat32(0) * (currentVar.resolution ?? 1.0)) +
//                         (currentVar.offset ?? 0.0);
//                   } else {
//                     floatPidValue =
//                         (unsignedPidIntValue * (currentVar.resolution ?? 1.0)) +
//                         (currentVar.offset ?? 0.0);
//                   }

//                   dataValue = floatPidValue.toStringAsFixed(3);
//                   print("IORTEST : DLL Value $dataValue");
//                   print(
//                     "---------------------Value-------------------------------------${currentVar.pidName} : $dataValue",
//                   );
//                   print("---END CONTINUOUS--");
//                 } else if (currentVar.datatype == "ASCII") {
//                   print("---START ASCII--");
//                   int noOfBytes = currentVar.noOfBytes ?? 0;
//                   int startByte = currentVar.startByte ?? 0;

//                   int start = startByte + 5 + txFrameLen - 1;
//                   if (start + noOfBytes <= rxArray.length) {
//                     Uint8List subArray = rxArray.sublist(
//                       start,
//                       start + noOfBytes,
//                     );
//                     dataValue = ascii.decode(subArray).replaceAll("\x00", "");
//                   }
//                   print("---END ASCII--");
//                 } else if (currentVar.datatype == "BCD" ||
//                     currentVar.datatype == "HEX") {
//                   print("---START BCD--");
//                   int noOfBytes = currentVar.noOfBytes ?? 0;
//                   int startByte = currentVar.startByte ?? 0;

//                   int start = startByte + 5 + txFrameLen - 1;
//                   if (start + noOfBytes <= rxArray.length) {
//                     Uint8List subArray = rxArray.sublist(
//                       start,
//                       start + noOfBytes,
//                     );
//                     var newData = subArray.takeWhile((v) => v != 0x00).toList();
//                     dataValue = byteArrayToString(Uint8List.fromList(newData));
//                   }
//                   print("---END BCD--");
//                 } else if (currentVar.datatype == "ENUMRATED") {
//                   int pidIntValue = 0;
//                   int noOfBytes = currentVar.noOfBytes ?? 0;
//                   int startByte = currentVar.startByte ?? 0;

//                   for (int j = 0; j < noOfBytes; j++) {
//                     int byteIndex = startByte + 5 + txFrameLen - 1 + j;
//                     if (byteIndex < rxArray.length) {
//                       pidIntValue |=
//                           (rxArray[byteIndex] << ((noOfBytes - 1 - j) * 8));
//                     }
//                   }

//                   if (currentVar.isBitcoded == true) {
//                     int lsbStartBit = currentVar.startBit ?? 1;
//                     int mask = 0;
//                     for (int x = 0; x < (currentVar.noofBits ?? 0); x++) {
//                       mask |= (0x01 << (lsbStartBit - 1));
//                       lsbStartBit++;
//                     }
//                     pidIntValue =
//                         (pidIntValue & mask) >>
//                         ((currentVar.startBit ?? 1) - 1);
//                   }

//                   dataValue = pidIntValue.toString();
//                   if (currentVar.messages != null &&
//                       currentVar.messages!.isNotEmpty) {
//                     for (var item in currentVar.messages!) {
//                       int? code = int.tryParse(item.code ?? "");
//                       if (code != null && code == pidIntValue) {
//                         dataValue = item.message ?? "";
//                       }
//                     }
//                   }
//                 } else if (currentVar.datatype == "IQA") {
//                   // Assuming decodeIQA logic from previous conversions
//                   dataValue = decodeIQA1(rxArray.sublist(3), k);
//                 }

//                 variableResponses.add(
//                   ReadParameterVariableResponse(
//                     pidName: currentVar.pidName,
//                     pidNumber: currentVar.pidNumber,
//                     responseValue: dataValue,
//                   ),
//                 );
//               } catch (ex) {
//                 variableResponses.add(
//                   ReadParameterVariableResponse(
//                     pidName: currentVar.pidName,
//                     pidNumber: currentVar.pidNumber,
//                     responseValue: "Exception",
//                   ),
//                 );
//               }
//               print(" END LOOP VARIABLE NAME = ${currentVar.pidName}");
//             }

//             databyteArray.add(
//               ReadParameterResponse(
//                 pidId: pidItem.pidId,
//                 status: status,
//                 dataArray: outputLiveParArray,
//                 pidName: "",
//                 variables: variableResponses,
//               ),
//             );
//           } else {
//             // Handle Error Case
//             List<ReadParameterVariableResponse> variableResponses = [];
//             for (var item in (inputLiveParaArray[i].variables ?? [])) {
//               variableResponses.add(
//                 ReadParameterVariableResponse(
//                   pidName: item.pidName,
//                   pidNumber: item.pidNumber,
//                   responseValue: dataValue,
//                 ),
//               );
//             }
//             databyteArray.add(
//               ReadParameterResponse(
//                 status: status,
//                 dataArray: Uint8List.fromList([
//                   0x00,
//                 ]), // Equivalent to outputlivepararray[i] = 0x00
//                 pidId: pidItem.pidId,
//                 pidName: "",
//                 variables: variableResponses,
//               ),
//             );
//           }
//         }
//       } catch (excepption) {
//         databyteArray.add(ReadParameterResponse(status: excepption.toString()));
//       }
//       print(" END LOOP PID NAME = ${pidItem.pid}");
//     }
//     return databyteArray;
//   }

//   Future<List<WriteParameterResponse>?> writeParameters(
//     int noOfParameters,
//     WriteParameterIndex writeParameterIndex,
//     List<WriteParameterPID> writeParameterCollection,
//   ) async {
//     try {
//       dongleComm?.saveLog("------Start Write Pid Process------\n");

//       if (calculateSeedkey == null || dongleComm == null) {
//         print(
//           "❌ CRITICAL: Comm=${dongleComm != null} | Calc=${calculateSeedkey != null}",
//         );
//         return null;
//       }

//       List<WriteParameterResponse> responseList = [];

//       for (var pidItem in writeParameterCollection) {
//         int diagnosticsMode = 0x03;
//         int getSeedIndex = 0x01;

//         // ── Seed Index Mapping ─────────────────────────────
//         switch (writeParameterIndex) {
//           case WriteParameterIndex.UDS_DS1003_SK090A:
//             getSeedIndex = 0x09;
//             break;
//           case WriteParameterIndex.UDS_DS1003_SK0102:
//             getSeedIndex = 0x01;
//             break;
//           case WriteParameterIndex.UDS_DS1003_SK0B0C:
//             getSeedIndex = 0x0B;
//             break;
//           case WriteParameterIndex.UDS_DS1003_SK0304:
//             getSeedIndex = 0x03;
//             break;
//           case WriteParameterIndex.UDS_DS1003_SK0506:
//             getSeedIndex = 0x05;
//             break;
//           default:
//             getSeedIndex = 0x01;
//         }

//         print("🔑 PID: ${pidItem.writePid} Seed: $getSeedIndex");

//         // ── STEP 1: Session ─────────────────────────────
//         var sessionResp = await dongleComm!.canTxRx(
//           2,
//           byteArrayToString(Uint8List.fromList([0x10, diagnosticsMode])),
//         );

//         if (sessionResp.ecuResponseStatus != "NOERROR") {
//           responseList.add(
//             WriteParameterResponse(
//               status: sessionResp.ecuResponseStatus,
//               pidNumber: pidItem.writeParaNo,
//               responseValue: "SESSION_FAILED",
//             ),
//           );
//           continue;
//         }

//         // ── STEP 2: Seed Request ─────────────────────────
//         var seedResp = await dongleComm!.canTxRx(
//           2,
//           byteArrayToString(Uint8List.fromList([0x27, getSeedIndex])),
//         );

//         if (seedResp.ecuResponseStatus != "NOERROR" ||
//             seedResp.actualDataBytes == null ||
//             seedResp.actualDataBytes!.length <= 2) {
//           responseList.add(
//             WriteParameterResponse(
//               status: seedResp.ecuResponseStatus,
//               pidNumber: pidItem.writeParaNo,
//               responseValue: "SEED_FAILED",
//             ),
//           );
//           continue;
//         }

//         Uint8List seedArray = seedResp.actualDataBytes!.sublist(2);
//         List<int> keyBuffer = [];

//         // ── STEP 3: Key Calculation ───────────────────────
//         await calculateSeedkey!.calculateSeedkey(
//           index: pidItem.seedKeyIndex as SeedKeyIndexType,
//           seed: seedArray,
//           keyOutput: keyBuffer,
//         );

//         if (keyBuffer.isEmpty) {
//           responseList.add(
//             WriteParameterResponse(
//               status: "KEY_CALC_FAILED",
//               pidNumber: pidItem.writeParaNo,
//             ),
//           );
//           continue;
//         }

//         // ── STEP 4: Key Send ──────────────────────────────
//         Uint8List keyFrame = Uint8List(2 + keyBuffer.length);
//         keyFrame[0] = 0x27;
//         keyFrame[1] = getSeedIndex + 1;
//         keyFrame.setRange(2, 2 + keyBuffer.length, keyBuffer);

//         var keyResp = await dongleComm!.canTxRx(
//           keyFrame.length,
//           byteArrayToString(keyFrame),
//         );

//         if (keyResp.ecuResponseStatus != "NOERROR") {
//           responseList.add(
//             WriteParameterResponse(
//               status: "SECURITY_DENIED",
//               pidNumber: pidItem.writeParaNo,
//             ),
//           );
//           continue;
//         }

//         // ── STEP 5: WRITE FRAME BUILD (FIXED CORE ISSUE) ─────

//         Uint8List pidBytes = hexStringToByteArray(pidItem.writePid ?? "");

//         int dataSize = pidItem.totalBytes ?? 0;

//         int frameSize = 1 + pidBytes.length + dataSize;

//         Uint8List writeFrame = Uint8List(frameSize);

//         writeFrame[0] = 0x2E;

//         // PID placement
//         writeFrame.setRange(1, 1 + pidBytes.length, pidBytes);

//         int baseOffset = 1 + pidBytes.length;

//         // ── SAFE DATA INSERTION ───────────────────────────
//         if (pidItem.writeInput != null && pidItem.writeInput!.isNotEmpty) {
//           int end =
//               baseOffset +
//               (pidItem.startByte ?? 0) +
//               pidItem.writeInput!.length;

//           if (end <= writeFrame.length) {
//             writeFrame.setRange(
//               baseOffset + (pidItem.startByte ?? 0),
//               baseOffset +
//                   (pidItem.startByte ?? 0) +
//                   pidItem.writeInput!.length,
//               pidItem.writeInput!,
//             );
//           } else {
//             print("❌ WRITE INPUT OVERFLOW - skipping");
//           }
//         }

//         // ── IQA PACKING SAFE ──────────────────────────────
//         for (int k = 0; k < (pidItem.variantList?.length ?? 0); k++) {
//           if (pidItem.variantList![k].datatype == "IQA") {
//             _packIQAData(pidItem, writeFrame, pidBytes.length, k);
//           }
//         }

//         print("🔧 FINAL FRAME: ${byteArrayToString(writeFrame)}");

//         // ── STEP 6: WRITE TO ECU ──────────────────────────
//         var writeResp = await dongleComm!.canTxRx(
//           writeFrame.length,
//           byteArrayToString(writeFrame),
//         );

//         responseList.add(
//           WriteParameterResponse(
//             status: writeResp.ecuResponseStatus,
//             dataArray: writeResp.actualDataBytes,
//             pidName: pidItem.pidName,
//             pidNumber: pidItem.writeParaNo,
//             responseValue: writeResp.ecuResponseStatus,
//           ),
//         );
//       }

//       return responseList;
//     } catch (ex) {
//       print("❌ WriteParameters Exception: $ex");
//       return null;
//     }
//   }

//   /// Helper for IQA packing bit-manipulation
//   void _packIQAData(
//     WriteParameterPID pidItem,
//     Uint8List writeFrame,
//     int pidOffset,
//     int k,
//   ) {
//     const String iqaLookup = "ABCDEFGHIKLMNOPTRSTUVWXYZ12345678";
//     List<int> iqaY = List.filled(7, 0);

//     // Find indices in lookup table
//     for (int i = 0; i < 7; i++) {
//       String charToFind = String.fromCharCode(
//         pidItem.writeInput![i],
//       ).toUpperCase();
//       iqaY[i] = iqaLookup.indexOf(charToFind);
//     }

//     // Pack 5-bit values into 32-bit temp
//     int temp =
//         ((iqaY[0] & 0x1F) << 27) |
//         ((iqaY[1] & 0x1F) << 22) |
//         ((iqaY[2] & 0x1F) << 17) |
//         ((iqaY[3] & 0x1F) << 12) |
//         ((iqaY[4] & 0x1F) << 7) |
//         ((iqaY[5] & 0x1F) << 2);

//     Uint8List iqaPacked = Uint8List(8);
//     iqaPacked[0] = (temp & 0xFF000000) >> 24;
//     iqaPacked[1] = (temp & 0x00FF0000) >> 16;
//     iqaPacked[2] = (temp & 0x0000FF00) >> 8;
//     iqaPacked[3] = (temp & 0x000000FF);
//     iqaPacked[4] = (iqaY[6] << 3);

//     int startPos = 1 + pidOffset + (pidItem.variantList![k].startByte ?? 0);
//     writeFrame.setRange(startPos, startPos + 8, iqaPacked);
//   }

//   Future<WriteParameterResponse> actuatorTestWriteParameters(
//     WriteParameterIndex writeParameterIndex,
//     SeedKeyIndexType seedKeyIndex,
//     List<Uint8List> actuatorCmd,
//     bool isStartTest,
//   ) async {
//     WriteParameterResponse writeParameterResp = WriteParameterResponse();

//     try {
//       int diagnosticsMode = 0x00;
//       int getSeedIndex = 0x00;

//       // Determine Diagnostic Mode and Seed Index based on Enum
//       if (writeParameterIndex == WriteParameterIndex.UDS) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x01;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x09;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x01;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x0B;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x03;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x05;
//       }

//       ResponseArrayStatus response = ResponseArrayStatus();
//       Uint8List txFrame = Uint8List(2);
//       int frameLength = 2;

//       // Use .name in Dart for Enum string comparison
//       String indexStr = writeParameterIndex.name;
//       int indexSK = indexStr.indexOf("SK");
//       int indexDS = indexStr.indexOf("DS1");

//       if (isStartTest) {
//         await dongleComm!.canStartTP();
//       }

//       // Diagnostic Session and Security Access logic
//       if (indexStr == "NA") {
//         // Do nothing
//       } else if (indexSK < 0 && isStartTest) {
//         /* Send start diagnostics mode command (10 XX) */
//         txFrame[0] = 0x10;
//         txFrame[1] = diagnosticsMode;
//         response = await dongleComm!.canTxRx(
//           frameLength,
//           byteArrayToString(txFrame),
//         );
//       } else if (indexSK >= 0 && indexSK < indexDS && isStartTest) {
//         /* Security Access first, then Session Control */
//         response = await sendSeedKey(getSeedIndex, seedKeyIndex);
//         if (response.ecuResponseStatus == "NOERROR") {
//           txFrame[0] = 0x10;
//           txFrame[1] = diagnosticsMode;
//           response = await dongleComm!.canTxRx(
//             frameLength,
//             byteArrayToString(txFrame),
//           );
//         }
//       } else if (isStartTest) {
//         /* Session Control first, then Security Access */
//         txFrame[0] = 0x10;
//         txFrame[1] = diagnosticsMode;
//         response = await dongleComm!.canTxRx(
//           frameLength,
//           byteArrayToString(txFrame),
//         );
//         if (response.ecuResponseStatus == "NOERROR") {
//           response = await sendSeedKey(getSeedIndex, seedKeyIndex);
//         }
//       }

//       // Check for errors before sending actuator commands
//       if (response.ecuResponseStatus != "NOERROR" &&
//           indexStr != "NA" &&
//           isStartTest) {
//         await dongleComm!.canStopTP();
//         writeParameterResp = WriteParameterResponse(
//           status: response.ecuResponseStatus,
//           dataArray: response.actualDataBytes,
//           responseValue: response.ecuResponseStatus,
//         );
//         return writeParameterResp;
//       }

//       // Execute Actuator Commands
//       for (var item in actuatorCmd) {
//         response = await dongleComm!.canTxRx(
//           item.length,
//           byteArrayToString(item),
//         );

//         writeParameterResp = WriteParameterResponse(
//           status: response.ecuResponseStatus,
//           dataArray: response.actualDataBytes,
//           responseValue: response.ecuResponseStatus,
//         );
//       }

//       if (!isStartTest) {
//         await dongleComm!.canStopTP();
//       }
//     } catch (ex) {
//       print("Actuator Test Error: $ex");
//       await dongleComm!.canStopTP();
//     }

//     return writeParameterResp;
//   }

//   Future<ResponseArrayStatus> enterExtendedSession(
//     WriteParameterIndex writeParamIndex,
//     SeedKeyIndexType seedKeyIndex,
//   ) async {
//     int diagnosticsMode = 0x00;
//     int getSeedIndex = 0x00;

//     // Logic to determine sub-functions based on the parameter index
//     if (writeParamIndex == WriteParameterIndex.UDS) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x01;
//     } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x09;
//     } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x01;
//     } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x0B;
//     } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x03;
//     } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x05;
//     }

//     ResponseArrayStatus response = ResponseArrayStatus();
//     Uint8List txFrame = Uint8List(2);
//     const int frameLength = 2;

//     // Use .name in Dart to get the string representation of an enum
//     String paramIndexStr = writeParamIndex.name;
//     int indexSK = paramIndexStr.indexOf("SK");
//     int indexDS = paramIndexStr.indexOf("DS1");

//     // Check the sequence order requirements
//     if (paramIndexStr == "NA") {
//       // Do nothing
//     } else if (indexSK < 0) {
//       /* Sequence: Just Session Control (10 XX) */
//       txFrame[0] = 0x10;
//       txFrame[1] = diagnosticsMode;

//       response = await dongleComm!.canTxRx(
//         frameLength,
//         byteArrayToString(txFrame),
//       );
//     } else if (indexSK >= 0 && indexSK < indexDS) {
//       /* Sequence: Seed-Key (27) then Session Control (10) */
//       response = await sendSeedKey(getSeedIndex, seedKeyIndex);

//       if (response.ecuResponseStatus == "NOERROR") {
//         txFrame[0] = 0x10;
//         txFrame[1] = diagnosticsMode;
//         response = await dongleComm!.canTxRx(
//           frameLength,
//           byteArrayToString(txFrame),
//         );
//       }
//     } else {
//       /* Sequence: Session Control (10) then Seed-Key (27) */
//       txFrame[0] = 0x10;
//       txFrame[1] = diagnosticsMode;

//       response = await dongleComm!.canTxRx(
//         frameLength,
//         byteArrayToString(txFrame),
//       );

//       if (response.ecuResponseStatus == "NOERROR") {
//         response = await sendSeedKey(getSeedIndex, seedKeyIndex);
//       }
//     }

//     return response;
//   }

//   Future<ResponseArrayStatus> sendSeedKey(
//     int getSeedIndex,
//     SeedKeyIndexType seedKeyIndex,
//   ) async {
//     ResponseArrayStatus response = ResponseArrayStatus();
//     Uint8List txFrame = Uint8List(2);
//     int frameLength = 2;

//     /* 1. Send Get Seed command (Service 0x27) */
//     txFrame[0] = 0x27;
//     txFrame[1] = getSeedIndex;

//     response = await dongleComm!.canTxRx(
//       frameLength,
//       byteArrayToString(txFrame),
//     );
//     String status = response.ecuResponseStatus ?? "";

//     /* 2. Handle Required Time Delay (ECU Security Access lock) */
//     while (status == "ECUERROR REQUIREDTIMEDELAYNOTEXPIRED") {
//       // Replaced Thread.Sleep with Future.delayed to keep the app responsive
//       await Future.delayed(const Duration(milliseconds: 300));
//       response = await dongleComm!.canTxRx(
//         frameLength,
//         byteArrayToString(txFrame),
//       );
//       status = response.ecuResponseStatus ?? "";
//     }

//     /* 3. If Seed is received successfully */
//     if (status == "NOERROR") {
//       Uint8List? rxArray = response.actualDataBytes;
//       // ignore: unused_local_variable
//       int rxSize = rxArray!.length;

//       // Extract seed (skip first 2 bytes: SID 0x67 and Sub-function)
//       Uint8List seedArray = rxArray.sublist(2);
//       // ignore: unused_local_variable
//       int seedKeyLen = 0; // Set this as per your specific ECU requirements

//       print("-------Calculating key from seed-------");

//       try {
//         // Assuming calculateSeedkey returns an object with 'key' and 'numBytes'
//         // 1. Initialize an empty list to receive the key
//         List<int> keyBuffer = [];

//         // 2. The function returns a status code (int), but fills keyBuffer
//         await calculateSeedkey!.calculateSeedkey(
//           index: seedKeyIndex,
//           seed: seedArray,
//           keyOutput: keyBuffer, // Pass the list here
//         );

//         // 3. Check status and use the buffer

//         // Check your specific "Success" code
//         Uint8List actualKey = Uint8List.fromList(keyBuffer);
//         int numKeyBytes = actualKey.length;

//         // Proceed with sending the key...
//         /* 4. Send Calculated Key back to ECU */
//         Uint8List newTxFrame = Uint8List(numKeyBytes + 2);
//         newTxFrame[0] = 0x27;
//         // Key sub-function is always GetSeed sub-function + 1
//         newTxFrame[1] = getSeedIndex + 1;

//         // Copy the calculated key into the frame starting at index 2
//         newTxFrame.setRange(2, 2 + numKeyBytes, actualKey);

//         print(
//           "-------Sending calculated key: ${byteArrayToString(newTxFrame)}-------",
//         );

//         response = await dongleComm!.canTxRx(
//           newTxFrame.length,
//           byteArrayToString(newTxFrame),
//         );
//       } catch (e) {
//         print("Error calculating or sending SeedKey: $e");
//         response.ecuResponseStatus = "EXCEPTION";
//       }
//     }

//     return response;
//   }

//   Future<List<WriteParameterResponse>> atuatorTestWriteParameters(
//     int noOfParameters,
//     WriteParameterIndex writeParameterIndex,
//     List<WriteParameterPID> writeParameterCollection,
//     bool isPlay,
//   ) async {
//     List<WriteParameterResponse> writeParameterResponseList = [];
//     dongleComm!.saveLog("------Start Actuator Test------\n");

//     for (var pidItem in writeParameterCollection) {
//       int diagnosticsMode = 0x00;
//       int getSeedIndex = 0x00;

//       // Map the session and seed requirements
//       if (writeParameterIndex == WriteParameterIndex.UDS) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x01;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x09;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x01;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x0B;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x03;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
//         diagnosticsMode = 0x03;
//         getSeedIndex = 0x05;
//       }

//       // 1. Send Diagnostic Session Control (0x10)
//       Uint8List txFrame = Uint8List.fromList([0x10, diagnosticsMode]);
//       var pidResponse = await dongleComm!.canTxRx(
//         2,
//         byteArrayToString(txFrame),
//       );

//       if (pidResponse.ecuResponseStatus == "NOERROR") {
//         // 2. Send Security Access - Request Seed (0x27)
//         Uint8List seedFrame = Uint8List.fromList([0x27, getSeedIndex]);
//         var pidResponseBytes = await dongleComm!.canTxRx(
//           2,
//           byteArrayToString(seedFrame),
//         );
//         var status = pidResponseBytes.ecuResponseStatus;

//         // Handle Required Time Delay
//         if (status == "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
//           await Future.delayed(const Duration(milliseconds: 11000));
//           pidResponseBytes = await dongleComm!.canTxRx(
//             2,
//             byteArrayToString(seedFrame),
//           );
//           status = pidResponseBytes.ecuResponseStatus;
//         }

//         if (status == "NOERROR") {
//           Uint8List? rxArray = pidResponseBytes.actualDataBytes;
//           Uint8List seedArray = rxArray!.sublist(2);

//           // ignore: unused_local_variable
//           int seedKeyLen = 16; // Logic simplified from previous blocks
//           if (pidItem.seedKeyIndex == SeedKeyIndexType.sanitasBoschBs6Prod) {
//             seedKeyLen = 8;
//           } else if (pidItem.seedKeyIndex ==
//               SeedKeyIndexType.seedkeyalgoVecvDelphiBs6) {
//             seedKeyLen = 4;
//           }

//           // 3. Calculate Key and Send (Service 0x27)
//           List<int> keyOutput = [];
//           await calculateSeedkey!.calculateSeedkey(
//             index: pidItem.seedKeyIndex as SeedKeyIndexType,
//             seed: seedArray,
//             keyOutput: keyOutput,
//           );

//           Uint8List actualKey = Uint8List.fromList(keyOutput);
//           Uint8List keyTxFrame = Uint8List(actualKey.length + 2);
//           keyTxFrame[0] = 0x27;
//           keyTxFrame[1] = getSeedIndex + 1;
//           keyTxFrame.setRange(2, 2 + actualKey.length, actualKey);

//           var pidResponse3 = await dongleComm!.canTxRx(
//             keyTxFrame.length,
//             byteArrayToString(keyTxFrame),
//           );

//           if (pidResponse3.ecuResponseStatus == "NOERROR") {
//             Uint8List ioCtrlPID = hexStringToByteArray(pidItem.ioCtrlPid ?? "");
//             int totalLen = pidItem.totalLen ?? 0;

//             // 4. Send IO Control (Service 0x2F)
//             Uint8List ioFrame;
//             if (isPlay) {
//               // Service 0x2F + PID + ControlParam(0x03 - ShortTermAdjustment) + Data
//               ioFrame = Uint8List(2 + ioCtrlPID.length + totalLen);
//               ioFrame[0] = 0x2F;
//               ioFrame.setRange(1, 1 + ioCtrlPID.length, ioCtrlPID);
//               ioFrame[1 + ioCtrlPID.length] = 0x03; // ShortTermAdjustment
//               ioFrame.setRange(
//                 2 + ioCtrlPID.length,
//                 2 + ioCtrlPID.length + totalLen,
//                 pidItem.writeInput!,
//               );
//             } else {
//               // Service 0x2F + PID + ControlParam(0x00 - ReturnControlToECU)
//               ioFrame = Uint8List(2 + ioCtrlPID.length);
//               ioFrame[0] = 0x2F;
//               ioFrame.setRange(1, 1 + ioCtrlPID.length, ioCtrlPID);
//               ioFrame[1 + ioCtrlPID.length] = 0x00; // ReturnControlToECU
//             }

//             var pidResponse4 = await dongleComm!.canTxRx(
//               ioFrame.length,
//               byteArrayToString(ioFrame),
//             );

//             writeParameterResponseList.add(
//               WriteParameterResponse(
//                 status: pidResponse4.ecuResponseStatus,
//                 dataArray: pidResponse4.actualDataBytes,
//                 pidName: pidItem.pidName,
//                 pidNumber: pidItem.writeParaNo,
//                 responseValue: pidResponse4.ecuResponseStatus,
//               ),
//             );
//           } else {
//             // Key Error
//             writeParameterResponseList.add(
//               WriteParameterResponse(
//                 status: pidResponse3.ecuResponseStatus,
//                 pidNumber: pidItem.writeParaNo,
//                 responseValue: pidResponse3.ecuResponseStatus,
//               ),
//             );
//           }
//         } else {
//           // Seed Error
//           writeParameterResponseList.add(
//             WriteParameterResponse(
//               status: pidResponseBytes.ecuResponseStatus,
//               pidNumber: pidItem.writeParaNo,
//               responseValue: pidResponseBytes.ecuResponseStatus,
//             ),
//           );
//         }
//       } else {
//         // Session Error
//         writeParameterResponseList.add(
//           WriteParameterResponse(
//             status: pidResponse.ecuResponseStatus,
//             pidNumber: pidItem.writeParaNo,
//             responseValue: pidResponse.ecuResponseStatus,
//           ),
//         );
//       }
//     }

//     return writeParameterResponseList;
//   }

//   Future<WriteParameterResponse> writeParametersFromAddr(
//     WriteParameterPID writeParameter,
//     String pidByAddrSeq,
//   ) async {
//     List<String> lineData = pidByAddrSeq.split('\n');

//     ResponseArrayStatus? reprogrammingResponse;
//     WriteParameterResponse writeParameterResponse = WriteParameterResponse();
//     Uint8List seedKey = Uint8List(0);

//     try {
//       bool isWriteStarted = false;
//       for (int i = 0; i < lineData.length; i++) {
//         String formattedLine = lineData[i].replaceAll('\r', '').trim();

//         // Skip comments and empty lines
//         if (formattedLine.startsWith("//") || formattedLine.isEmpty) {
//           continue;
//         }

//         if (formattedLine.contains("startwrite")) isWriteStarted = true;
//         if (isWriteStarted && formattedLine.contains("endwrite"))
//           isWriteStarted = false;

//         if (!isWriteStarted) continue;

//         List<String> lineParts = formattedLine.split(':');
//         String command = lineParts[0];
//         String info = lineParts.length > 1 ? lineParts[1] : "";

//         if (command == "send" || command == "sendroutine") {
//           List<String> splitData = info.split('+');
//           List<int> txFrameList = [];

//           for (var item in splitData) {
//             if (!item.contains("<")) {
//               txFrameList.addAll(hexStringToByteArray(item));
//             } else {
//               int endIndex = item.indexOf('>');
//               String bracketString = item.substring(1, endIndex);
//               List<String> bracketParts = bracketString.split(',');
//               String reference = bracketParts[0];

//               int copyLength = 0;
//               if (bracketString.contains(',')) {
//                 copyLength = int.parse(bracketParts[1], radix: 16);
//               }

//               Uint8List? copyArray = Uint8List(0);

//               if (reference.contains("key")) {
//                 copyArray = seedKey;
//               } else if (reference.contains("pid_addr")) {
//                 Uint8List addrArray = hexStringToByteArray(
//                   writeParameter.pid ?? "",
//                 );
//                 if (addrArray.length > copyLength) {
//                   copyArray = addrArray.sublist(addrArray.length - copyLength);
//                 } else {
//                   copyArray = addrArray;
//                 }
//               } else if (reference.contains("pid_len")) {
//                 // Get total bytes as Big Endian byte array
//                 int totalBytes = writeParameter.totalBytes ?? 0;
//                 ByteData bData = ByteData(4)
//                   ..setUint32(0, totalBytes, Endian.big);
//                 Uint8List lenArray = bData.buffer.asUint8List();

//                 if (lenArray.length > copyLength) {
//                   copyArray = lenArray.sublist(lenArray.length - copyLength);
//                 } else {
//                   copyArray = lenArray;
//                 }
//               } else if (reference.contains("writePid")) {
//                 // Wrap the List<int> in Uint8List.fromList to convert the type
//                 copyArray = Uint8List.fromList(writeParameter.writeInput ?? []);
//                 copyLength = writeParameter.totalBytes ?? 0;
//               }

//               // Resize logic: Ensure copyArray matches copyLength
//               Uint8List finalCopy = Uint8List(copyLength);
//               int bytesToCopy = copyArray.length > copyLength
//                   ? copyLength
//                   : copyArray.length;
//               finalCopy.setRange(0, bytesToCopy, copyArray);

//               txFrameList.addAll(finalCopy);
//             }
//           }

//           Uint8List txFrame = Uint8List.fromList(txFrameList);
//           print("send : Sending Command ${byteArrayToString(txFrame)}");
//           reprogrammingResponse = await dongleComm!.canTxRx(
//             txFrame.length,
//             byteArrayToString(txFrame),
//           );

//           // Handle Time Delay Error
//           while (reprogrammingResponse?.ecuResponseStatus ==
//               "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
//             await Future.delayed(const Duration(milliseconds: 300));
//             reprogrammingResponse = await dongleComm!.canTxRx(
//               txFrame.length,
//               byteArrayToString(txFrame),
//             );
//           }

//           writeParameterResponse.status =
//               reprogrammingResponse?.ecuResponseStatus;

//           if (reprogrammingResponse?.ecuResponseStatus != "NOERROR") {
//             print(
//               "ELMZ : --------- reprogrammingResponse ERROR------------==${reprogrammingResponse?.ecuResponseStatus}",
//             );
//             return writeParameterResponse;
//           }

//           // Handle Routine Loop
//           if (command == "sendroutine") {
//             // Equivalent of 3103 + substring after first 4 chars of splitData[0]
//             String routineReqCommand =
//                 "3103" + splitData[0].trim().substring(4);

//             bool isRoutineLoop = true;
//             while (isRoutineLoop) {
//               await Future.delayed(const Duration(milliseconds: 500));
//               print("RoutineSend : Sending Command $routineReqCommand");
//               reprogrammingResponse = await dongleComm!.canTxRx(
//                 routineReqCommand.length ~/ 2,
//                 routineReqCommand,
//               );

//               if (reprogrammingResponse.ecuResponseStatus != "NOERROR") {
//                 print(
//                   "ELMZ : --------- Routine ERROR------------==${reprogrammingResponse.ecuResponseStatus}",
//                 );
//                 isRoutineLoop = false;
//                 writeParameterResponse.status =
//                     reprogrammingResponse.ecuResponseStatus;
//                 return writeParameterResponse;
//               } else if (reprogrammingResponse.actualDataBytes![4] != 0x02) {
//                 // Routine no longer active/finished
//                 isRoutineLoop = false;
//               }
//             }
//           }
//         } else if (command == "sleep") {
//           await Future.delayed(Duration(milliseconds: int.parse(info)));
//         } else if (command == "function") {
//           if (info.contains("CalculateKeyFromSeed")) {
//             int startIdx = info.indexOf('[') + 1;
//             int endIdx = info.indexOf(']');
//             String sqrBktInfo = info.substring(startIdx, endIdx);
//             List<String> params = sqrBktInfo.split(',');

//             String seedKeyIndexStr = params[0].replaceAll('-', '_');
//             int seedKeyNumBytes = int.parse(params[1], radix: 16);

//             // Find Enum value in Dart
//             SeedKeyIndexType selectedIndex = SeedKeyIndexType.values.firstWhere(
//               (e) => e.toString().split('.').last == seedKeyIndexStr,
//               orElse: () => SeedKeyIndexType.values.first,
//             );

//             Uint8List? actualData = reprogrammingResponse!.actualDataBytes;
//             Uint8List seedArray = actualData!.sublist(2, 2 + seedKeyNumBytes);

//             print("-------seed array = ${byteArrayToString(seedArray)}-------");
//             print("-------get key-------");

//             // Buffer for result
//             List<int> keyBuffer = [];
//             await calculateSeedkey!.calculateSeedkey(
//               index: selectedIndex,
//               seed: seedArray,
//               keyOutput: keyBuffer,
//             );

//             seedKey = Uint8List.fromList(keyBuffer);
//             print(
//               "-------get key response = ${byteArrayToString(seedKey)}-------",
//             );
//           }
//         }
//       }
//     } catch (ex, stackTrace) {
//       print("Exception : $ex $stackTrace");
//       writeParameterResponse.status = "Exception";
//     }

//     return writeParameterResponse;
//   }

//   bool testCondition = false;
//   bool stopTimer = true;

//   /// Dart implementation of IORTestParameters1
//   Future<ResponseArrayStatus> iorTestParameters1({
//     SeedKeyIndexType? seedKeyIndex,
//     WriteParameterIndex? writeParameterIndex,
//     String? startCommand,
//     String? requestCommand,
//     String? stopCommand,
//     bool? initialTestCondition,
//     int? bitPosition,
//     String? activeCommand,
//     String? completeCommand,
//     String? failCommand,
//     bool? isStop,
//     int? timeBase,
//   }) async {
//     print("-------START IOR TEST METHOD-------");
//     ResponseArrayStatus response = ResponseArrayStatus();

//     if (!isStop!) {
//       print("-------Entered-------");
//       testCondition = true;

//       int diagnosticsMode = 0x03; // Default based on your UDS logic
//       int getSeedIndex = 0x01;

//       // Logic for WriteParameterIndex mapping
//       if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
//         getSeedIndex = 0x09;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
//         getSeedIndex = 0x0B;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
//         getSeedIndex = 0x03;
//       } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
//         getSeedIndex = 0x05;
//       }

//       // 1. Session Control
//       Uint8List txFrame = Uint8List.fromList([0x10, diagnosticsMode]);
//       print("-------Send the parameter ID to the ECU-------");
//       response = await dongleComm!.canTxRx(2, byteArrayToString(txFrame));

//       if (response.ecuResponseStatus == "NOERROR") {
//         // 2. Request Seed
//         txFrame[0] = 0x27;
//         txFrame[1] = getSeedIndex;
//         print("-------Send get seed command to ECU-------");
//         response = await dongleComm!.canTxRx(2, byteArrayToString(txFrame));

//         if (response.ecuResponseStatus ==
//             "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
//           await Future.delayed(const Duration(milliseconds: 11000));
//           response = await dongleComm!.canTxRx(2, byteArrayToString(txFrame));
//         }

//         if (response.ecuResponseStatus == "NOERROR") {
//           // 3. Security Access (Seed-Key)
//           Uint8List seedArray = response.actualDataBytes!.sublist(2);
//           List<int> keyBuffer = [];

//           await calculateSeedkey!.calculateSeedkey(
//             index: seedKeyIndex!,
//             seed: seedArray,
//             keyOutput: keyBuffer,
//           );

//           Uint8List actualKey = Uint8List.fromList(keyBuffer);
//           Uint8List keyFrame = Uint8List(actualKey.length + 2);
//           keyFrame[0] = 0x27;
//           keyFrame[1] = getSeedIndex + 1;
//           keyFrame.setRange(2, 2 + actualKey.length, actualKey);

//           response = await dongleComm!.canTxRx(
//             keyFrame.length,
//             byteArrayToString(keyFrame),
//           );

//           if (response.ecuResponseStatus == "NOERROR") {
//             // 4. Start Test Command
//             print("-------START COMMAND SENDING-------");
//             response = await dongleComm!.canTxRx(
//               startCommand!.length ~/ 2,
//               startCommand,
//             );

//             if (response.ecuResponseStatus == "NOERROR") {
//               int currentTimerCount = timeBase!;

//               // Handle Countdown Timer
//               if (currentTimerCount > 0) {
//                 stopTimer = true;
//                 testCondition = true;

//                 Timer.periodic(const Duration(seconds: 1), (timer) async {
//                   currentTimerCount--;
//                   print("Count : $currentTimerCount");

//                   if (currentTimerCount < 1 && testCondition) {
//                     print("Condition True : $currentTimerCount");
//                     stopTimer = false;
//                     testCondition = false;
//                     timer.cancel();

//                     print("-------STOP COMMAND SENDING-------");
//                     var stopRes = await dongleComm!.canTxRx(
//                       stopCommand!.length ~/ 2,
//                       stopCommand,
//                     );
//                     if (stopRes.ecuResponseStatus == "NOERROR") {
//                       // Update external status via a callback or provider if needed
//                     }
//                   }
//                   if (!stopTimer) timer.cancel();
//                 });
//               }

//               // 5. Monitoring Loop (Request Status)
//               while (testCondition) {
//                 response = await dongleComm!.canTxRx(
//                   requestCommand!.length ~/ 2,
//                   requestCommand,
//                 );

//                 if (response.ecuResponseStatus == "NOERROR") {
//                   int statusByte = response.actualDataBytes![bitPosition! - 1];
//                   int activeByte = hexStringToByteArray(activeCommand!)[0];
//                   int completeByte = hexStringToByteArray(completeCommand!)[0];
//                   int failByte = hexStringToByteArray(failCommand!)[0];

//                   if (statusByte != activeByte) {
//                     testCondition = false;
//                     stopTimer = false;

//                     if (statusByte == completeByte) {
//                       response.ecuResponseStatus = "Test Completed";
//                     } else if (statusByte == failByte) {
//                       response.ecuResponseStatus = "Test Aborted";
//                     }
//                   }
//                 } else {
//                   testCondition = false;
//                   stopTimer = false;
//                 }
//                 // Prevent CPU hogging in while loop
//                 await Future.delayed(const Duration(milliseconds: 100));
//               }
//             }
//           }
//         }
//       }
//     } else {
//       // Handling Stop Logic
//       stopTimer = false;
//       testCondition = false;
//       print("-------STOP COMMAND SENDING------- Stop");
//       response = await dongleComm!.canTxRx(
//         stopCommand!.length ~/ 2,
//         stopCommand,
//       );
//       if (response.ecuResponseStatus == "NOERROR") {
//         response.ecuResponseStatus = "Test Stopped";
//       }
//     }

//     return response;
//   }

//   bool activeCon = false;

//   Future<ResponseArrayStatus> iorTestParameters2({
//     SeedKeyIndexType? seedKeyIndex,
//     WriteParameterIndex? writeParameterIndex,
//     String? startCommand,
//     String? requestCommand,
//     String? stopCommand,
//     bool? initialTestCondition,
//     int? bitPosition,
//     List<String>? activeCommands, // Changed to List
//     String? completeCommand,
//     String? failCommand,
//     bool? isStop,
//     int? timeBase,
//     bool? isTimebase,
//   }) async {
//     print("-------START IOR TEST METHOD-------");
//     ResponseArrayStatus responseArrayStatus = ResponseArrayStatus();

//     if (!isStop!) {
//       // If timebase is enabled, start the countdown timer
//       if (isTimebase! && timeBase! > 0) {
//         stopTimer = true;
//         testCondition = true;
//         int currentTimerCount = timeBase;

//         Timer.periodic(const Duration(seconds: 1), (timer) async {
//           currentTimerCount -= 1;
//           print("Count : $currentTimerCount");

//           if (currentTimerCount < 1 && testCondition) {
//             print("Condition True : $currentTimerCount");
//             stopTimer = false;
//             testCondition = false;
//             timer.cancel();

//             print("-------STOP COMMAND SENDING-------");
//             var stopRes = await dongleComm!.canTxRx(
//               stopCommand!.length ~/ 2,
//               stopCommand,
//             );
//             if (stopRes.ecuResponseStatus == "NOERROR") {
//               // In a real app, you'd likely use a Listenable or Stream to update the UI here
//               responseArrayStatus.ecuResponseStatus = "Test Stopped";
//             }
//           }

//           if (!stopTimer) timer.cancel();
//         });
//       }

//       // Main monitoring loop
//       while (testCondition) {
//         responseArrayStatus = await dongleComm!.canTxRx(
//           requestCommand!.length ~/ 2,
//           requestCommand,
//         );

//         if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//           int currentByteValue =
//               responseArrayStatus.actualDataBytes![bitPosition! - 1];
//           int completeByte = hexStringToByteArray(completeCommand!)[0];

//           activeCon = false;

//           // Check if current byte matches any of the active commands in the list
//           for (String active in activeCommands!) {
//             int activeByte = hexStringToByteArray(active)[0];
//             if (currentByteValue == activeByte) {
//               activeCon = true;
//             }
//             print(
//               "Compare Byte = $currentByteValue - $completeByte - $activeByte",
//             );
//           }

//           // If the status is no longer "Active", determine if it's Completed or Failed
//           if (!activeCon) {
//             testCondition = false;
//             stopTimer = false;

//             if (currentByteValue == completeByte) {
//               responseArrayStatus.ecuResponseStatus = "Test Completed";
//             } else if (currentByteValue ==
//                 hexStringToByteArray(failCommand!)[0]) {
//               responseArrayStatus.ecuResponseStatus = "Test Aborted";
//             }
//           }
//         } else {
//           testCondition = false;
//           stopTimer = false;
//         }

//         // Essential: Yield control to the event loop so the Timer and UI can run
//         await Future.delayed(const Duration(milliseconds: 100));
//       }
//     } else {
//       // Immediate Stop Logic
//       stopTimer = false;
//       testCondition = false;
//       print("-------STOP COMMAND SENDING------- Stop");
//       responseArrayStatus = await dongleComm!.canTxRx(
//         stopCommand!.length ~/ 2,
//         stopCommand,
//       );

//       if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//         responseArrayStatus.ecuResponseStatus = "Test Stopped";
//       }
//     }

//     return responseArrayStatus;
//   }

//   Future<ResponseArrayStatus> startIdIOR(
//     SeedKeyIndexType seedKeyIndex1,
//     WriteParameterIndex writeParameterIndex,
//     String startCommand,
//   ) async {
//     print("-------START IOR TEST METHOD-------");
//     ResponseArrayStatus responseArrayStatus = ResponseArrayStatus();
//     print("-------Entered-------");

//     // Logic used in earlier methods to keep the test state

//     int diagnosticsMode = 0x00;
//     int getSeedIndex = 0x00;

//     // Map the session and seed requirements based on the index
//     if (writeParameterIndex == WriteParameterIndex.UDS) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x01;
//     } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x09;
//     } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x01;
//     } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x0B;
//     } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x03;
//     } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
//       diagnosticsMode = 0x03;
//       getSeedIndex = 0x05;
//     }

//     Uint8List txFrame = Uint8List(2);
//     /* 1. Send Diagnostic Session Control (0x10) */
//     txFrame[0] = 0x10;
//     txFrame[1] = diagnosticsMode;
//     int frameLength = 2;

//     print("-------Send the parameter ID to the ECU-------");
//     responseArrayStatus = await dongleComm!.canTxRx(
//       frameLength,
//       byteArrayToHex(txFrame),
//     );

//     if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//       /* 2. Send Security Access - Request Seed (0x27) */
//       txFrame[0] = 0x27;
//       txFrame[1] = getSeedIndex;
//       print("-------Send get seed command to ECU-------");
//       responseArrayStatus = await dongleComm!.canTxRx(
//         frameLength,
//         byteArrayToHex(txFrame),
//       );

//       // Handle Required Time Delay (usually after multiple failed attempts)
//       if (responseArrayStatus.ecuResponseStatus ==
//           "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
//         await Future.delayed(const Duration(milliseconds: 11000));
//         responseArrayStatus = await dongleComm!.canTxRx(
//           frameLength,
//           byteArrayToHex(txFrame),
//         );
//       }

//       if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//         int seedKeyIndex = getSeedIndex;

//         // Extract Seed from response (skipping first 2 bytes)
//         Uint8List seedArray = responseArrayStatus.actualDataBytes!.sublist(2);

//         // Determine expected key length based on the algorithm index
//         if (seedKeyIndex1 == SeedKeyIndexType.sanitasBoschBs6Prod) {
//         } else if (seedKeyIndex1 == SeedKeyIndexType.seedkeyalgoVecvDelphiBs6 ||
//             seedKeyIndex1 == SeedKeyIndexType.seedkeyalgoVecvAmtBs6) {
//         } else if (seedKeyIndex1 ==
//             SeedKeyIndexType.seedkeyalgoVecvDelphiTcic) {}

//         // Calculate Key using the provided buffer-filling logic
//         List<int> actualKeyBuffer = [];
//         await calculateSeedkey!.calculateSeedkey(
//           index: seedKeyIndex1,
//           seed: seedArray,
//           keyOutput: actualKeyBuffer,
//         );

//         // result.numBytes is inferred from the buffer length in Dart
//         int numKeyBytes = actualKeyBuffer.length;

//         if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//           /* 3. Send Security Access - Send Key (0x27) */
//           Uint8List newTxFrame = Uint8List(numKeyBytes + 2);
//           newTxFrame[0] = 0x27;
//           newTxFrame[1] = seedKeyIndex + 1; // getseedindex + 1

//           newTxFrame.setRange(2, 2 + numKeyBytes, actualKeyBuffer);
//           frameLength = newTxFrame.length;

//           responseArrayStatus = await dongleComm!.canTxRx(
//             frameLength,
//             byteArrayToHex(newTxFrame),
//           );

//           if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//             /* 4. Send the specific IOR Start Command */
//             print("-------START COMMAND SENDING-------");
//             responseArrayStatus = await dongleComm!.canTxRx(
//               startCommand.length ~/ 2,
//               startCommand,
//             );
//           } else {
//             // Log or handle security access (key) error
//             print(
//               "Security Access Key Failed: ${responseArrayStatus.ecuResponseStatus}",
//             );
//           }
//         }
//       } else {
//         print(
//           "Security Access Seed Request Failed: ${responseArrayStatus.ecuResponseStatus}",
//         );
//       }
//     }

//     return responseArrayStatus;
//   }

//   Future<ResponseArrayStatus> requestIdIOR(String requestCommand) async {
//     print("-------START IOR TEST METHOD-------");

//     // Calculate length: command string length divided by 2 (2 hex chars per byte)
//     int frameLength = requestCommand.length ~/ 2;

//     // Perform the asynchronous TxRx operation
//     ResponseArrayStatus responseArrayStatus = await dongleComm!.canTxRx(
//       frameLength,
//       requestCommand,
//     );

//     return responseArrayStatus;
//   }

//   Future<ResponseArrayStatus> stopIdIOR(String stopCommand) async {
//     print("-------STOP IOR TEST METHOD-------");
//     ResponseArrayStatus responseArrayStatus = ResponseArrayStatus();
//     print("STOP COMMAND SENDING : $stopCommand");

//     // Calculate length based on hex string pairs
//     int frameLength = stopCommand.length ~/ 2;

//     // Perform the TxRx operation
//     responseArrayStatus = await dongleComm!.canTxRx(frameLength, stopCommand);

//     if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
//       // Standard UDS success response (0x6F) usually doesn't require extra logic here
//     } else {
//       // If the stop command fails, force the background loops/timers to stop
//       testCondition = false;
//       stopTimer = false;
//     }

//     return responseArrayStatus;
//   }

//   Future<dynamic> testRoutine(String command) async {
//     try {
//       // Perform the TxRx operation
//       // ~/ is integer division in Dart (replaces command.length / 2)
//       var responseBytes = await dongleComm!.canTxRx(
//         command.length ~/ 2,
//         command,
//       );

//       return responseBytes;
//     } catch (ex) {
//       // Log the exception if a logger is available
//       print("Error in testRoutine: $ex");
//       return null;
//     }
//   }

//   Future<String?> startEcuUnlocking(
//     String txFrame,
//     String txFrequency,
//     String txTotalTime,
//   ) async {
//     try {
//       int frameLen = txFrame.length ~/ 2;

//       // Parse strings to integers
//       int frequencyMs = int.parse(txFrequency);
//       int totalTimeMs = int.parse(txTotalTime);

//       // Stopwatch equivalent in Dart
//       Stopwatch stopwatch = Stopwatch()..start();

//       // Device.StartTimer equivalent in Dart is Timer.periodic
//       Timer.periodic(Duration(milliseconds: frequencyMs), (timer) {
//         if (stopwatch.elapsedMilliseconds < totalTimeMs) {
//           // Fire and forget the TxRx call just like Task.Run
//           // We don't await this because we want the timer to keep ticking
//           dongleComm!
//               .canTxRx(frameLen, txFrame)
//               .then((response) {
//                 // Optional: handle response inside the keep-alive loop
//               })
//               .catchError((e) {
//                 print("Unlocking keep-alive error: $e");
//               });
//         } else {
//           // Stop the timer and the stopwatch
//           stopwatch.stop();
//           timer.cancel();
//         }
//       });

//       // Note: In your C# code, 'response' was never assigned before returning.
//       // I am returning an empty string or a success indicator.
//       return "Started";
//     } catch (ex) {
//       print("Exception in startEcuUnlocking: $ex");
//       return null;
//     }
//   }

//   Future<List<ReadParameterResponse>?> readParametersFromAddr1(
//     int noOfParameters,
//     List<ReadParameterPID> readParameterCollection,
//     String pidByAddrSeq,
//   ) async {
//     try {
//       // Split by newline and remove carriage returns
//       List<String> lineData = pidByAddrSeq.split('\n');

//       for (int i = 0; i < lineData.length; i++) {
//         String formattedLine = lineData[i].replaceAll('\r', '').trim();

//         // Skip comments or empty lines
//         if (formattedLine.startsWith("//") || formattedLine.isEmpty) {
//           continue;
//         }

//         // Ensure the line contains a colon before splitting
//         if (!formattedLine.contains(':')) continue;

//         List<String> parts = formattedLine.split(':');
//         String command = parts[0].trim();
//         String info = parts[1].trim();

//         if (command == "send") {
//           // splitData logic
//           List<String> splitData = info.split('+');

//           // Example of how to convert hex strings to bytes
//           List<int> txFrame = [];
//           for (String segment in splitData) {
//             // This assumes hexStringToByteArray is defined in your project
//             txFrame.addAll(hexStringToByteArray(segment.trim()));
//           }

//           // Convert to Uint8List for CAN transmission
//           // ignore: unused_local_variable
//           Uint8List requestBytes = Uint8List.fromList(txFrame);

//           // Example TxRx call
//           // var response = await dongleComm.canTxRx(requestBytes.length, byteArrayToHex(requestBytes));
//         }
//       }

//       // Returning empty list or null as per your C# placeholder
//       return null;
//     } catch (e) {
//       print("Error parsing Address Sequence: $e");
//       return null;
//     }
//   }

//   int totalBytesToBeFlashed = 0;
//   int realTimeBytesFlashed = 0;

//   Future<void> resetPercentage() async {
//     totalBytesToBeFlashed = 0;
//     realTimeBytesFlashed = 0;
//   }

//   Future<double> getRuntimeFlashPercent() async {
//     // Check to prevent division by zero if flashing hasn't started
//     if (totalBytesToBeFlashed == 0) {
//       return 0.0;
//     }

//     // Dart's / operator returns a double by default
//     double runtimeFlashPercent = realTimeBytesFlashed / totalBytesToBeFlashed;

//     return runtimeFlashPercent;
//   }

//   List<LoopModel> loopModelList = [];

//   Future<String?> flashInterpreter(
//     FlashConfig flashconfigData,
//     int noofsectors,
//     List<FlashingMatrix> sectordata,
//     String interpreterFile,
//   ) async {
//     ResponseArrayStatus reprogrammingResponse = ResponseArrayStatus();

//     try {
//       dongleComm!.saveLog("------Start Flashing------\n");
//       List<String> lineData = interpreterFile.split('\n');

//       /* Calculate the total number of bytes to be flashed */
//       totalBytesToBeFlashed = 0;
//       for (int i = 0; i < noofsectors; i++) {
//         Uint8List sectorDataArray = hexStringToByteArray(
//           sectordata[i].jsonData ?? "",
//         );
//         int sectorNumBytes = sectorDataArray.length;
//         totalBytesToBeFlashed += sectorNumBytes;
//         realTimeBytesFlashed = 0;
//       }

//       Uint8List seedKey = Uint8List(0);
//       int currSectorIndex = 0;
//       bool isLoopPresent = false;
//       int loopInit = 0;
//       bool skipKey = false;

//       for (int i = 0; i < lineData.length; i++) {
//         String formattedLine = lineData[i].replaceAll('\r', '').trim();

//         if (formattedLine.isEmpty || formattedLine.startsWith("//")) {
//           continue;
//         } else if (skipKey) {
//           skipKey = false;
//           continue;
//         }

//         List<String> parts = formattedLine.split(':');
//         String command = parts[0];
//         String info = parts.length > 1 ? parts[1] : "";

//         if (command == "send" ||
//             command == "sendroutine" ||
//             command == "sendignore" ||
//             command == "sendroutineignore") {
//           List<String> splitData = info.split('+');
//           List<int> txFrameList = [];

//           for (var item in splitData) {
//             if (!item.contains("<")) {
//               txFrameList.addAll(hexStringToByteArray(item));
//             } else {
//               int endIndex = item.indexOf('>');
//               String bracketString = item.substring(1, endIndex);
//               List<String> bParts = bracketString.split(',');
//               String reference = bParts[0];
//               int copyLength = int.parse(bParts[1]);

//               Uint8List copyArray = Uint8List(0);

//               if (reference.contains("key")) {
//                 copyArray = seedKey;
//               } else if (reference.contains("json_strt_addr") ||
//                   reference.contains("ecu_memmap_strt_addr")) {
//                 int index;
//                 if (reference.contains("[i]")) {
//                   index = loopModelList.last.i ?? 0;
//                 } else {
//                   String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
//                   index = int.parse(match);
//                   currSectorIndex = index;
//                 }

//                 String addrHex = "";
//                 if (reference.contains("json_strt_addr")) {
//                   addrHex = (sectordata[index].jsonStartAddress ?? "").padLeft(
//                     copyLength * 2,
//                     '0',
//                   );
//                 } else {
//                   addrHex = (sectordata[index].ecuMemMapStartAddress ?? "")
//                       .padLeft(copyLength * 2, '0');
//                 }
//                 copyArray = hexStringToByteArray(addrHex);
//               } else if (reference.contains("json_end_addr") ||
//                   reference.contains("ecu_memmap_end_addr")) {
//                 int index;
//                 if (reference.contains("[i]")) {
//                   index = loopModelList.last.i ?? 0;
//                 } else {
//                   String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
//                   index = int.parse(match);
//                   currSectorIndex = index;
//                 }

//                 String addrHex = "";
//                 if (reference.contains("json_end_addr")) {
//                   addrHex = (sectordata[index].jsonEndAddress ?? "").padLeft(
//                     copyLength * 2,
//                     '0',
//                   );
//                 } else {
//                   addrHex = (sectordata[index].ecuMemMapEndAddress ?? "")
//                       .padLeft(copyLength * 2, '0');
//                 }
//                 copyArray = hexStringToByteArray(addrHex);
//               } else if (reference.contains("json_checksum")) {
//                 int index;
//                 if (reference.contains("[i]")) {
//                   index = loopModelList.last.i ?? 0;
//                 } else {
//                   String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
//                   index = int.parse(match);
//                   currSectorIndex = index;
//                 }
//                 String checkSumHex = (sectordata[index].jsonCheckSum ?? "")
//                     .padLeft(copyLength * 2, '0');
//                 copyArray = hexStringToByteArray(checkSumHex);
//               } else if (reference.contains("json_sector_len") ||
//                   reference.contains("ecu_memmap_len")) {
//                 int index;
//                 if (reference.contains("[i]")) {
//                   index = loopModelList.last.i ?? 0;
//                 } else {
//                   String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
//                   index = int.parse(match);
//                   currSectorIndex = index;
//                 }

//                 int sectorNumBytes;
//                 if (reference.contains("json_sector_len")) {
//                   sectorNumBytes =
//                       int.parse(sectordata[index].jsonEndAddress!, radix: 16) -
//                       int.parse(
//                         sectordata[index].jsonStartAddress!,
//                         radix: 16,
//                       ) +
//                       1;
//                 } else {
//                   sectorNumBytes =
//                       int.parse(
//                         sectordata[index].ecuMemMapEndAddress!,
//                         radix: 16,
//                       ) -
//                       int.parse(
//                         sectordata[index].ecuMemMapStartAddress!,
//                         radix: 16,
//                       ) +
//                       1;
//                 }
//                 String hexLen = sectorNumBytes
//                     .toRadixString(16)
//                     .padLeft(copyLength * 2, '0');
//                 copyArray = hexStringToByteArray(hexLen);
//               } else if (reference.contains("calculate_sector_len")) {
//                 int index;
//                 if (reference.contains("[i]")) {
//                   index = loopModelList.last.i ?? 0;
//                 } else {
//                   String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
//                   index = int.parse(match);
//                   currSectorIndex = index;
//                 }
//                 int sectorNumBytes = (sectordata[index].jsonData!.length ~/ 2);
//                 String hexLen = sectorNumBytes
//                     .toRadixString(16)
//                     .padLeft(copyLength * 2, '0');
//                 copyArray = hexStringToByteArray(hexLen);
//               } else if (reference.contains("i")) {
//                 copyArray = Uint8List.fromList([
//                   loopModelList.last.i! + loopInit,
//                 ]);
//               }

//               // Standardize copyArray to copyLength
//               Uint8List finalBuffer = Uint8List(copyLength);
//               int actualToCopy = copyArray.length > copyLength
//                   ? copyLength
//                   : copyArray.length;
//               finalBuffer.setRange(0, actualToCopy, copyArray);
//               txFrameList.addAll(finalBuffer);
//             }
//           }

//           Uint8List txFrame = Uint8List.fromList(txFrameList);
//           print("send : Sending Command ${byteArrayToHex(txFrame)}");
//           var sendResp = await dongleComm!.canTxRx(
//             txFrame.length,
//             byteArrayToHex(txFrame),
//           );

//           if (command != "sendignore") {
//             reprogrammingResponse = sendResp;
//           }

//           while (reprogrammingResponse.ecuResponseStatus ==
//               "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
//             await Future.delayed(const Duration(milliseconds: 300));
//             reprogrammingResponse = await dongleComm!.canTxRx(
//               txFrame.length,
//               byteArrayToHex(txFrame),
//             );
//           }

//           if (reprogrammingResponse.ecuResponseStatus != "NOERROR" &&
//               command != "sendignore") {
//             print(
//               "ELMZ: --------- reprogrammingResponse ERROR------------==${reprogrammingResponse.ecuResponseStatus}",
//             );
//             return reprogrammingResponse.ecuResponseStatus;
//           }

//           if (command == "sendroutine" || command == "sendroutineignore") {
//             String routineReqCommand =
//                 "3103" + splitData[0].trim().substring(4);
//             bool isRoutineLoop = true;
//             while (isRoutineLoop) {
//               await Future.delayed(const Duration(milliseconds: 500));
//               print("RoutineSend : Sending Command $routineReqCommand");
//               var routineResp = await dongleComm!.canTxRx(
//                 routineReqCommand.length ~/ 2,
//                 routineReqCommand,
//               );

//               if (command != "sendroutineignore") {
//                 reprogrammingResponse = routineResp;
//               }

//               if (reprogrammingResponse.ecuResponseStatus != "NOERROR" &&
//                   command != "sendroutineignore") {
//                 isRoutineLoop = false;
//                 return reprogrammingResponse.ecuResponseStatus;
//               } else if (routineResp.ecuResponseStatus != "NOERROR" &&
//                   command == "sendroutineignore") {
//                 isRoutineLoop = false;
//               } else {
//                 int statusByte = reprogrammingResponse.actualDataBytes![4];
//                 if (statusByte == 0x02 ||
//                     statusByte == 0x01 ||
//                     statusByte == 0x04) {
//                   isRoutineLoop = false;
//                 }
//               }
//             }
//           }
//         } else if (command == "sleep") {
//           await Future.delayed(Duration(milliseconds: int.parse(info)));
//         } else if (command == "function") {
//           if (info.contains("CalculateKeyFromSeed")) {
//             var firstSplit = info.split('[');
//             var secondSplit = firstSplit[1].split(',');
//             String index1Str = secondSplit[0];
//             String seedKeyNumBytesStr = secondSplit[1].substring(
//               0,
//               secondSplit[1].length - 1,
//             );

//             int seedLen = int.parse(seedKeyNumBytesStr);
//             Uint8List seedArray = reprogrammingResponse.actualDataBytes!
//                 .sublist(2, 2 + seedLen);

//             print("-------seed array = ${byteArrayToHex(seedArray)}-------");
//             print("-------get key-------");

//             if (seedArray.every((x) => x == 0)) {
//               skipKey = true;
//             }

//             SeedKeyIndexType seedKeyIndex = SeedKeyIndexType.values.firstWhere(
//               (e) =>
//                   e.toString().split('.').last ==
//                   index1Str.replaceAll('-', '_'),
//             );

//             List<int> keyOutput = [];
//             await calculateSeedkey!.calculateSeedkey(
//               index: seedKeyIndex,
//               seed: seedArray,
//               keyOutput: keyOutput,
//             );
//             seedKey = Uint8List.fromList(keyOutput);
//             print(
//               "-------get key response = ${byteArrayToHex(seedKey)}-------",
//             );
//           }
//         } else if (command == "repeatstart") {
//           isLoopPresent = true;
//           List<String> sData = info.split(',');
//           int maxIdx = sData[3] == "noofsectors"
//               ? noofsectors
//               : int.parse(sData[3]);
//           loopInit = int.parse(sData[2]);

//           loopModelList.add(
//             LoopModel(
//               i: 0,
//               loopId: int.parse(sData[0]),
//               maxIndex: maxIdx,
//               loopLocation: i,
//             ),
//           );
//         } else if (command == "repeatend") {
//           // Use ! to tell Dart the list is definitely not empty here
//           loopModelList.last.i = (loopModelList.last.i ?? 0) + 1;

//           if (loopModelList.last.i == loopModelList.last.maxIndex) {
//             loopModelList.removeLast();
//           } else {
//             // Ensure loopLocation is also handled for null safety
//             i = loopModelList.last.loopLocation ?? 0;
//           }
//         } else if (command == "sendbulkdata") {
//           List<String> sInfo = info.split(',');
//           int seqVarInitValue = int.parse(sInfo[1]);
//           String transferInfo = sInfo[2];

//           int startBracket = info.indexOf('[') + 1;
//           int endBracket = info.indexOf(']');
//           String sqrBktInfo = info.substring(startBracket, endBracket);
//           int sectorFrameTransferLen = int.parse(
//             sqrBktInfo.split(',')[1].trim(),
//             radix: 16,
//           );

//           int blkSeqCnt = seqVarInitValue;
//           int index = isLoopPresent
//               ? loopModelList.last.i ?? 0
//               : currSectorIndex;

//           Uint8List sectorDataArray = hexStringToByteArray(
//             sectordata[index].jsonData ?? "",
//           );
//           int sectorNumBytes = sectorDataArray.length;

//           for (int j = 0; j < sectorNumBytes;) {
//             try {
//               int currentTransferLen =
//                   (sectorNumBytes - j) < sectorFrameTransferLen
//                   ? (sectorNumBytes - j)
//                   : sectorFrameTransferLen;

//               print("ELMZ: currenttransferlen==${currentTransferLen + 2}");

//               List<String> tSplitData = transferInfo.split('+');
//               List<int> nTxFrameList = [];

//               for (var item in tSplitData) {
//                 String trimmedItem = item.trim();
//                 if (RegExp(r'^\d+$').hasMatch(trimmedItem)) {
//                   nTxFrameList.addAll(hexStringToByteArray(trimmedItem));
//                 } else if (trimmedItem.contains("bsc")) {
//                   nTxFrameList.add(blkSeqCnt & 0xFF);
//                 } else if (trimmedItem.contains("json_sectordata")) {
//                   nTxFrameList.addAll(
//                     sectorDataArray.sublist(j, j + currentTransferLen),
//                   );
//                 }
//               }

//               j += currentTransferLen;
//               print("ELMZ: J==$j");

//               Uint8List nTxFrame = Uint8List.fromList(nTxFrameList);
//               var bulkResp = await dongleComm!.canTxRx(
//                 nTxFrame.length,
//                 byteArrayToHex(nTxFrame),
//               );
//               blkSeqCnt++;

//               if (bulkResp.ecuResponseStatus != "NOERROR") {
//                 print(
//                   "ELMZ: --------bulkTransferResponse -ERROR------------==${bulkResp.ecuResponseStatus}",
//                 );
//                 return bulkResp.ecuResponseStatus;
//               }

//               realTimeBytesFlashed += currentTransferLen;
//               print("ELMZ: blkseqcnt==$blkSeqCnt");
//             } catch (e) {
//               print("ELMZ: exception==$e");
//               return e.toString();
//             }
//           }
//         } else if (command == "txid") {
//           await dongleComm!.canSetTxHeader(info);
//         } else if (command == "rxid") {
//           await dongleComm!.canSetRxHeaderMask(info);
//         } else if (command == "startpadding") {
//           await dongleComm!.canStartPadding(info);
//         } else if (command == "stoppadding") {
//           await dongleComm!.canStopPadding();
//         } else if (command == "setstmin") {
//           await dongleComm!.canSetP1Min(info.trim());
//         } else if (command == "setP2Max") {
//           await dongleComm!.canSetP2Max(info.trim());
//         } else if (command == "stopTP") {
//           await dongleComm!.canStopTP();
//         } else if (command == "startTP") {
//           await dongleComm!.canStartTP();
//         }
//       }
//     } catch (ex) {
//       print("ELMZ: exception==$ex");
//       return ex.toString();
//     }
//     return reprogrammingResponse.ecuResponseStatus;
//   }

//   Future<ResponseArrayStatus> setDataData(String command) async {
//     // ~/ is the integer division operator in Dart
//     // It replaces (int)(command.Length / 2) from C#
//     int frameLength = command.length ~/ 2;

//     // Await the asynchronous CAN transmission
//     ResponseArrayStatus pidResponse = await dongleComm!.canTxRx(
//       frameLength,
//       command,
//     );

//     return pidResponse;
//   }
// }
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:ap_dongle_commcore/ap_dongle_commcore.dart';
import 'package:ap_dongle_commcore/model/responseArrayStatusModel.dart';
import 'package:ap_dongle_diagnostic_core/enums/readDTCIndex.dart';
import 'package:ap_dongle_diagnostic_core/enums/readParameterIndex.dart';
import 'package:ap_dongle_diagnostic_core/enums/writeParameterIndex.dart';
import 'package:ap_dongle_diagnostic_core/model/flashingMatrixModel.dart';
import 'package:ap_dongle_diagnostic_core/model/freezeFrameModel.dart';
import 'package:ap_dongle_diagnostic_core/model/loopModel.dart';
import 'package:ap_dongle_diagnostic_core/model/readDtcResponseModel.dart';
import 'package:ap_dongle_diagnostic_core/model/readMappedPidModel.dart';
import 'package:ap_dongle_diagnostic_core/model/readParameterPidModel.dart';
import 'package:ap_dongle_diagnostic_core/model/readParameterResponse.dart';
import 'package:ap_dongle_diagnostic_core/model/writeParameterPidModel.dart';
import 'package:ap_dongle_diagnostic_core/model/writeParameterResponse.dart';
import 'package:ap_dongle_diagnostic_core/structure/flashConfig.dart';
import 'package:ecu_seedkeypcl_core/ecu_seedkeypcl_core.dart';

class UDSDiagnostic {
  DongleCommWin? dongleComm;
  ECUCalculateSeedkey? calculateSeedkey;

  UDSDiagnostic({this.dongleComm, this.calculateSeedkey});

  Future<ApReadDtcResponseModel> readDTC(ReadDTCIndex readDtcIndex) async {
    String returnStatus = "ECU_ERROR";
    List<List<String>> dtcArray = [];
    int dtcCounter = 0;

    try {
      dongleComm!.saveLog("------Start Read Dtc: $readDtcIndex------\n");

      // ─── CASE 1: UDS & KWP 2-BYTE/3-BYTE ──────────────────────────────────────
      if ([
        ReadDTCIndex.KWP_2BYTE_DTC,
        ReadDTCIndex.UDS_2BYTE12_DTC,
        ReadDTCIndex.UDS_2BYTE13_DTC,
        ReadDTCIndex.UDS_3BYTE_DTC,
      ].contains(readDtcIndex)) {
        int frameLength = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC) ? 4 : 3;
        String dtcFunction = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC)
            ? "1800FFFF"
            : "1902FF";

        final response = await dongleComm!.canTxRx(frameLength, dtcFunction);
        String responseStatus = response.ecuResponseStatus ?? "";
        final rxArray = response.actualDataBytes;

        if ((responseStatus == "NOERROR" || responseStatus == "NO_ERROR") &&
            rxArray != null) {
          returnStatus = "NO_ERROR";

          // ✅ FIX: UDS always 4 bytes per DTC (3 code + 1 status)
          int step = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC) ? 3 : 4;
          int startIdx = (readDtcIndex == ReadDTCIndex.KWP_2BYTE_DTC) ? 2 : 3;

          if (rxArray.length > startIdx) {
            int noOfDtcCalculated = (rxArray.length - startIdx) ~/ step;

            for (int i = 0; i < noOfDtcCalculated; i++) {
              int p = startIdx + (i * step);
              if (p + 3 >= rxArray.length) break;

              // ✅ FIX: Skip padding/null entries
              if (rxArray[p] == 0x00 &&
                  rxArray[p + 1] == 0x00 &&
                  rxArray[p + 2] == 0x00)
                continue;

              int typeBits = (rxArray[p] & 0xC0) >> 6;
              String type = ["P", "C", "B", "U"][typeBits];

              String h0 = (rxArray[p] & 0x3F)
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase();
              String h1 = rxArray[p + 1]
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase();
              String h2 = rxArray[p + 2]
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase();

              String fullCode = "";
              if (readDtcIndex == ReadDTCIndex.UDS_3BYTE_DTC) {
                fullCode = "$type$h0$h1-$h2";
              } else if (readDtcIndex == ReadDTCIndex.UDS_2BYTE13_DTC) {
                fullCode = "$type$h0$h2";
              } else {
                fullCode = "$type$h0$h1";
              }

              // ✅ FIX: 0x50 status byte handling (stored/confirmed not currently failing)
              int sByte = rxArray[p + 3];
              String dtcStatusDesc;

              if ((sByte & 0x01) != 0) {
                dtcStatusDesc = "Active";
              } else if ((sByte & 0x08) != 0) {
                dtcStatusDesc = "History";
              } else if ((sByte & 0x04) != 0) {
                dtcStatusDesc = "Pending";
              } else if ((sByte & 0x20) != 0) {
                // 0x50 = testNotCompletedSinceLastClear — treat as History
                dtcStatusDesc = "History";
              } else if (sByte == 0x00) {
                continue; // skip null status
              } else {
                dtcStatusDesc = "History"; // any other stored status
              }

              dtcArray.add([fullCode, dtcStatusDesc]);
              dtcCounter++;
            }
          }
        } else {
          returnStatus = responseStatus.isEmpty
              ? "ECUERROR_NORESPONSEFROMECU"
              : responseStatus;
        }
      }
      // ─── CASE 2: GENERIC OBD ──────────────────────────────────────────────────
      else if (readDtcIndex == ReadDTCIndex.GENERIC_OBD) {
        var resp03 = await dongleComm!.canTxRx(1, "03");
        if (resp03.ecuResponseStatus == "NOERROR") {
          var resp07 = await dongleComm!.canTxRx(1, "07");
          if (resp07.ecuResponseStatus == "NOERROR") {
            returnStatus = "NO_ERROR";

            void processOBD(List<int>? d, String label) {
              if (d == null || d.length < 2) return;
              int count = d[1];
              for (int i = 0; i < count; i++) {
                int p = (i * 2) + 2;
                if (p + 1 >= d.length) break;
                int high = d[p];
                String t = ["P", "C", "B", "U"][(high & 0xC0) >> 6];
                String code =
                    (high & 0x3F)
                        .toRadixString(16)
                        .padLeft(2, '0')
                        .toUpperCase() +
                    d[p + 1].toRadixString(16).padLeft(2, '0').toUpperCase();
                dtcArray.add(["$t$code", label]);
                dtcCounter++;
              }
            }

            processOBD(resp03.actualDataBytes, "Current");
            processOBD(resp07.actualDataBytes, "Pending");
          }
        }
      }
      // ─── CASE 3: J1939 (SPN/FMI) ──────────────────────────────────────────────
      else if (readDtcIndex == ReadDTCIndex.UDS_J1939) {
        var resp = await dongleComm!.canTxRx(3, "1902FF");
        if (resp.ecuResponseStatus == "NOERROR" &&
            resp.actualDataBytes != null) {
          returnStatus = "NO_ERROR";
          var data = resp.actualDataBytes!;
          int count = (data.length - 3) ~/ 4;
          for (int i = 0; i < count; i++) {
            int p = 3 + (i * 4);
            if (p + 3 >= data.length) break;
            int spn =
                data[p] | (data[p + 1] << 8) | ((data[p + 2] & 0xE0) << 11);
            int fmi = data[p + 2] & 0x1F;
            int s = data[p + 3];
            String statusTxt = (s & 0x01 != 0)
                ? "Active"
                : ((s & 0x08 != 0) ? "History" : "Stored");

            dtcArray.add([spn.toString(), statusTxt, fmi.toString()]);
            dtcCounter++;
          }
        }
      }
      // ─── CASE 4: UDS GCU (Decimal ID) ─────────────────────────────────────────
      else if (readDtcIndex == ReadDTCIndex.UDS_GCU) {
        var resp = await dongleComm!.canTxRx(3, "1902FF");
        if (resp.ecuResponseStatus == "NOERROR" &&
            resp.actualDataBytes != null) {
          returnStatus = "NO_ERROR";
          var data = resp.actualDataBytes!;
          int count = (data.length - 3) ~/ 4;
          for (int i = 0; i < count; i++) {
            int p = 3 + (i * 4);
            if (p + 3 >= data.length) break;
            int id = (data[p] << 16) | (data[p + 1] << 8) | data[p + 2];
            String desc = "Unknown";
            switch (data[p + 3]) {
              case 0xF1:
                desc = "Active Warning";
                break;
              case 0xF2:
                desc = "Inactive Warning";
                break;
              case 0xF3:
                desc = "Active Shutdown";
                break;
              case 0xF4:
                desc = "Inactive Shutdown";
                break;
            }
            dtcArray.add([id.toString(), desc]);
            dtcCounter++;
          }
        }
      }
      // ─── CASE 5: KWP PRIMITIVE ────────────────────────────────────────────────
      else if (readDtcIndex == ReadDTCIndex.KWP_PRIMITIVE) {
        var resp = await dongleComm!.canTxRx(1, "13");
        if (resp.ecuResponseStatus == "NOERROR" &&
            resp.actualDataBytes != null) {
          returnStatus = "NO_ERROR";
          int count = resp.actualDataBytes![1];
          for (int i = 0; i < count; i++) {
            int p = (i * 2) + 2;
            if (p + 1 >= resp.actualDataBytes!.length) break;
            int b1 = resp.actualDataBytes![p];
            String t = ["P", "C", "B", "U"][(b1 & 0xC0) >> 6];
            String code =
                (b1 & 0x3F).toRadixString(16).padLeft(2, '0').toUpperCase() +
                resp.actualDataBytes![p + 1]
                    .toRadixString(16)
                    .padLeft(2, '0')
                    .toUpperCase();
            dtcArray.add(["$t$code", "Stored"]);
            dtcCounter++;
          }
        }
      }
    } catch (ex) {
      print("Error decoding DTC: $ex");
      returnStatus = "DECODING_ERROR";
    }

    return ApReadDtcResponseModel(
      dtcs: dtcArray,
      noOfDtc: dtcCounter,
      status: returnStatus,
    );
  }

  // Future<FreezeFrameResponseModel> getFreezeFrame(
  //   String dtcCode,
  //   FreezeFrameModel freezeFrame,
  //   List<ReadParameterPID>? envSnapshotList,
  // ) async {
  //   FreezeFrameResponseModel freezeFrameResponseModel =
  //       FreezeFrameResponseModel();
  //   List<FreezeFrame> dummyList = [];

  //   try {
  //     dongleComm!.saveLog("------Start Read Dtc ($dtcCode)------\n");

  //     String completeCode = "";
  //     if (dtcCode.contains("-")) {
  //       var parts = dtcCode.split('-');
  //       completeCode = parts[0] + parts[1];
  //     } else {
  //       completeCode = dtcCode;
  //     }

  //     int dtcTypeBits = 0;
  //     if (completeCode.startsWith('P')) {
  //       dtcTypeBits = 0x00;
  //     } else if (completeCode.startsWith('C')) {
  //       dtcTypeBits = 0x01;
  //     } else if (completeCode.startsWith('B')) {
  //       dtcTypeBits = 0x02;
  //     } else if (completeCode.startsWith('U')) {
  //       dtcTypeBits = 0x03;
  //     }

  //     // Remove the prefix character (P, C, B, or U)
  //     String hexCodeOnly = completeCode.substring(1);

  //     // Convert hex string to byte list
  //     Uint8List frame = hexToBytes(hexCodeOnly);

  //     // Apply DTC type bits to the first byte
  //     frame[0] = (frame[0] | (dtcTypeBits << 6));

  //     // Request SID 19 04 (ReadDTCFreezeFrameData)
  //     var responseBytes = await dongleComm!.canTxRx(
  //       frame.length + 3,
  //       "1904${byteArrayToHex(frame)}FF",
  //     );

  //     String? ecuStatus = responseBytes.ecuResponseStatus;

  //     if (ecuStatus == null || ecuStatus.isEmpty) {
  //       freezeFrameResponseModel.status = "Status not found.";
  //     } else if (ecuStatus == "NOERROR") {
  //       int index = 8; // Starting index based on your printic
  //       Uint8List? actualData = responseBytes.actualDataBytes;
  //       // 1. Check if the list exists before starting
  //       if (freezeFrame.freezeFrameCode != null) {
  //         for (var item in freezeFrame.freezeFrameCode!) {
  //           FreezeFrame freeze = FreezeFrame(
  //             code: item.code,
  //             priority: item.priority,
  //           );

  //           try {
  //             int itemCode = int.parse(item.code ?? '', radix: 16);
  //             int highByte = (itemCode & 0xFF00) >> 8;
  //             int lowByte = (itemCode & 0x00FF);

  //             // Ensure actualData isn't null before entering nested loops
  //             if (actualData != null) {
  //               bool found = false;

  //               // First search pass
  //               for (; index < actualData.length - 1; index++) {
  //                 if (actualData[index] == highByte &&
  //                     actualData[index + 1] == lowByte) {
  //                   freeze.value = _getFreezeValue(responseBytes, item, index);
  //                   found = true;
  //                   break;
  //                 }
  //               }

  //               // Second search pass from start if not found
  //               if (!found) {
  //                 for (index = 0; index < actualData.length - 1; index++) {
  //                   if (actualData[index] == highByte &&
  //                       actualData[index + 1] == lowByte) {
  //                     freeze.value = _getFreezeValue(
  //                       responseBytes,
  //                       item,
  //                       index,
  //                     );
  //                     break;
  //                   }
  //                 }
  //               }
  //             }
  //           } catch (ex) {
  //             freeze.value = "Exception";
  //           }

  //           // Advance index safely
  //           index += (2 + (item.length ?? 0));
  //           dummyList.add(freeze);
  //         }
  //       }

  //       // Process Environmental Snapshots
  //       if (envSnapshotList != null && envSnapshotList.isNotEmpty) {
  //         for (var pid in envSnapshotList) {
  //           try {
  //             int receivedCode = 0;
  //             int itemCode = int.parse(pid.pid ?? '', radix: 16);
  //             int highByte = (itemCode & 0xFF00) >> 8;
  //             int lowByte = (itemCode & 0x00FF);

  //             for (; index < actualData!.length - 1; index++) {
  //               if (actualData[index] == highByte &&
  //                   actualData[index + 1] == lowByte) {
  //                 receivedCode =
  //                     (actualData[index] << 8) | actualData[index + 1];
  //                 break;
  //               }
  //             }

  //             if (receivedCode == 0) index = 0;

  //             if (receivedCode == itemCode) {
  //               // Prepare subset of data for conversion
  //               // The (pid.totalLen ?? 0) ensures that if totalLen is null, it treats it as 0.
  //               Uint8List subArray = actualData.sublist(
  //                 index,
  //                 index + (pid.totalLen ?? 0) + 2,
  //               );
  //               ResponseArrayStatus statusObj = ResponseArrayStatus(
  //                 actualDataBytes: subArray,
  //                 ecuResponseStatus: "NOERROR",
  //               );

  //               var pidResponse = await pidConvertResponse(statusObj, pid);

  //               if (pidResponse.status == "NOERROR") {
  //                 for (var variable in pidResponse.variables ?? []) {
  //                   dummyList.add(
  //                     FreezeFrame(code: pid.pid, value: variable.responseValue),
  //                   );
  //                 }
  //               } else {
  //                 // Adding ?? [] ensures that if pid.variables is null, the loop simply doesn't run.
  //                 for (var _ in pid.variables ?? []) {
  //                   dummyList.add(
  //                     FreezeFrame(code: pid.pid, value: pidResponse.status),
  //                   );
  //                 }
  //               }
  //             } else {
  //               for (var _ in pid.variables ?? []) {
  //                 dummyList.add(FreezeFrame(code: pid.pid, value: "NA"));
  //               }
  //             }
  //           } catch (ex) {
  //             for (var _ in pid.variables ?? []) {
  //               dummyList.add(FreezeFrame(code: pid.pid, value: "Exception"));
  //             }
  //           }
  //         }
  //       }

  //       freezeFrameResponseModel.status = ecuStatus;
  //       freezeFrameResponseModel.dtcs = dummyList;
  //     } else {
  //       freezeFrameResponseModel.status = ecuStatus;
  //     }
  //   } catch (ex) {
  //     freezeFrameResponseModel.status = ex.toString();
  //   }

  //   return freezeFrameResponseModel;
  // }

  // String byteArrayToHex(Uint8List bytes) {
  //   return bytes
  //       .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
  //       .join('');
  // }

  // String _getFreezeValue(
  //   ResponseArrayStatus responseBytes,
  //   FreezeFrameCode item,
  //   int index,
  // ) {
  //   String retValue = "";

  //   // Get received code (PID) from the first two bytes at index
  //   int receivedCode =
  //       (responseBytes.actualDataBytes![index] << 8) |
  //       responseBytes.actualDataBytes![index + 1];

  //   // Parse the expected item code from hex string
  //   int itemCode = int.parse(item.code ?? "0", radix: 16);

  //   if (receivedCode == itemCode) {
  //     int len = item.length ?? 0;
  //     int startPos = index + 2 + (item.bytePosition ?? 1) - 1;

  //     // Extract the raw value bytes
  //     Uint8List value = Uint8List.fromList(
  //       responseBytes.actualDataBytes!.sublist(startPos, startPos + len),
  //     );

  //     if (item.messageType == "CONTINUOUS" ||
  //         item.messageType == "IEEE754_FLOAT") {
  //       if (len <= 4) {
  //         // Create a 4-byte buffer for conversion (equivalent to Resize in C#)
  //         Uint8List buffer = Uint8List(4);

  //         // C# uses Array.Reverse + BitConverter (which is Little Endian)
  //         // In Dart, we can just read Big Endian directly or fill the buffer
  //         for (int i = 0; i < value.length; i++) {
  //           buffer[3 - i] = value[value.length - 1 - i];
  //         }

  //         ByteData bd = ByteData.sublistView(buffer);
  //         int unsignedPidIntValue = bd.getUint32(0, Endian.little);

  //         if (item.messageType == "CONTINUOUS") {
  //           double floatPidValue =
  //               (unsignedPidIntValue * (item.resolution ?? 1.0)) +
  //               (item.offset ?? 0.0);
  //           retValue = floatPidValue
  //               .toStringAsFixed(3)
  //               .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  //           // Note: replaceAll printic above mimics the "0.###" format
  //         } else {
  //           // IEEE754 Float
  //           double floatValue = bd.getFloat32(0, Endian.little);
  //           double floatPidValue =
  //               (floatValue * (item.resolution ?? 1.0)) + (item.offset ?? 0.0);
  //           retValue = floatPidValue
  //               .toStringAsFixed(3)
  //               .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  //         }
  //       }
  //     } else if (item.messageType == "ASCII") {
  //       retValue = utf8.decode(value, allowMalformed: true);
  //     } else if (item.messageType == "BCD" || item.messageType == "HEX") {
  //       retValue = value
  //           .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
  //           .join("");
  //     } else if (item.messageType == "ENUMRATED") {
  //       Uint8List buffer = Uint8List(4);
  //       for (int i = 0; i < value.length; i++) {
  //         buffer[3 - i] = value[value.length - 1 - i];
  //       }
  //       ByteData bd = ByteData.sublistView(buffer);
  //       int unsignedPidIntValue = bd.getUint32(0, Endian.little);

  //       if (item.bitcoded == true) {
  //         int lsbStartBit = item.startBit ?? 1;
  //         int mask = 0;
  //         for (int x = 0; x < (item.noofBits ?? 0); x++) {
  //           mask |= (0x01 << (lsbStartBit - 1));
  //           lsbStartBit++;
  //         }
  //         unsignedPidIntValue =
  //             (unsignedPidIntValue & mask) >> ((item.startBit ?? 1) - 1);
  //       }

  //       retValue = unsignedPidIntValue.toString();

  //       if (item.freezeFrameMessages != null) {
  //         for (var msg in item.freezeFrameMessages!) {
  //           double? code = double.tryParse(msg.code ?? "");
  //           if (code != null && code.toInt() == unsignedPidIntValue) {
  //             retValue = msg.message ?? "";
  //             break;
  //           }
  //         }
  //       }
  //     }
  //   } else {
  //     retValue = "NA";
  //   }

  //   return retValue;
  // }

  Future<FreezeFrameResponseModel> getFreezeFrame(
    String dtcCode,
    FreezeFrameModel freezeFrame,
    List<ReadParameterPID>? envSnapshotList,
  ) async {
    FreezeFrameResponseModel freezeFrameResponseModel =
        FreezeFrameResponseModel();
    List<FreezeFrame> dummyList = [];

    try {
      dongleComm!.saveLog("------Start Read Dtc ($dtcCode)------\n");

      // 1. Sanitize DTC code string safely
      String completeCode = dtcCode.toUpperCase().replaceAll('-', '').trim();

      int dtcTypeBits = 0;
      if (completeCode.startsWith('P')) {
        dtcTypeBits = 0x00;
      } else if (completeCode.startsWith('C')) {
        dtcTypeBits = 0x01;
      } else if (completeCode.startsWith('B')) {
        dtcTypeBits = 0x02;
      } else if (completeCode.startsWith('U')) {
        dtcTypeBits = 0x03;
      }

      // Safeguard: Ensure we actually have characters left after removing the prefix
      String hexCodeOnly = completeCode.length > 1
          ? completeCode.substring(1)
          : completeCode;

      print("🔧 Sanitized DTC Code for UDS: From '$dtcCode' to '$hexCodeOnly'");

      // Convert hex string to byte list safely
      Uint8List frame = hexToBytes(hexCodeOnly);

      if (frame.isEmpty) {
        freezeFrameResponseModel.status = "Invalid DTC hex format.";
        return freezeFrameResponseModel;
      }

      // Apply DTC type bits to the first byte
      frame[0] = (frame[0] | (dtcTypeBits << 6));

      // Request SID 19 04 (ReadDTCFreezeFrameData)
      var responseBytes = await dongleComm!.canTxRx(
        frame.length + 3,
        "1904${byteArrayToHex(frame)}FF",
      );

      String? ecuStatus = responseBytes.ecuResponseStatus;

      if (ecuStatus == null || ecuStatus.isEmpty) {
        freezeFrameResponseModel.status = "Status not found.";
      } else if (ecuStatus == "NOERROR") {
        int index = 8;
        Uint8List? actualData = responseBytes.actualDataBytes;

        // Process Metadata Parameter Codes
        if (freezeFrame.freezeFrameCode != null) {
          for (var item in freezeFrame.freezeFrameCode!) {
            FreezeFrame freeze = FreezeFrame(
              code: item.code,
              priority: item.priority,
            );

            try {
              // ✅ FIXED: Guard against trailing spaces/invalid symbols using int.tryParse
              String cleanedItemCode = (item.code ?? '').trim().replaceAll(
                RegExp(r'[^0-9a-fA-F]'),
                '',
              );
              int? itemCode = int.tryParse(cleanedItemCode, radix: 16);

              if (itemCode == null || cleanedItemCode.isEmpty) {
                print(
                  "⚠️ Skipping freezeFrame processing: '${item.code}' is an invalid hex representation.",
                );
                freeze.value = "NA";
                dummyList.add(freeze);
                continue;
              }

              int highByte = (itemCode & 0xFF00) >> 8;
              int lowByte = (itemCode & 0x00FF);

              if (actualData != null) {
                bool found = false;

                // First search pass
                for (; index < actualData.length - 1; index++) {
                  if (actualData[index] == highByte &&
                      actualData[index + 1] == lowByte) {
                    freeze.value = _getFreezeValue(responseBytes, item, index);
                    found = true;
                    break;
                  }
                }

                // Second search pass from start if not found
                if (!found) {
                  for (index = 0; index < actualData.length - 1; index++) {
                    if (actualData[index] == highByte &&
                        actualData[index + 1] == lowByte) {
                      freeze.value = _getFreezeValue(
                        responseBytes,
                        item,
                        index,
                      );
                      break;
                    }
                  }
                }
              }
            } catch (ex) {
              freeze.value = "Exception";
            }

            index += (2 + (item.length ?? 0));
            dummyList.add(freeze);
          }
        }

        // Process Environmental Snapshots
        if (envSnapshotList != null && envSnapshotList.isNotEmpty) {
          for (var pid in envSnapshotList) {
            try {
              int receivedCode = 0;

              // ✅ FIXED: Guard snapshot records from throwing string index crashes
              String cleanedPid = (pid.pid ?? '').trim().replaceAll(
                RegExp(r'[^0-9a-fA-F]'),
                '',
              );
              int? itemCode = int.tryParse(cleanedPid, radix: 16);

              if (itemCode == null || cleanedPid.isEmpty) {
                for (var _ in pid.variables ?? []) {
                  dummyList.add(FreezeFrame(code: pid.pid, value: "NA"));
                }
                continue;
              }

              int highByte = (itemCode & 0xFF00) >> 8;
              int lowByte = (itemCode & 0x00FF);

              for (; index < actualData!.length - 1; index++) {
                if (actualData[index] == highByte &&
                    actualData[index + 1] == lowByte) {
                  receivedCode =
                      (actualData[index] << 8) | actualData[index + 1];
                  break;
                }
              }

              if (receivedCode == 0) index = 0;

              if (receivedCode == itemCode) {
                Uint8List subArray = actualData.sublist(
                  index,
                  index + (pid.totalLen ?? 0) + 2,
                );
                ResponseArrayStatus statusObj = ResponseArrayStatus(
                  actualDataBytes: subArray,
                  ecuResponseStatus: "NOERROR",
                );

                var pidResponse = await pidConvertResponse(statusObj, pid);

                if (pidResponse.status == "NOERROR") {
                  for (var variable in pidResponse.variables ?? []) {
                    dummyList.add(
                      FreezeFrame(code: pid.pid, value: variable.responseValue),
                    );
                  }
                } else {
                  for (var _ in pid.variables ?? []) {
                    dummyList.add(
                      FreezeFrame(code: pid.pid, value: pidResponse.status),
                    );
                  }
                }
              } else {
                for (var _ in pid.variables ?? []) {
                  dummyList.add(FreezeFrame(code: pid.pid, value: "NA"));
                }
              }
            } catch (ex) {
              for (var _ in pid.variables ?? []) {
                dummyList.add(FreezeFrame(code: pid.pid, value: "Exception"));
              }
            }
          }
        }

        freezeFrameResponseModel.status = ecuStatus;
        freezeFrameResponseModel.dtcs = dummyList;
      } else {
        freezeFrameResponseModel.status = ecuStatus;
      }
    } catch (ex) {
      freezeFrameResponseModel.status = ex.toString();
    }

    return freezeFrameResponseModel;
  }

  // ✅ FIXED: Robust hex parsing string conversion method
  Uint8List hexToBytes(String hex) {
    String normalized = hex.trim().replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.length % 2 != 0) {
      normalized = '0' + normalized; // Pad odd sizes safely
    }

    if (normalized.isEmpty) return Uint8List(0);

    var result = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  String byteArrayToHex(Uint8List bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('');
  }

  String _getFreezeValue(
    ResponseArrayStatus responseBytes,
    FreezeFrameCode item,
    int index,
  ) {
    String retValue = "";

    int receivedCode =
        (responseBytes.actualDataBytes![index] << 8) |
        responseBytes.actualDataBytes![index + 1];

    int itemCode = int.tryParse((item.code ?? "0").trim(), radix: 16) ?? 0;

    if (receivedCode == itemCode) {
      int len = item.length ?? 0;
      int startPos = index + 2 + (item.bytePosition ?? 1) - 1;

      Uint8List value = Uint8List.fromList(
        responseBytes.actualDataBytes!.sublist(startPos, startPos + len),
      );

      if (item.messageType == "CONTINUOUS" ||
          item.messageType == "IEEE754_FLOAT") {
        if (len <= 4) {
          // ✅ Match C# exactly: Array.Reverse(value) then Array.Resize to 4 (zero-pad at end)
          Uint8List reversed = Uint8List(4); // zero-initialized = zero-padded
          for (int i = 0; i < value.length; i++) {
            reversed[i] =
                value[value.length - 1 - i]; // reverse into positions 0..len-1
          }
          // positions len..3 remain 0x00 — matches C# Array.Resize behavior

          ByteData bd = ByteData.sublistView(reversed);
          int unsignedPidIntValue = bd.getUint32(0, Endian.little);

          if (item.messageType == "CONTINUOUS") {
            double floatPidValue =
                (unsignedPidIntValue * (item.resolution ?? 1.0)) +
                (item.offset ?? 0.0);
            retValue = floatPidValue
                .toStringAsFixed(3)
                .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
          } else {
            // IEEE754_FLOAT
            double floatValue = bd.getFloat32(0, Endian.little);
            double floatPidValue =
                (floatValue * (item.resolution ?? 1.0)) + (item.offset ?? 0.0);
            retValue = floatPidValue
                .toStringAsFixed(3)
                .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
          }
        }
      } else if (item.messageType == "ASCII") {
        retValue = utf8.decode(value, allowMalformed: true);
      } else if (item.messageType == "BCD" || item.messageType == "HEX") {
        retValue = value
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join("");
      } else if (item.messageType == "ENUMRATED") {
        // ✅ Same fix: reverse then zero-pad to 4
        Uint8List reversed = Uint8List(4);
        for (int i = 0; i < value.length; i++) {
          reversed[i] = value[value.length - 1 - i];
        }

        ByteData bd = ByteData.sublistView(reversed);
        int unsignedPidIntValue = bd.getUint32(0, Endian.little);

        if (item.bitcoded == true) {
          int lsbStartBit = item.startBit ?? 1;
          int mask = 0;
          for (int x = 0; x < (item.noofBits ?? 0); x++) {
            mask |= (0x01 << (lsbStartBit - 1));
            lsbStartBit++;
          }
          unsignedPidIntValue =
              (unsignedPidIntValue & mask) >> ((item.startBit ?? 1) - 1);
        }

        retValue = unsignedPidIntValue.toString();

        if (item.freezeFrameMessages != null) {
          for (var msg in item.freezeFrameMessages!) {
            double? code = double.tryParse(msg.code ?? "");
            if (code != null && code.toInt() == unsignedPidIntValue) {
              retValue = msg.message ?? "";
              break;
            }
          }
        }
      }
    } else {
      retValue = "NA";
    }

    return retValue;
  }

  Future<List<ReadParameterResponseIvn>> ivnReadParameters(
    int noOfParameters,
    List<IVNSelectedPID> readParameterCollection,
  ) async {
    List<ReadParameterResponseIvn> databyteArray = [];

    try {
      String dataValue = "";

      // Outer loop through collection
      for (int i = 0; i < readParameterCollection.length; i++) {
        // Accessing first element's frame_ids as per C# printic
        var frameIds = readParameterCollection.first.frameIds ?? [];

        for (var item in frameIds) {
          var getivnframe = await dongleComm!.canIvnRxFrame(item.framId ?? '');

          if (getivnframe.ecuResponseStatus == "NOERROR") {
            var pidName = item.pidDescription;
            var unit = item.unit;
            String pidType = item.messageType.toString();
            int pidStartByte = int.parse(item.startByte.toString());
            int pidNoOfBytes = int.parse(item.byte.toString());
            var pidBitcoded = item.bitCoded;

            int pidStartBit = 0;
            int pidNoOfBits = 0;

            if (item.bitCoded != "0") {
              pidStartBit = int.parse(item.startBit.toString());
              pidNoOfBits = int.parse(item.noOfBits.toString());
            }

            double pidResolution = double.parse(item.resolution.toString());
            double pidOffset = double.parse(item.offset.toString());
            Uint8List actualFrameBytes = Uint8List.fromList(
              getivnframe.actualFrameBytes as List<int>,
            );

            if (pidType.contains("CONTINUOUS")) {
              print("---START CONTINUOUS--");
              int unsignedPidIntValue = 0;

              // Handle Endianness
              if (item.endian.toString().contains("LITTLE")) {
                // Reverse the specific range in the byte array
                List<int> subList = actualFrameBytes.sublist(
                  pidStartByte - 1,
                  pidStartByte - 1 + pidNoOfBytes,
                );
                List<int> reversed = subList.reversed.toList();
                actualFrameBytes.setRange(
                  pidStartByte - 1,
                  pidStartByte - 1 + pidNoOfBytes,
                  reversed,
                );
              }

              // Construct Integer from Bytes
              for (int l = 0; l < pidNoOfBytes; l++) {
                unsignedPidIntValue |=
                    (actualFrameBytes[pidStartByte - 1 + l] <<
                    ((pidNoOfBytes - 1 - l) * 8));
              }

              // Bitwise Masking
              if (pidBitcoded == "1") {
                if (pidNoOfBytes == 1) {
                  int mask = 0;
                  int tempStartBit = pidStartBit;
                  for (int x = 0; x < pidNoOfBits; x++) {
                    mask |= (1 << (8 - tempStartBit));
                    tempStartBit++;
                  }
                  unsignedPidIntValue =
                      (unsignedPidIntValue & mask) >>
                      ((pidNoOfBytes * 8) - pidStartBit - pidNoOfBits + 1);
                } else {
                  int mask =
                      ((pow(16, pidNoOfBytes * 2).toInt() - 1)) >>
                      ((pidNoOfBytes * 8) - pidNoOfBits - pidStartBit + 1);
                  unsignedPidIntValue =
                      (unsignedPidIntValue >>
                          ((pidNoOfBytes * 8) -
                              pidNoOfBits -
                              pidStartBit +
                              1)) &
                      mask;
                }
              }

              double floatPidValue = 0.0;

              // Handle Signed vs Unsigned (2's Complement)
              if (pidType == "CONTINUOUS_2S_COMPLEMENT" ||
                  item.numType == "SIGNED") {
                int signedValue = unsignedPidIntValue;

                // Manual sign extension based on byte count
                if (pidNoOfBytes == 1) {
                  signedValue = Int8List.fromList([unsignedPidIntValue])[0];
                } else if (pidNoOfBytes == 2) {
                  signedValue = Int16List.fromList([unsignedPidIntValue])[0];
                } else {
                  // For 3 or 4 bytes, treat as 32-bit signed
                  signedValue = Int32List.fromList([unsignedPidIntValue])[0];
                }
                floatPidValue = (signedValue * pidResolution) + pidOffset;
              } else {
                floatPidValue =
                    (unsignedPidIntValue * pidResolution) + pidOffset;
              }

              dataValue = floatPidValue.toString();
              print("---END CONTINUOUS--");
            } else if (pidType == "ASCII") {
              print("---START ASCII--");
              List<int> outputlivepararray = [];
              for (int k = 0; k < pidNoOfBytes; k++) {
                outputlivepararray.add(actualFrameBytes[pidStartByte - 1 + k]);
              }
              // Reverse to match C# printic: outputlivepararray[pidNoOfBytes - 1 - k]
              dataValue = utf8.decode(
                outputlivepararray.reversed.toList(),
                allowMalformed: true,
              );
              if (dataValue.contains('\x00')) dataValue = "0";
              print("---END ASCII--");
            } else if (pidType == "BCD") {
              print("---START BCD--");
              List<int> outputlivepararray = [];
              for (int k = 0; k < pidNoOfBytes; k++) {
                outputlivepararray.add(actualFrameBytes[pidStartByte - 1 + k]);
              }
              // Convert to Hex String as BCD replacement
              dataValue = outputlivepararray.reversed
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join("");
              print("---END BCD--");
            } else if (pidType == "ENUMRATED") {
              int unsignedPidIntValue = 0;
              for (int m = 0; m < pidNoOfBytes; m++) {
                unsignedPidIntValue |=
                    (actualFrameBytes[pidStartByte - 1 + m] <<
                    ((pidNoOfBytes - 1 - m) * 8));
              }

              if (pidBitcoded == "1") {
                int startBit = pidStartBit;
                int mask = 0;
                for (int x = 0; x < pidNoOfBits; x++) {
                  mask |= (1 << (8 - startBit));
                  if (item.endian.toString().contains("LITTLE")) {
                    startBit--;
                  } else {
                    startBit++;
                  }
                }
                unsignedPidIntValue =
                    (unsignedPidIntValue & mask) >>
                    ((pidNoOfBytes * 8) - pidStartBit - pidNoOfBits + 1);
              }

              dataValue = unsignedPidIntValue.toString();

              // Map code to message if available
              var messages = item.frameOfPidMessage ?? [];
              for (var msg in messages) {
                if (int.tryParse(msg.code.toString()) == unsignedPidIntValue) {
                  dataValue = msg.message ?? '';
                }
              }
            }

            databyteArray.add(
              ReadParameterResponseIvn(
                pidName: pidName,
                responseValue: dataValue,
                status: "NO_ERROR",
                unit: unit,
              ),
            );
          } else if (getivnframe.ecuResponseStatus ==
              "ECUERROR_NORESPONSEFROMECU") {
            databyteArray.add(
              ReadParameterResponseIvn(
                pidName: item.pidDescription,
                responseValue: "ERR",
                status: "NoResponse",
                unit: "",
              ),
            );
          } else {
            databyteArray.add(
              ReadParameterResponseIvn(
                pidName: item.pidDescription,
                responseValue: "ERR",
                status: "ERROR",
                unit: "",
              ),
            );
          }
        }
      }
    } catch (e) {
      print("Error in IVN_ReadParameters: $e");
    }

    return databyteArray;
  }

  String byteArrayToString(Uint8List ba) {
    return ba
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('');
  }

  /// Converts a Hex String to a byte array, handling odd lengths by padding
  Uint8List hexStringToByteArray(String hex) {
    // Remove spaces equivalent to hex.Replace(" ", "")
    String cleanHex = hex.replaceAll(' ', '');

    // Handle odd lengths by padding with a leading zero
    if (cleanHex.length % 2 != 0) {
      cleanHex = '0' + cleanHex;
    }

    int numberChars = cleanHex.length;
    Uint8List bytes = Uint8List(numberChars ~/ 2);

    for (int i = 0; i < numberChars; i += 2) {
      bytes[i ~/ 2] = int.parse(cleanHex.substring(i, i + 2), radix: 16);
    }

    return bytes;
  }

  ClearDTCIndex _currentClearDTCIndex = ClearDTCIndex.KWP;

  /// Clears Diagnostic Trouble Codes based on the provided index
  Future<dynamic> clearDTC(
    ClearDTCIndex readDtcIndex,
    SeedKeyIndexType seedKeyIndex,
    WriteParameterIndex writeParameterIndex,
  ) async {
    _currentClearDTCIndex = readDtcIndex;
    dynamic responseBytes;

    dongleComm!.saveLog("------Start Clear Dtc------\n");

    if (_currentClearDTCIndex == ClearDTCIndex.UDS_4BYTES) {
      int frameLength = 4;
      responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFFFF");
    } else if (_currentClearDTCIndex == ClearDTCIndex.UDS_3BYTES) {
      int frameLength = 3;
      responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFF");
    } else if (_currentClearDTCIndex == ClearDTCIndex.GENERIC_OBD) {
      int frameLength = 1;
      responseBytes = await dongleComm!.canTxRx(frameLength, "04");
    } else if (_currentClearDTCIndex == ClearDTCIndex.KWP_PRIMITIVE) {
      int frameLength = 1;
      responseBytes = await dongleComm!.canTxRx(frameLength, "14");
    } else if (_currentClearDTCIndex == ClearDTCIndex.UDS_3BYTES_EXTENDED) {
      responseBytes = await enterExtendedSession(
        writeParameterIndex,
        seedKeyIndex,
      );

      // Dart uses 'is' for type checking. If true, 'responseBytes' is promoted to ResponseArrayStatus
      if (responseBytes is ResponseArrayStatus &&
          responseBytes.ecuResponseStatus == "NOERROR") {
        int frameLength = 3;
        responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFF");
      }
    } else if (_currentClearDTCIndex == ClearDTCIndex.UDS_4BYTES_EXTENDED) {
      responseBytes = await enterExtendedSession(
        writeParameterIndex,
        seedKeyIndex,
      );

      if (responseBytes is ResponseArrayStatus &&
          responseBytes.ecuResponseStatus == "NOERROR") {
        int frameLength = 4;
        responseBytes = await dongleComm!.canTxRx(frameLength, "14FFFFFF");
      }
    }

    return responseBytes;
  }

  Future<List<String>?> genericOBDSupportedPidList() async {
    try {
      // In Dart, we use a List<String> which can grow dynamically
      List<String> supportedPid = [];

      // Loop through the PID range (0x00 to 0x0B as per your C# loop)
      for (int i = 0; i < 0x0c; i++) {
        int frameLength = 2;

        // Convert i to a 2-character Hex string
        String pidHex = i.toRadixString(16).padLeft(2, '0').toUpperCase();

        var response = await dongleComm!.canTxRx(frameLength, "01$pidHex");

        // Check for positive response (Service 01 response is 0x41)
        if (response.ecuResponseStatus == "NOERROR" &&
            response.actualDataBytes!.isNotEmpty &&
            response.actualDataBytes![0] == 0x41) {
          int cmpResp = 0;
          Uint8List? data = response.actualDataBytes;
          int len = data!.length;

          // Construct a 32-bit integer from the variable length response bytes
          // Note: Data typically starts at index 2 for OBD PIDs (Mode 01, PID i)
          if (len == 2) {
            /* Do Nothing */
          } else if (len == 3) {
            cmpResp = (data[2] << 24);
          } else if (len == 4) {
            cmpResp = (data[2] << 24) | (data[3] << 16);
          } else if (len == 5) {
            cmpResp = (data[2] << 24) | (data[3] << 16) | (data[4] << 8);
          } else if (len >= 6) {
            cmpResp =
                (data[2] << 24) | (data[3] << 16) | (data[4] << 8) | data[5];
          }

          // Masking printic to find supported PIDs (32 bits per availability PID)
          for (int j = 31; j >= 0; j--) {
            // Check if the specific bit is set
            if ((cmpResp & (1 << j)) != 0) {
              // Calculate the PID number: i * 0x20 provides the base for the block
              // (e.g., 0100 returns support for 01-20)
              int pidVal = (i * 0x20) + (32 - j);

              String supportedHex = pidVal
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase();
              supportedPid.add("01$supportedHex");
            }
          }
        }
      }

      return supportedPid.isEmpty ? null : supportedPid;
    } catch (ex) {
      return null;
    }
  }

  Future<List<ReadParameterResponse>> readParameters(
    int noOfParameters,
    List<ReadParameterPID> readParameterCollection,
  ) async {
    List<ReadParameterResponse> databyteArray = [];
    dongleComm!.saveLog("------Start Read Pid------\n");

    for (int i = 0; i < readParameterCollection.length; i++) {
      var pidItem = readParameterCollection[i];

      // Total length of command
      var frameLength = pidItem.pid!.length ~/ 2;
      String dataValue = "";

      print(
        "---------------------START LOOP PID NAME-------------------------------------${pidItem.pid}\n",
      );
      dongleComm!.saveLog("------Start Read Pid (${pidItem.pid})------");

      // Send the parameter ID to the ECU
      var pidResponse = await dongleComm!.canTxRx(
        frameLength,
        pidItem.pid ?? '',
      );

      try {
        if (pidResponse.ecuResponseStatus == "NOERROR") {
          var pidBytesResponseString = byteArrayToString(
            pidResponse.actualDataBytes!,
          );
          print("Response received = $pidBytesResponseString");

          var status = pidResponse.ecuResponseStatus;
          Uint8List rxArray = pidResponse.actualDataBytes!;
          var inputLiveParaArray = readParameterCollection;

          double? floatPidValue = 0;
          var txFrameLength = frameLength;

          // Initialize output array
          Uint8List outputLiveParArray = Uint8List(
            txFrameLength - 2 > 0 ? txFrameLength - 2 : 0,
          );

          if (status == "NOERROR") {
            print("---NOERROR LOOP");
            List<ReadParameterVariableResponse> variableResponses = [];

            for (int k = 0; k < inputLiveParaArray[i].variables!.length; k++) {
              var currentVar = inputLiveParaArray[i].variables![k];
              print(
                "---------------------START LOOP VARIABLE NAME-------------------------------------${currentVar.pidName}",
              );

              if (currentVar.datatype == "CONTINUOUS" ||
                  currentVar.datatype == "IEEE754_FLOAT") {
                print("---START CONTINUOUS--");
                int unsignedPidIntValue = 0;

                // 1. Provide a default for the loop condition
                for (int j = 0; j < (currentVar.noOfBytes ?? 0); j++) {
                  // 2. Provide a default for the math (or use ! since the loop condition ensures it exists)
                  int totalBytes = currentVar.noOfBytes ?? 0;
                  int startByte = currentVar.startByte ?? 0;

                  int shift = (totalBytes - 1 - j) * 8;
                  int byteVal = rxArray[startByte + txFrameLength - 1 + j];

                  unsignedPidIntValue |= (byteVal << shift);
                }
                if (currentVar.isBitcoded == true) {
                  // Capture values safely at the start
                  int startBit = currentVar.startBit ?? 0;
                  int noofBits = currentVar.noofBits ?? 0;

                  int lsbStartBit = startBit;
                  int mask = 0;

                  // Use the local 'noofBits' which is guaranteed to be a non-nullable 'int'
                  for (int x = 0; x < noofBits; x++) {
                    mask |= (0x01 << (lsbStartBit - 1));
                    lsbStartBit++;
                  }

                  // Use the local 'startBit' here too
                  unsignedPidIntValue =
                      (unsignedPidIntValue & mask) >> (startBit - 1);
                }

                if (currentVar.readParameterIndex ==
                        ReadParameterIndex.uds2sCompliment &&
                    currentVar.offset == 1) {
                  // Use ?? 1.0 as a fallback for resolution to avoid multiplying by null
                  floatPidValue =
                      (unsignedPidIntValue * (currentVar.resolution ?? 1.0));
                } else if (currentVar.datatype == "IEEE754_FLOAT") {
                  // 1. Declare floatValue as a double
                  var bd = ByteData(4)..setUint32(0, unsignedPidIntValue);
                  double floatValue = bd.getFloat32(0);

                  // 2. Use fallbacks for resolution (1.0) and offset (0.0)
                  floatPidValue =
                      (floatValue * (currentVar.resolution ?? 1.0)) +
                      (currentVar.offset ?? 0.0);
                } else if (currentVar.numType == "SIGNED") {
                  // Sign extension logic for 1, 2, or 3 bytes into a 32-bit signed int
                  int signedPidIntValue = unsignedPidIntValue;

                  // Use ?? 0 to ensure bitWidth isn't calculated on a null
                  int noOfBytes = currentVar.noOfBytes ?? 0;
                  int bitWidth = noOfBytes * 8;

                  // Check if the sign bit is set (if bitWidth is 0, this skips correctly)
                  if (bitWidth > 0 &&
                      (unsignedPidIntValue & (1 << (bitWidth - 1))) != 0) {
                    signedPidIntValue = unsignedPidIntValue - (1 << bitWidth);
                  }

                  // Handle null resolution and offset
                  floatPidValue =
                      (signedPidIntValue * (currentVar.resolution ?? 1.0)) +
                      (currentVar.offset ?? 0.0);
                } else {
                  // Logic for UNSIGNED
                  floatPidValue =
                      (unsignedPidIntValue * (currentVar.resolution ?? 1.0)) +
                      (currentVar.offset ?? 0.0);
                }

                // Equivalent to ToString("0.###")
                String treePlace = floatPidValue
                    .toStringAsFixed(3)
                    .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
                dataValue = treePlace;
                print("---END CONTINUOUS--");
              } else if (currentVar.datatype == "ASCII") {
                print("---START ASCII--");

                // Use ?? 0 or ?? 1 to ensure these aren't null before math operations
                int startOffset = currentVar.startByte ?? 1;
                int count = currentVar.noOfBytes ?? 0;

                int start = startOffset + txFrameLength - 1;

                // sublist(start, end) where end is start + count
                // We use Uint8List.fromList to ensure type consistency if sublist returns a standard List
                Uint8List subArray = rxArray.sublist(start, start + count);

                try {
                  // ascii.decode comes from 'import dart:convert'
                  // .replaceAll("\x00", "") removes null terminators common in automotive buffers
                  dataValue = ascii
                      .decode(subArray)
                      .replaceAll("\x00", "")
                      .trim();
                } catch (e) {
                  dataValue = "Format Error";
                }

                print("---END ASCII--");
              } else if (currentVar.datatype == "BCD" ||
                  currentVar.datatype == "HEX") {
                print("---START BCD--");

                // 1. Safely handle potential nulls
                int startOffset = currentVar.startByte ?? 1;
                int byteCount = currentVar.noOfBytes ?? 0;

                int start = startOffset + txFrameLength - 1;

                // 2. Extract the sub-buffer
                Uint8List subArray = rxArray.sublist(start, start + byteCount);

                // 3. Remove trailing zeros (equivalent to TakeWhile in LINQ)
                // We use Uint8List.fromList to convert the Iterable back to the expected type
                var newData = Uint8List.fromList(
                  subArray.takeWhile((value) => value != 0x00).toList(),
                );

                // 4. Convert the bytes to a Hex string
                dataValue = byteArrayToString(newData);

                print("---END BCD--");
              } else if (currentVar.datatype == "ENUMRATED") {
                int pidIntValue = 0;

                // 1. Safe handling of nullable metadata
                int numBytes = currentVar.noOfBytes ?? 0;
                int startPos = currentVar.startByte ?? 1;

                for (int j = 0; j < numBytes; j++) {
                  // Calculate index and shift safely
                  int arrayIndex = startPos + txFrameLength - 1 + j;
                  int shiftAmount = (numBytes - 1 - j) * 8;

                  pidIntValue |= (rxArray[arrayIndex] << shiftAmount);
                }

                if (currentVar.isBitcoded == true) {
                  // 2. Safe local copies for bitmasking
                  int startBit = currentVar.startBit ?? 1;
                  int bitCount = currentVar.noofBits ?? 0;

                  int lsbStartBit = startBit;
                  int mask = 0;

                  for (int x = 0; x < bitCount; x++) {
                    mask |= (0x01 << (lsbStartBit - 1));
                    lsbStartBit++;
                  }

                  // Shift the masked value back to the LSB
                  pidIntValue = (pidIntValue & mask) >> (startBit - 1);
                }

                dataValue = pidIntValue.toString();

                // 3. Map numeric code to its human-readable message
                if (currentVar.messages != null &&
                    currentVar.messages!.isNotEmpty) {
                  for (var msgItem in currentVar.messages!) {
                    // Use double.tryParse to handle potential hex or numeric strings in the code field
                    double? parsedCode = double.tryParse(msgItem.code ?? "");
                    if (parsedCode != null &&
                        parsedCode.toInt() == pidIntValue) {
                      dataValue = msgItem.message ?? "";
                      break; // Stop once the matching message is found
                    }
                  }
                }
              } else if (currentVar.datatype == "IQA") {
                // Ensure we don't sublist past the array length
                if (rxArray.length > 3) {
                  dataValue = decodeIQA(rxArray.sublist(3));
                } else {
                  dataValue = "Invalid IQA Data";
                }
              }

              variableResponses.add(
                ReadParameterVariableResponse(
                  pidName: currentVar.pidName,
                  pidNumber: currentVar.pidNumber,
                  responseValue: dataValue,
                ),
              );
              print(" END LOOP VARIABLE NAME = ${currentVar.pidName}");
            }

            databyteArray.add(
              ReadParameterResponse(
                pidId: pidItem.pidId,
                status: pidResponse.ecuResponseStatus,
                dataArray: outputLiveParArray,
                pidName: "",
                variables: variableResponses,
              ),
            );
          } else {
            // ECU Error Case
            List<ReadParameterVariableResponse> variableResponses = [];
            // Adding ?? [] ensures the loop has a valid list to iterate over
            for (var item in inputLiveParaArray[i].variables ?? []) {
              variableResponses.add(
                ReadParameterVariableResponse(
                  pidName: item.pidName,
                  pidNumber: item.pidNumber,
                  responseValue: dataValue,
                ),
              );
            }
            databyteArray.add(
              ReadParameterResponse(
                status: pidResponse.ecuResponseStatus,
                dataArray: outputLiveParArray,
                pidId: pidItem.pidId,
                pidName: "",
                variables: variableResponses,
              ),
            );
          }
        } else {
          // ECU Positive Response Check failed
          List<ReadParameterVariableResponse> variableResponses = [];
          for (var item in readParameterCollection[i].variables ?? []) {
            variableResponses.add(
              ReadParameterVariableResponse(
                pidName: item.pidName,
                pidNumber: item.pidNumber,
                responseValue: dataValue,
              ),
            );
          }
          databyteArray.add(
            ReadParameterResponse(
              status: pidResponse.ecuResponseStatus,
              pidId: pidItem.pidId,
              pidName: "",
              variables: variableResponses,
            ),
          );
        }
      } catch (e) {
        databyteArray.add(ReadParameterResponse(status: e.toString()));
      }
      print(" END LOOP PID NAME = ${pidItem.pid}");
    }
    return databyteArray;
  }

  String decodeIQA(Uint8List rxData) {
    try {
      // IQA lookup table for alphanumeric characters
      const String iqaLookup = "ABCDEFGHIKLMNOPTRSTUVWXYZ12345678";

      // We expect at least 5 bytes to extract 7 characters
      if (rxData.length < 5) return "Invalid Data";

      List<int> iqaY = List.filled(7, 0);
      Uint8List iqaX = Uint8List(7);

      // Use 'rxData' (the parameter), not 'rxArray'
      iqaY[0] = (rxData[0] & 0xF8) >> 3;
      iqaY[1] =
          (((rxData[0] & 0x07) << 8) | (rxData[1] & 0xC0)) >>
          6; // Fixed: rxData[1]
      iqaY[2] = (rxData[1] & 0x3E) >> 1;
      iqaY[3] = (((rxData[1] & 0x01) << 8) | (rxData[2] & 0xF0)) >> 4;
      iqaY[4] = (((rxData[2] & 0x0F) << 8) | (rxData[3] & 0x80)) >> 7;
      iqaY[5] = (rxData[3] & 0x7C) >> 2;
      iqaY[6] = (rxData[4] & 0xF8) >> 3;

      // Map the unpacked 5-bit values to the lookup table
      for (int i = 0; i < 7; i++) {
        int index = iqaY[i];
        if (index < iqaLookup.length) {
          iqaX[i] = iqaLookup.codeUnitAt(index);
        } else {
          iqaX[i] = 63; // ASCII '?' for out of bounds
        }
      }

      // Convert the mapped bytes back to a string
      return ascii.decode(iqaX);
    } catch (e) {
      return "Error";
    }
  }

  Future<List<MappedPIDResponse>> readMappedParameters(
    List<ReadMappedPID> readParameterCollection,
  ) async {
    List<MappedPIDResponse> mappedPIDResponseList = [];

    for (int i = 0; i < readParameterCollection.length; i++) {
      var pidItem = readParameterCollection[i];

      MappedPIDResponse mappedPIDResponse = MappedPIDResponse(
        id: pidItem.id,
        name: pidItem.name,
        pidCode: pidItem.pidCode,
        unit: pidItem.unit,
      );

      try {
        // frameLength is PID hex length / 2
        int frameLength = (pidItem.pidCode ?? "").length ~/ 2;
        var pidResponse = await dongleComm!.canTxRx(
          frameLength,
          pidItem.pidCode ?? "",
        );

        if (pidResponse.ecuResponseStatus == "NOERROR") {
          Uint8List? rxArray = pidResponse.actualDataBytes;

          mappedPIDResponse.status = pidResponse.ecuResponseStatus;
          mappedPIDResponse.values = [];

          int totalLen = pidItem.totalLen ?? 0;
          int itemLength = pidItem.length ?? 0;

          for (int j = 0; j < totalLen; j += 2) {
            try {
              double? floatPidValue = 0;
              int unsignedPidIntValue = 0;

              // Construct integer from bytes
              for (int k = 0; k < itemLength; k++) {
                int byteIndex = j + k + frameLength;
                if (byteIndex < rxArray!.length) {
                  int shift = (itemLength - 1 - k) * 8;
                  unsignedPidIntValue |= (rxArray[byteIndex] << shift);
                }
              }

              if (pidItem.numType == "SIGNED") {
                int signedPidIntValue = unsignedPidIntValue;
                int bitWidth = itemLength * 8;

                // Sign extension for 1, 2, or 3 byte signed integers
                if (bitWidth > 0 &&
                    bitWidth < 64 &&
                    (unsignedPidIntValue & (1 << (bitWidth - 1))) != 0) {
                  signedPidIntValue = unsignedPidIntValue - (1 << bitWidth);
                }

                floatPidValue =
                    (signedPidIntValue * (pidItem.resolution ?? 1.0)) +
                    (pidItem.offset ?? 0.0);
              } else {
                floatPidValue =
                    (unsignedPidIntValue * (pidItem.resolution ?? 1.0)) +
                    (pidItem.offset ?? 0.0);
              }

              // Formatting equivalent to ToString("0.###")
              String formattedValue = floatPidValue
                  .toStringAsFixed(3)
                  .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");

              mappedPIDResponse.values!.add(formattedValue);
            } catch (ex) {
              mappedPIDResponse.values!.add("Exception");
            }
          }
          mappedPIDResponseList.add(mappedPIDResponse);
        } else {
          mappedPIDResponse.status = pidResponse.ecuResponseStatus;
          mappedPIDResponseList.add(mappedPIDResponse);
        }
      } catch (exception) {
        mappedPIDResponse.status = "Exception";
        mappedPIDResponseList.add(mappedPIDResponse);
      }
    }
    return mappedPIDResponseList;
  }

  Future<ReadParameterResponse> pidConvertResponse(
    ResponseArrayStatus pidResponse,
    ReadParameterPID pidItem,
  ) async {
    ReadParameterResponse databyteArray = ReadParameterResponse();

    try {
      String dataValue = "";

      if (pidResponse.ecuResponseStatus == "NOERROR") {
        var pidBytesResponseString = byteArrayToString(
          pidResponse.actualDataBytes!,
        );
        print("Response received = $pidBytesResponseString");

        Uint8List rxArray = pidResponse.actualDataBytes!;
        var inputLiveParaArray = pidItem;

        double? floatPidValue = 0;

        // Note: Dart uses ~/ for integer division
        var txFrameLen = 2;
        Uint8List outputLiveParArray = Uint8List(
          txFrameLen - 2 > 0 ? txFrameLen - 2 : 0,
        );

        print("---NOERROR LOOP");
        List<ReadParameterVariableResponse> variableResponses = [];

        for (int k = 0; k < (inputLiveParaArray.variables?.length ?? 0); k++) {
          try {
            var currentVar = inputLiveParaArray.variables![k];
            print(
              "---------------------START LOOP VARIABLE NAME-------------------------------------${currentVar.pidName}",
            );

            if (currentVar.datatype == "CONTINUOUS" ||
                currentVar.datatype == "IEEE754_FLOAT") {
              print("---START CONTINUOUS--");
              int unsignedPidIntValue = 0;
              int noOfBytes = currentVar.noOfBytes ?? 0;

              for (int j = 0; j < noOfBytes; j++) {
                int startByte = currentVar.startByte ?? 0;
                int byteVal = rxArray[startByte + txFrameLen - 1 + j];
                unsignedPidIntValue |= (byteVal << ((noOfBytes - 1 - j) * 8));
              }

              if (currentVar.isBitcoded == true) {
                int startBit = currentVar.startBit ?? 0;
                int noOfBits = currentVar.noofBits ?? 0;

                // C# logic: (unsignedpidintvalue >> (totalbits - noofbits - startbit + 1)) & mask
                int shiftAmount = (noOfBytes * 8) - noOfBits - startBit + 1;
                int mask =
                    (pow(16, noOfBytes * 2).toInt() - 1) >>
                    ((noOfBytes * 8) - noOfBits - startBit + 1);

                unsignedPidIntValue =
                    (unsignedPidIntValue >> shiftAmount) & mask;
              }

              if (currentVar.readParameterIndex ==
                      ReadParameterIndex.uds2sCompliment &&
                  currentVar.offset == 1) {
                // Using .toDouble() to ensure precision before multiplication
                floatPidValue =
                    unsignedPidIntValue.toDouble() *
                    (currentVar.resolution ?? 1.0);
              } else if (currentVar.datatype == "IEEE754_FLOAT") {
                var bd = ByteData(4)..setUint32(0, unsignedPidIntValue);
                double floatValue = bd.getFloat32(0);
                floatPidValue =
                    (floatValue * (currentVar.resolution ?? 1.0)) +
                    (currentVar.offset ?? 0.0);
              } else {
                floatPidValue =
                    (unsignedPidIntValue * (currentVar.resolution ?? 1.0)) +
                    (currentVar.offset ?? 0.0);
              }

              // ToString("0.000") equivalent in Dart
              dataValue = floatPidValue.toStringAsFixed(3);
              print("---END CONTINUOUS--");
            } else if (currentVar.datatype == "ASCII") {
              print("---START ASCII--");
              int noOfBytes = currentVar.noOfBytes ?? 0;
              int startByte = currentVar.startByte ?? 0;

              outputLiveParArray = rxArray.sublist(
                startByte + txFrameLen - 1,
                startByte + txFrameLen - 1 + noOfBytes,
              );

              dataValue = ascii
                  .decode(outputLiveParArray)
                  .replaceAll("\x00", "");
              print("---END ASCII--");
            } else if (currentVar.datatype == "BCD" ||
                currentVar.datatype == "HEX") {
              print("---START BCD--");
              int noOfBytes = currentVar.noOfBytes ?? 0;
              int startByte = currentVar.startByte ?? 0;

              Uint8List subArray = rxArray.sublist(
                startByte + txFrameLen - 1,
                startByte + txFrameLen - 1 + noOfBytes,
              );

              // takeWhile equivalent
              var filteredBytes = subArray
                  .takeWhile((value) => value != 0x00)
                  .toList();
              dataValue = byteArrayToString(Uint8List.fromList(filteredBytes));
              print("---END BCD--");
            } else if (currentVar.datatype == "ENUMRATED") {
              int pidIntValue = 0;
              int noOfBytes = currentVar.noOfBytes ?? 0;
              int startByte = currentVar.startByte ?? 0;

              for (int j = 0; j < noOfBytes; j++) {
                pidIntValue |=
                    (rxArray[startByte + txFrameLen - 1 + j] <<
                    ((noOfBytes - 1 - j) * 8));
              }

              if (currentVar.isBitcoded == true) {
                int noOfBits = currentVar.noofBits ?? 0;
                int startBit = currentVar.startBit ?? 0;
                int shiftAmount = (noOfBytes * 8) - noOfBits - startBit + 1;
                int mask = (pow(16, noOfBytes * 2).toInt() - 1) >> shiftAmount;

                pidIntValue = (pidIntValue >> shiftAmount) & mask;
              }

              dataValue = pidIntValue.toString();

              if (currentVar.messages != null &&
                  currentVar.messages!.isNotEmpty) {
                for (var item in currentVar.messages!) {
                  if (int.tryParse(item.code ?? "") == pidIntValue) {
                    dataValue = item.message ?? "";
                  }
                }
              }
            } else if (currentVar.datatype == "IQA") {
              dataValue = decodeIQA1(
                rxArray,
                k,
              ); // Logic abstracted into the helper below
            }

            variableResponses.add(
              ReadParameterVariableResponse(
                pidName: currentVar.pidName,
                pidNumber: currentVar.pidNumber,
                responseValue: dataValue,
              ),
            );
          } catch (e) {
            variableResponses.add(
              ReadParameterVariableResponse(
                pidName: inputLiveParaArray.variables![k].pidName,
                pidNumber: inputLiveParaArray.variables![k].pidNumber,
                responseValue: "Exception",
              ),
            );
          }
          print(
            " END LOOP VARIABLE NAME = ${inputLiveParaArray.variables![k].pidName}",
          );
        }

        databyteArray = ReadParameterResponse(
          pidId: pidItem.pidId,
          status: pidResponse.ecuResponseStatus,
          dataArray: outputLiveParArray,
          pidName: "",
          variables: variableResponses,
        );
      } else {
        List<ReadParameterVariableResponse> variableResponses = [];
        for (var item in (pidItem.variables ?? [])) {
          variableResponses.add(
            ReadParameterVariableResponse(
              pidName: item.pidName,
              pidNumber: item.pidNumber,
              responseValue: dataValue,
            ),
          );
        }
        databyteArray = ReadParameterResponse(
          status: pidResponse.ecuResponseStatus,
          pidId: pidItem.pidId,
          pidName: "",
          variables: variableResponses,
        );
      }
    } catch (e) {
      databyteArray = ReadParameterResponse(status: "Exception");
    }

    return databyteArray;
  }

  // IQA Helper function based on your logic
  String decodeIQA1(Uint8List rxArray, int k) {
    const String iqaLookupX = "ABCDEFGHIKLMNOPTRSTUVWXYZ12345678";
    Uint8List iqaEcuArray = Uint8List(48);

    // Array.Copy(Rxarray, 3, iqaecuarray, 0, Rxarray.Length - 3)
    if (rxArray.length > 3) {
      List<int> sub = rxArray.sublist(3);
      iqaEcuArray.setRange(0, sub.length > 48 ? 48 : sub.length, sub);
    }

    Uint8List rxData = Uint8List(8);
    rxData.setRange(0, 8, iqaEcuArray.sublist(k * 8, (k * 8) + 8));

    List<int> iqaY = List.filled(7, 0);
    iqaY[0] = (rxData[0] & 0xF8) >> 3;
    iqaY[1] = (((rxData[0] & 0x07) << 8) | (rxData[1] & 0xC0)) >> 6;
    iqaY[2] = (rxData[1] & 0x3E) >> 1;
    iqaY[3] = (((rxData[1] & 0x01) << 8) | (rxData[2] & 0xF0)) >> 4;
    iqaY[4] = (((rxData[2] & 0x0F) << 8) | (rxData[3] & 0x80)) >> 7;
    iqaY[5] = (rxData[3] & 0x7C) >> 2;
    iqaY[6] = (rxData[4] & 0xF8) >> 3;

    String result = "";
    for (int y in iqaY) {
      result += iqaLookupX[y];
    }
    return result;
  }

  Future<ReadParameterResponse> readParametersFromAddr(
    ReadParameterPID readParameter,
    String pidByAddrSeq,
  ) async {
    List<String> lineData = pidByAddrSeq.split('\n');

    ResponseArrayStatus? reprogrammingResponse;
    ReadParameterResponse readParameterResponse = ReadParameterResponse();
    Uint8List seedKey = Uint8List(0);

    try {
      bool isReadStarted = false;
      for (int i = 0; i < lineData.length; i++) {
        String formattedLine = lineData[i].replaceAll('\r', '').trim();

        if (formattedLine.startsWith("//") || formattedLine == "") {
          continue;
        }

        if (formattedLine.contains("startread")) isReadStarted = true;

        if (isReadStarted && formattedLine.contains("endread")) {
          isReadStarted = false;
        }

        if (!isReadStarted) continue;

        List<String> parts = formattedLine.split(':');
        String command = parts[0];
        String info = parts.length > 1 ? parts[1] : "";

        if (command == "send") {
          List<String> splitData = info.split('+');
          List<int> txFrameList = [];

          for (var item in splitData) {
            if (!item.contains("<")) {
              txFrameList.addAll(hexStringToByteArray(item));
            } else {
              int endIndex = item.indexOf('>');
              // item.substring(1, endIndex) gets content between < and >
              String bracketString = item.substring(1, endIndex);
              List<String> bracketParts = bracketString.split(',');
              String reference = bracketParts[0];

              // Convert hex length string to int
              int copyLength = int.parse(bracketParts[1], radix: 16);
              List<int> copyArray = [];

              if (reference.contains("key")) {
                copyArray = List<int>.from(seedKey);
              } else if (reference.contains("pid_addr")) {
                copyArray = hexStringToByteArray(readParameter.pid ?? "");

                if (copyArray.length > copyLength) {
                  copyArray = copyArray.sublist(copyArray.length - copyLength);
                }
              } else if (reference.contains("pid_len")) {
                // Convert totalLen to bytes (Big Endian logic like C# Array.Reverse)
                int totalLen = readParameter.totalLen ?? 0;
                ByteData bdata = ByteData(4)
                  ..setUint32(0, totalLen, Endian.big);
                copyArray = bdata.buffer.asUint8List().toList();

                if (copyArray.length > copyLength) {
                  copyArray = copyArray.sublist(copyArray.length - copyLength);
                }
              }

              // Ensure the copyArray matches the requested copyLength
              if (copyArray.length > copyLength) {
                copyArray = copyArray.sublist(0, copyLength);
              } else if (copyArray.length < copyLength) {
                // Pad with zeros if too short
                copyArray = List<int>.from(copyArray)
                  ..addAll(List.filled(copyLength - copyArray.length, 0));
              }

              txFrameList.addAll(copyArray);
            }
          }

          String txHexString = byteArrayToString(
            Uint8List.fromList(txFrameList),
          );
          print("send : Sending Command $txHexString");

          reprogrammingResponse = await dongleComm!.canTxRx(
            txFrameList.length,
            txHexString,
          );

          // Handle "Required Time Delay Not Expired" loop
          while (reprogrammingResponse?.ecuResponseStatus ==
              "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
            await Future.delayed(Duration(milliseconds: 300));
            reprogrammingResponse = await dongleComm!.canTxRx(
              txFrameList.length,
              txHexString,
            );
          }

          if (reprogrammingResponse?.ecuResponseStatus != "NOERROR") {
            print(
              "ELMZ : --------- reprogrammingResponse ERROR------------==${reprogrammingResponse?.ecuResponseStatus}",
            );
            readParameterResponse = ReadParameterResponse()
              ..pidId = readParameter.pidId
              ..status = reprogrammingResponse?.ecuResponseStatus;
            return readParameterResponse;
          }
        } else if (command == "sleep") {
          await Future.delayed(Duration(milliseconds: int.parse(info)));
        } else if (command == "function") {
          if (info.contains("CalculateKeyFromSeed")) {
            int startIdx = info.indexOf('[') + 1;
            int endIdx = info.indexOf(']');
            String sqrBktInfo = info.substring(startIdx, endIdx);
            List<String> params = sqrBktInfo.split(',');

            String seedKeyIndexStr = params[0].replaceAll(
              '-',
              '_',
            ); // e.g., "UDS_LEVEL_1"

            // 1. Convert String to Enum
            // We look for a match in SeedKeyIndexType.values
            SeedKeyIndexType? selectedIndex;
            try {
              selectedIndex = SeedKeyIndexType.values.firstWhere(
                (e) => e.toString().split('.').last == seedKeyIndexStr,
              );
            } catch (e) {
              print("Error: $seedKeyIndexStr is not a valid SeedKeyIndexType");
            }

            if (selectedIndex != null) {
              Uint8List actualBytes = reprogrammingResponse!.actualDataBytes!;
              // Skip the first 2 bytes (usually service ID and sub-function)
              Uint8List seedArray = actualBytes.sublist(2);

              print(
                "-------seed array = ${byteArrayToString(seedArray)}-------",
              );
              print("-------get key-------");

              // 2. Pass the Enum 'selectedIndex', not the String
              // Also ensuring we initialize the keyOutput list if your method requires it
              List<int> keyBuffer = [];
              await calculateSeedkey!.calculateSeedkey(
                index: selectedIndex,
                seed: seedArray,
                keyOutput: keyBuffer,
              );

              // 3. Convert the result back to Uint8List
              seedKey = Uint8List.fromList(keyBuffer);
              print(
                "-------get key response = ${byteArrayToString(seedKey)}-------",
              );
            }
          }
        } else if (command == "readpid") {
          if (reprogrammingResponse != null) {
            readParameterResponse = await pidConvertResponse(
              reprogrammingResponse,
              readParameter,
            );
          }
        }
      }
    } catch (ex, stack) {
      print("Exception : $ex $stack");
      readParameterResponse.status = "Exception";
    }

    return readParameterResponse;
  }

  Future<List<ReadParameterResponse>> setRoutineValue(
    int noOfParameters,
    List<ReadParameterPID> readParameterCollection,
    Uint8List actualResponse,
  ) async {
    List<ReadParameterResponse> databyteArray = [];
    dongleComm!.saveLog("------Start Read Pid------\n");
    // ignore: unused_local_variable
    int index = 0;

    for (int i = 0; i < readParameterCollection.length; i++) {
      var pidItem = readParameterCollection[i];
      int frameLength = 0;
      String dataValue = "";

      print(
        "---------------------START LOOP PID NAME-------------------------------------${pidItem.pid}\n",
      );
      dongleComm!.saveLog("------Start Read Pid (${pidItem.pid})------");

      // Manually creating the response object as per your C# logic
      var pidResponseStatus = "NOERROR";
      Uint8List rxArray = actualResponse;

      try {
        if (pidResponseStatus == "NOERROR") {
          var pidBytesResponseString = byteArrayToString(rxArray);
          print("Response received = $pidBytesResponseString");
          print("IORTEST : Actual Response $pidBytesResponseString");

          var status = pidResponseStatus;
          var inputLiveParaArray = readParameterCollection;
          var txFrameLen = frameLength;

          // Initializing empty byte array
          Uint8List outputLiveParArray = Uint8List(0);

          if (status == "NOERROR") {
            print("---NOERROR LOOP");
            List<ReadParameterVariableResponse> variableResponses = [];

            for (
              int k = 0;
              k < (inputLiveParaArray[i].variables?.length ?? 0);
              k++
            ) {
              var currentVar = inputLiveParaArray[i].variables![k];
              print(
                "---------------------START LOOP VARIABLE NAME-------------------------------------${currentVar.pidName}",
              );

              try {
                if (currentVar.datatype == "CONTINUOUS" ||
                    currentVar.datatype == "IEEE754_FLOAT") {
                  print("---START CONTINUOUS--");
                  int unsignedPidIntValue = 0;
                  int noOfBytes = currentVar.noOfBytes ?? 0;

                  for (int j = 0; j < noOfBytes; j++) {
                    index++;
                    // Note the +5 offset from your C# code: (startByte + 5)
                    int byteIndex =
                        (currentVar.startByte ?? 0) + 5 + txFrameLen - 1 + j;

                    if (byteIndex < rxArray.length) {
                      unsignedPidIntValue |=
                          (rxArray[byteIndex] << ((noOfBytes - 1 - j) * 8));
                    }

                    print("IORTEST : Start byte ${currentVar.startByte}");
                    print("IORTEST : Lenth $txFrameLen");
                    print("IORTEST : No Of Byte $noOfBytes");
                  }

                  print("IORTEST : Shifted Value Value = $unsignedPidIntValue");

                  if (currentVar.isBitcoded == true) {
                    int lsbStartBit = currentVar.startBit ?? 1;
                    int mask = 0;
                    for (int x = 0; x < (currentVar.noofBits ?? 0); x++) {
                      mask |= (0x01 << (lsbStartBit - 1));
                      lsbStartBit++;
                    }
                    unsignedPidIntValue =
                        (unsignedPidIntValue & mask) >>
                        ((currentVar.startBit ?? 1) - 1);
                  }

                  double floatPidValue = 0;
                  if (currentVar.readParameterIndex ==
                          ReadParameterIndex.uds2sCompliment &&
                      currentVar.offset == 1) {
                    floatPidValue =
                        unsignedPidIntValue.toDouble() *
                        (currentVar.resolution ?? 1.0);
                  } else if (currentVar.datatype == "IEEE754_FLOAT") {
                    var bd = ByteData(4)..setUint32(0, unsignedPidIntValue);
                    floatPidValue =
                        (bd.getFloat32(0) * (currentVar.resolution ?? 1.0)) +
                        (currentVar.offset ?? 0.0);
                  } else {
                    floatPidValue =
                        (unsignedPidIntValue * (currentVar.resolution ?? 1.0)) +
                        (currentVar.offset ?? 0.0);
                  }

                  dataValue = floatPidValue.toStringAsFixed(3);
                  print("IORTEST : DLL Value $dataValue");
                  print(
                    "---------------------Value-------------------------------------${currentVar.pidName} : $dataValue",
                  );
                  print("---END CONTINUOUS--");
                } else if (currentVar.datatype == "ASCII") {
                  print("---START ASCII--");
                  int noOfBytes = currentVar.noOfBytes ?? 0;
                  int startByte = currentVar.startByte ?? 0;

                  int start = startByte + 5 + txFrameLen - 1;
                  if (start + noOfBytes <= rxArray.length) {
                    Uint8List subArray = rxArray.sublist(
                      start,
                      start + noOfBytes,
                    );
                    dataValue = ascii.decode(subArray).replaceAll("\x00", "");
                  }
                  print("---END ASCII--");
                } else if (currentVar.datatype == "BCD" ||
                    currentVar.datatype == "HEX") {
                  print("---START BCD--");
                  int noOfBytes = currentVar.noOfBytes ?? 0;
                  int startByte = currentVar.startByte ?? 0;

                  int start = startByte + 5 + txFrameLen - 1;
                  if (start + noOfBytes <= rxArray.length) {
                    Uint8List subArray = rxArray.sublist(
                      start,
                      start + noOfBytes,
                    );
                    var newData = subArray.takeWhile((v) => v != 0x00).toList();
                    dataValue = byteArrayToString(Uint8List.fromList(newData));
                  }
                  print("---END BCD--");
                } else if (currentVar.datatype == "ENUMRATED") {
                  int pidIntValue = 0;
                  int noOfBytes = currentVar.noOfBytes ?? 0;
                  int startByte = currentVar.startByte ?? 0;

                  for (int j = 0; j < noOfBytes; j++) {
                    int byteIndex = startByte + 5 + txFrameLen - 1 + j;
                    if (byteIndex < rxArray.length) {
                      pidIntValue |=
                          (rxArray[byteIndex] << ((noOfBytes - 1 - j) * 8));
                    }
                  }

                  if (currentVar.isBitcoded == true) {
                    int lsbStartBit = currentVar.startBit ?? 1;
                    int mask = 0;
                    for (int x = 0; x < (currentVar.noofBits ?? 0); x++) {
                      mask |= (0x01 << (lsbStartBit - 1));
                      lsbStartBit++;
                    }
                    pidIntValue =
                        (pidIntValue & mask) >>
                        ((currentVar.startBit ?? 1) - 1);
                  }

                  dataValue = pidIntValue.toString();
                  if (currentVar.messages != null &&
                      currentVar.messages!.isNotEmpty) {
                    for (var item in currentVar.messages!) {
                      int? code = int.tryParse(item.code ?? "");
                      if (code != null && code == pidIntValue) {
                        dataValue = item.message ?? "";
                      }
                    }
                  }
                } else if (currentVar.datatype == "IQA") {
                  // Assuming decodeIQA logic from previous conversions
                  dataValue = decodeIQA1(rxArray.sublist(3), k);
                }

                variableResponses.add(
                  ReadParameterVariableResponse(
                    pidName: currentVar.pidName,
                    pidNumber: currentVar.pidNumber,
                    responseValue: dataValue,
                  ),
                );
              } catch (ex) {
                variableResponses.add(
                  ReadParameterVariableResponse(
                    pidName: currentVar.pidName,
                    pidNumber: currentVar.pidNumber,
                    responseValue: "Exception",
                  ),
                );
              }
              print(" END LOOP VARIABLE NAME = ${currentVar.pidName}");
            }

            databyteArray.add(
              ReadParameterResponse(
                pidId: pidItem.pidId,
                status: status,
                dataArray: outputLiveParArray,
                pidName: "",
                variables: variableResponses,
              ),
            );
          } else {
            // Handle Error Case
            List<ReadParameterVariableResponse> variableResponses = [];
            for (var item in (inputLiveParaArray[i].variables ?? [])) {
              variableResponses.add(
                ReadParameterVariableResponse(
                  pidName: item.pidName,
                  pidNumber: item.pidNumber,
                  responseValue: dataValue,
                ),
              );
            }
            databyteArray.add(
              ReadParameterResponse(
                status: status,
                dataArray: Uint8List.fromList([
                  0x00,
                ]), // Equivalent to outputlivepararray[i] = 0x00
                pidId: pidItem.pidId,
                pidName: "",
                variables: variableResponses,
              ),
            );
          }
        }
      } catch (excepption) {
        databyteArray.add(ReadParameterResponse(status: excepption.toString()));
      }
      print(" END LOOP PID NAME = ${pidItem.pid}");
    }
    return databyteArray;
  }

  Future<List<WriteParameterResponse>?> writeParameters(
    int noOfParameters,
    WriteParameterIndex writeParameterIndex,
    List<WriteParameterPID> writeParameterCollection,
  ) async {
    try {
      dongleComm?.saveLog("------Start Write Pid Process------\n");

      if (calculateSeedkey == null || dongleComm == null) {
        print(
          "❌ CRITICAL: Comm=${dongleComm != null} | Calc=${calculateSeedkey != null}",
        );
        return null;
      }

      List<WriteParameterResponse> responseList = [];

      for (var pidItem in writeParameterCollection) {
        int diagnosticsMode = 0x03;
        int getSeedIndex = 0x01;

        // ── Seed Index Mapping ─────────────────────────────
        switch (writeParameterIndex) {
          case WriteParameterIndex.UDS_DS1003_SK090A:
            getSeedIndex = 0x09;
            break;
          case WriteParameterIndex.UDS_DS1003_SK0102:
            getSeedIndex = 0x01;
            break;
          case WriteParameterIndex.UDS_DS1003_SK0B0C:
            getSeedIndex = 0x0B;
            break;
          case WriteParameterIndex.UDS_DS1003_SK0304:
            getSeedIndex = 0x03;
            break;
          case WriteParameterIndex.UDS_DS1003_SK0506:
            getSeedIndex = 0x05;
            break;
          default:
            getSeedIndex = 0x01;
        }

        print("🔑 PID: ${pidItem.writePid} Seed: $getSeedIndex");

        // ── STEP 1: Session ─────────────────────────────
        var sessionResp = await dongleComm!.canTxRx(
          2,
          byteArrayToString(Uint8List.fromList([0x10, diagnosticsMode])),
        );

        if (sessionResp.ecuResponseStatus != "NOERROR") {
          responseList.add(
            WriteParameterResponse(
              status: sessionResp.ecuResponseStatus,
              pidNumber: pidItem.writeParaNo,
              responseValue: "SESSION_FAILED",
            ),
          );
          continue;
        }

        // ── STEP 2: Seed Request ─────────────────────────
        var seedResp = await dongleComm!.canTxRx(
          2,
          byteArrayToString(Uint8List.fromList([0x27, getSeedIndex])),
        );

        if (seedResp.ecuResponseStatus != "NOERROR" ||
            seedResp.actualDataBytes == null ||
            seedResp.actualDataBytes!.length <= 2) {
          responseList.add(
            WriteParameterResponse(
              status: seedResp.ecuResponseStatus,
              pidNumber: pidItem.writeParaNo,
              responseValue: "SEED_FAILED",
            ),
          );
          continue;
        }

        Uint8List seedArray = seedResp.actualDataBytes!.sublist(2);
        List<int> keyBuffer = [];

        // ── STEP 3: Key Calculation ───────────────────────
        await calculateSeedkey!.calculateSeedkey(
          index: pidItem.seedKeyIndex as SeedKeyIndexType,
          seed: seedArray,
          keyOutput: keyBuffer,
        );

        if (keyBuffer.isEmpty) {
          responseList.add(
            WriteParameterResponse(
              status: "KEY_CALC_FAILED",
              pidNumber: pidItem.writeParaNo,
            ),
          );
          continue;
        }

        // ── STEP 4: Key Send ──────────────────────────────
        Uint8List keyFrame = Uint8List(2 + keyBuffer.length);
        keyFrame[0] = 0x27;
        keyFrame[1] = getSeedIndex + 1;
        keyFrame.setRange(2, 2 + keyBuffer.length, keyBuffer);

        var keyResp = await dongleComm!.canTxRx(
          keyFrame.length,
          byteArrayToString(keyFrame),
        );

        if (keyResp.ecuResponseStatus != "NOERROR") {
          responseList.add(
            WriteParameterResponse(
              status: "SECURITY_DENIED",
              pidNumber: pidItem.writeParaNo,
            ),
          );
          continue;
        }

        // ── STEP 5: WRITE FRAME BUILD (FIXED CORE ISSUE) ─────

        Uint8List pidBytes = hexStringToByteArray(pidItem.writePid ?? "");

        int dataSize = pidItem.totalBytes ?? 0;

        int frameSize = 1 + pidBytes.length + dataSize;

        Uint8List writeFrame = Uint8List(frameSize);

        writeFrame[0] = 0x2E;

        // PID placement
        writeFrame.setRange(1, 1 + pidBytes.length, pidBytes);

        int baseOffset = 1 + pidBytes.length;

        // ── SAFE DATA INSERTION ───────────────────────────
        if (pidItem.writeInput != null && pidItem.writeInput!.isNotEmpty) {
          int end =
              baseOffset +
              (pidItem.startByte ?? 0) +
              pidItem.writeInput!.length;

          if (end <= writeFrame.length) {
            writeFrame.setRange(
              baseOffset + (pidItem.startByte ?? 0),
              baseOffset +
                  (pidItem.startByte ?? 0) +
                  pidItem.writeInput!.length,
              pidItem.writeInput!,
            );
          } else {
            print("❌ WRITE INPUT OVERFLOW - skipping");
          }
        }

        // ── IQA PACKING SAFE ──────────────────────────────
        for (int k = 0; k < (pidItem.variantList?.length ?? 0); k++) {
          if (pidItem.variantList![k].datatype == "IQA") {
            _packIQAData(pidItem, writeFrame, pidBytes.length, k);
          }
        }

        print("🔧 FINAL FRAME: ${byteArrayToString(writeFrame)}");

        // ── STEP 6: WRITE TO ECU ──────────────────────────
        var writeResp = await dongleComm!.canTxRx(
          writeFrame.length,
          byteArrayToString(writeFrame),
        );

        responseList.add(
          WriteParameterResponse(
            status: writeResp.ecuResponseStatus,
            dataArray: writeResp.actualDataBytes,
            pidName: pidItem.pidName,
            pidNumber: pidItem.writeParaNo,
            responseValue: writeResp.ecuResponseStatus,
          ),
        );
      }

      return responseList;
    } catch (ex) {
      print("❌ WriteParameters Exception: $ex");
      return null;
    }
  }

  /// Helper for IQA packing bit-manipulation
  void _packIQAData(
    WriteParameterPID pidItem,
    Uint8List writeFrame,
    int pidOffset,
    int k,
  ) {
    const String iqaLookup = "ABCDEFGHIKLMNOPTRSTUVWXYZ12345678";
    List<int> iqaY = List.filled(7, 0);

    // Find indices in lookup table
    for (int i = 0; i < 7; i++) {
      String charToFind = String.fromCharCode(
        pidItem.writeInput![i],
      ).toUpperCase();
      iqaY[i] = iqaLookup.indexOf(charToFind);
    }

    // Pack 5-bit values into 32-bit temp
    int temp =
        ((iqaY[0] & 0x1F) << 27) |
        ((iqaY[1] & 0x1F) << 22) |
        ((iqaY[2] & 0x1F) << 17) |
        ((iqaY[3] & 0x1F) << 12) |
        ((iqaY[4] & 0x1F) << 7) |
        ((iqaY[5] & 0x1F) << 2);

    Uint8List iqaPacked = Uint8List(8);
    iqaPacked[0] = (temp & 0xFF000000) >> 24;
    iqaPacked[1] = (temp & 0x00FF0000) >> 16;
    iqaPacked[2] = (temp & 0x0000FF00) >> 8;
    iqaPacked[3] = (temp & 0x000000FF);
    iqaPacked[4] = (iqaY[6] << 3);

    int startPos = 1 + pidOffset + (pidItem.variantList![k].startByte ?? 0);
    writeFrame.setRange(startPos, startPos + 8, iqaPacked);
  }

  Future<WriteParameterResponse> actuatorTestWriteParameters(
    WriteParameterIndex writeParameterIndex,
    SeedKeyIndexType seedKeyIndex,
    List<Uint8List> actuatorCmd,
    bool isStartTest,
  ) async {
    WriteParameterResponse writeParameterResp = WriteParameterResponse();

    try {
      int diagnosticsMode = 0x00;
      int getSeedIndex = 0x00;

      // Determine Diagnostic Mode and Seed Index based on Enum
      if (writeParameterIndex == WriteParameterIndex.UDS) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x01;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x09;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x01;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x0B;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x03;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x05;
      }

      ResponseArrayStatus response = ResponseArrayStatus();
      Uint8List txFrame = Uint8List(2);
      int frameLength = 2;

      // Use .name in Dart for Enum string comparison
      String indexStr = writeParameterIndex.name;
      int indexSK = indexStr.indexOf("SK");
      int indexDS = indexStr.indexOf("DS1");

      if (isStartTest) {
        await dongleComm!.canStartTP();
      }

      // Diagnostic Session and Security Access logic
      if (indexStr == "NA") {
        // Do nothing
      } else if (indexSK < 0 && isStartTest) {
        /* Send start diagnostics mode command (10 XX) */
        txFrame[0] = 0x10;
        txFrame[1] = diagnosticsMode;
        response = await dongleComm!.canTxRx(
          frameLength,
          byteArrayToString(txFrame),
        );
      } else if (indexSK >= 0 && indexSK < indexDS && isStartTest) {
        /* Security Access first, then Session Control */
        response = await sendSeedKey(getSeedIndex, seedKeyIndex);
        if (response.ecuResponseStatus == "NOERROR") {
          txFrame[0] = 0x10;
          txFrame[1] = diagnosticsMode;
          response = await dongleComm!.canTxRx(
            frameLength,
            byteArrayToString(txFrame),
          );
        }
      } else if (isStartTest) {
        /* Session Control first, then Security Access */
        txFrame[0] = 0x10;
        txFrame[1] = diagnosticsMode;
        response = await dongleComm!.canTxRx(
          frameLength,
          byteArrayToString(txFrame),
        );
        if (response.ecuResponseStatus == "NOERROR") {
          response = await sendSeedKey(getSeedIndex, seedKeyIndex);
        }
      }

      // Check for errors before sending actuator commands
      if (response.ecuResponseStatus != "NOERROR" &&
          indexStr != "NA" &&
          isStartTest) {
        await dongleComm!.canStopTP();
        writeParameterResp = WriteParameterResponse(
          status: response.ecuResponseStatus,
          dataArray: response.actualDataBytes,
          responseValue: response.ecuResponseStatus,
        );
        return writeParameterResp;
      }

      // Execute Actuator Commands
      for (var item in actuatorCmd) {
        response = await dongleComm!.canTxRx(
          item.length,
          byteArrayToString(item),
        );

        writeParameterResp = WriteParameterResponse(
          status: response.ecuResponseStatus,
          dataArray: response.actualDataBytes,
          responseValue: response.ecuResponseStatus,
        );
      }

      if (!isStartTest) {
        await dongleComm!.canStopTP();
      }
    } catch (ex) {
      print("Actuator Test Error: $ex");
      await dongleComm!.canStopTP();
    }

    return writeParameterResp;
  }

  Future<ResponseArrayStatus> enterExtendedSession(
    WriteParameterIndex writeParamIndex,
    SeedKeyIndexType seedKeyIndex,
  ) async {
    int diagnosticsMode = 0x00;
    int getSeedIndex = 0x00;

    // Logic to determine sub-functions based on the parameter index
    if (writeParamIndex == WriteParameterIndex.UDS) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x01;
    } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x09;
    } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x01;
    } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x0B;
    } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x03;
    } else if (writeParamIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x05;
    }

    ResponseArrayStatus response = ResponseArrayStatus();
    Uint8List txFrame = Uint8List(2);
    const int frameLength = 2;

    // Use .name in Dart to get the string representation of an enum
    String paramIndexStr = writeParamIndex.name;
    int indexSK = paramIndexStr.indexOf("SK");
    int indexDS = paramIndexStr.indexOf("DS1");

    // Check the sequence order requirements
    if (paramIndexStr == "NA") {
      // Do nothing
    } else if (indexSK < 0) {
      /* Sequence: Just Session Control (10 XX) */
      txFrame[0] = 0x10;
      txFrame[1] = diagnosticsMode;

      response = await dongleComm!.canTxRx(
        frameLength,
        byteArrayToString(txFrame),
      );
    } else if (indexSK >= 0 && indexSK < indexDS) {
      /* Sequence: Seed-Key (27) then Session Control (10) */
      response = await sendSeedKey(getSeedIndex, seedKeyIndex);

      if (response.ecuResponseStatus == "NOERROR") {
        txFrame[0] = 0x10;
        txFrame[1] = diagnosticsMode;
        response = await dongleComm!.canTxRx(
          frameLength,
          byteArrayToString(txFrame),
        );
      }
    } else {
      /* Sequence: Session Control (10) then Seed-Key (27) */
      txFrame[0] = 0x10;
      txFrame[1] = diagnosticsMode;

      response = await dongleComm!.canTxRx(
        frameLength,
        byteArrayToString(txFrame),
      );

      if (response.ecuResponseStatus == "NOERROR") {
        response = await sendSeedKey(getSeedIndex, seedKeyIndex);
      }
    }

    return response;
  }

  Future<ResponseArrayStatus> sendSeedKey(
    int getSeedIndex,
    SeedKeyIndexType seedKeyIndex,
  ) async {
    ResponseArrayStatus response = ResponseArrayStatus();
    Uint8List txFrame = Uint8List(2);
    int frameLength = 2;

    /* 1. Send Get Seed command (Service 0x27) */
    txFrame[0] = 0x27;
    txFrame[1] = getSeedIndex;

    response = await dongleComm!.canTxRx(
      frameLength,
      byteArrayToString(txFrame),
    );
    String status = response.ecuResponseStatus ?? "";

    /* 2. Handle Required Time Delay (ECU Security Access lock) */
    while (status == "ECUERROR REQUIREDTIMEDELAYNOTEXPIRED") {
      // Replaced Thread.Sleep with Future.delayed to keep the app responsive
      await Future.delayed(const Duration(milliseconds: 300));
      response = await dongleComm!.canTxRx(
        frameLength,
        byteArrayToString(txFrame),
      );
      status = response.ecuResponseStatus ?? "";
    }

    /* 3. If Seed is received successfully */
    if (status == "NOERROR") {
      Uint8List? rxArray = response.actualDataBytes;
      // ignore: unused_local_variable
      int rxSize = rxArray!.length;

      // Extract seed (skip first 2 bytes: SID 0x67 and Sub-function)
      Uint8List seedArray = rxArray.sublist(2);
      // ignore: unused_local_variable
      int seedKeyLen = 0; // Set this as per your specific ECU requirements

      print("-------Calculating key from seed-------");

      try {
        // Assuming calculateSeedkey returns an object with 'key' and 'numBytes'
        // 1. Initialize an empty list to receive the key
        List<int> keyBuffer = [];

        // 2. The function returns a status code (int), but fills keyBuffer
        await calculateSeedkey!.calculateSeedkey(
          index: seedKeyIndex,
          seed: seedArray,
          keyOutput: keyBuffer, // Pass the list here
        );

        // 3. Check status and use the buffer

        // Check your specific "Success" code
        Uint8List actualKey = Uint8List.fromList(keyBuffer);
        int numKeyBytes = actualKey.length;

        // Proceed with sending the key...
        /* 4. Send Calculated Key back to ECU */
        Uint8List newTxFrame = Uint8List(numKeyBytes + 2);
        newTxFrame[0] = 0x27;
        // Key sub-function is always GetSeed sub-function + 1
        newTxFrame[1] = getSeedIndex + 1;

        // Copy the calculated key into the frame starting at index 2
        newTxFrame.setRange(2, 2 + numKeyBytes, actualKey);

        print(
          "-------Sending calculated key: ${byteArrayToString(newTxFrame)}-------",
        );

        response = await dongleComm!.canTxRx(
          newTxFrame.length,
          byteArrayToString(newTxFrame),
        );
      } catch (e) {
        print("Error calculating or sending SeedKey: $e");
        response.ecuResponseStatus = "EXCEPTION";
      }
    }

    return response;
  }

  Future<List<WriteParameterResponse>> atuatorTestWriteParameters(
    int noOfParameters,
    WriteParameterIndex writeParameterIndex,
    List<WriteParameterPID> writeParameterCollection,
    bool isPlay,
  ) async {
    List<WriteParameterResponse> writeParameterResponseList = [];
    dongleComm!.saveLog("------Start Actuator Test------\n");

    for (var pidItem in writeParameterCollection) {
      int diagnosticsMode = 0x00;
      int getSeedIndex = 0x00;

      // Map the session and seed requirements
      if (writeParameterIndex == WriteParameterIndex.UDS) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x01;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x09;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x01;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x0B;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x03;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
        diagnosticsMode = 0x03;
        getSeedIndex = 0x05;
      }

      // 1. Send Diagnostic Session Control (0x10)
      Uint8List txFrame = Uint8List.fromList([0x10, diagnosticsMode]);
      var pidResponse = await dongleComm!.canTxRx(
        2,
        byteArrayToString(txFrame),
      );

      if (pidResponse.ecuResponseStatus == "NOERROR") {
        // 2. Send Security Access - Request Seed (0x27)
        Uint8List seedFrame = Uint8List.fromList([0x27, getSeedIndex]);
        var pidResponseBytes = await dongleComm!.canTxRx(
          2,
          byteArrayToString(seedFrame),
        );
        var status = pidResponseBytes.ecuResponseStatus;

        // Handle Required Time Delay
        if (status == "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
          await Future.delayed(const Duration(milliseconds: 11000));
          pidResponseBytes = await dongleComm!.canTxRx(
            2,
            byteArrayToString(seedFrame),
          );
          status = pidResponseBytes.ecuResponseStatus;
        }

        if (status == "NOERROR") {
          Uint8List? rxArray = pidResponseBytes.actualDataBytes;
          Uint8List seedArray = rxArray!.sublist(2);

          // ignore: unused_local_variable
          int seedKeyLen = 16; // Logic simplified from previous blocks
          if (pidItem.seedKeyIndex == SeedKeyIndexType.sanitasBoschBs6Prod) {
            seedKeyLen = 8;
          } else if (pidItem.seedKeyIndex ==
              SeedKeyIndexType.seedkeyalgoVecvDelphiBs6) {
            seedKeyLen = 4;
          }

          // 3. Calculate Key and Send (Service 0x27)
          List<int> keyOutput = [];
          await calculateSeedkey!.calculateSeedkey(
            index: pidItem.seedKeyIndex as SeedKeyIndexType,
            seed: seedArray,
            keyOutput: keyOutput,
          );

          Uint8List actualKey = Uint8List.fromList(keyOutput);
          Uint8List keyTxFrame = Uint8List(actualKey.length + 2);
          keyTxFrame[0] = 0x27;
          keyTxFrame[1] = getSeedIndex + 1;
          keyTxFrame.setRange(2, 2 + actualKey.length, actualKey);

          var pidResponse3 = await dongleComm!.canTxRx(
            keyTxFrame.length,
            byteArrayToString(keyTxFrame),
          );

          if (pidResponse3.ecuResponseStatus == "NOERROR") {
            Uint8List ioCtrlPID = hexStringToByteArray(pidItem.ioCtrlPid ?? "");
            int totalLen = pidItem.totalLen ?? 0;

            // 4. Send IO Control (Service 0x2F)
            Uint8List ioFrame;
            if (isPlay) {
              // Service 0x2F + PID + ControlParam(0x03 - ShortTermAdjustment) + Data
              ioFrame = Uint8List(2 + ioCtrlPID.length + totalLen);
              ioFrame[0] = 0x2F;
              ioFrame.setRange(1, 1 + ioCtrlPID.length, ioCtrlPID);
              ioFrame[1 + ioCtrlPID.length] = 0x03; // ShortTermAdjustment
              ioFrame.setRange(
                2 + ioCtrlPID.length,
                2 + ioCtrlPID.length + totalLen,
                pidItem.writeInput!,
              );
            } else {
              // Service 0x2F + PID + ControlParam(0x00 - ReturnControlToECU)
              ioFrame = Uint8List(2 + ioCtrlPID.length);
              ioFrame[0] = 0x2F;
              ioFrame.setRange(1, 1 + ioCtrlPID.length, ioCtrlPID);
              ioFrame[1 + ioCtrlPID.length] = 0x00; // ReturnControlToECU
            }

            var pidResponse4 = await dongleComm!.canTxRx(
              ioFrame.length,
              byteArrayToString(ioFrame),
            );

            writeParameterResponseList.add(
              WriteParameterResponse(
                status: pidResponse4.ecuResponseStatus,
                dataArray: pidResponse4.actualDataBytes,
                pidName: pidItem.pidName,
                pidNumber: pidItem.writeParaNo,
                responseValue: pidResponse4.ecuResponseStatus,
              ),
            );
          } else {
            // Key Error
            writeParameterResponseList.add(
              WriteParameterResponse(
                status: pidResponse3.ecuResponseStatus,
                pidNumber: pidItem.writeParaNo,
                responseValue: pidResponse3.ecuResponseStatus,
              ),
            );
          }
        } else {
          // Seed Error
          writeParameterResponseList.add(
            WriteParameterResponse(
              status: pidResponseBytes.ecuResponseStatus,
              pidNumber: pidItem.writeParaNo,
              responseValue: pidResponseBytes.ecuResponseStatus,
            ),
          );
        }
      } else {
        // Session Error
        writeParameterResponseList.add(
          WriteParameterResponse(
            status: pidResponse.ecuResponseStatus,
            pidNumber: pidItem.writeParaNo,
            responseValue: pidResponse.ecuResponseStatus,
          ),
        );
      }
    }

    return writeParameterResponseList;
  }

  Future<WriteParameterResponse> writeParametersFromAddr(
    WriteParameterPID writeParameter,
    String pidByAddrSeq,
  ) async {
    List<String> lineData = pidByAddrSeq.split('\n');

    ResponseArrayStatus? reprogrammingResponse;
    WriteParameterResponse writeParameterResponse = WriteParameterResponse();
    Uint8List seedKey = Uint8List(0);

    try {
      bool isWriteStarted = false;
      for (int i = 0; i < lineData.length; i++) {
        String formattedLine = lineData[i].replaceAll('\r', '').trim();

        // Skip comments and empty lines
        if (formattedLine.startsWith("//") || formattedLine.isEmpty) {
          continue;
        }

        if (formattedLine.contains("startwrite")) isWriteStarted = true;
        if (isWriteStarted && formattedLine.contains("endwrite"))
          isWriteStarted = false;

        if (!isWriteStarted) continue;

        List<String> lineParts = formattedLine.split(':');
        String command = lineParts[0];
        String info = lineParts.length > 1 ? lineParts[1] : "";

        if (command == "send" || command == "sendroutine") {
          List<String> splitData = info.split('+');
          List<int> txFrameList = [];

          for (var item in splitData) {
            if (!item.contains("<")) {
              txFrameList.addAll(hexStringToByteArray(item));
            } else {
              int endIndex = item.indexOf('>');
              String bracketString = item.substring(1, endIndex);
              List<String> bracketParts = bracketString.split(',');
              String reference = bracketParts[0];

              int copyLength = 0;
              if (bracketString.contains(',')) {
                copyLength = int.parse(bracketParts[1], radix: 16);
              }

              Uint8List? copyArray = Uint8List(0);

              if (reference.contains("key")) {
                copyArray = seedKey;
              } else if (reference.contains("pid_addr")) {
                Uint8List addrArray = hexStringToByteArray(
                  writeParameter.pid ?? "",
                );
                if (addrArray.length > copyLength) {
                  copyArray = addrArray.sublist(addrArray.length - copyLength);
                } else {
                  copyArray = addrArray;
                }
              } else if (reference.contains("pid_len")) {
                // Get total bytes as Big Endian byte array
                int totalBytes = writeParameter.totalBytes ?? 0;
                ByteData bData = ByteData(4)
                  ..setUint32(0, totalBytes, Endian.big);
                Uint8List lenArray = bData.buffer.asUint8List();

                if (lenArray.length > copyLength) {
                  copyArray = lenArray.sublist(lenArray.length - copyLength);
                } else {
                  copyArray = lenArray;
                }
              } else if (reference.contains("writePid")) {
                // Wrap the List<int> in Uint8List.fromList to convert the type
                copyArray = Uint8List.fromList(writeParameter.writeInput ?? []);
                copyLength = writeParameter.totalBytes ?? 0;
              }

              // Resize logic: Ensure copyArray matches copyLength
              Uint8List finalCopy = Uint8List(copyLength);
              int bytesToCopy = copyArray.length > copyLength
                  ? copyLength
                  : copyArray.length;
              finalCopy.setRange(0, bytesToCopy, copyArray);

              txFrameList.addAll(finalCopy);
            }
          }

          Uint8List txFrame = Uint8List.fromList(txFrameList);
          print("send : Sending Command ${byteArrayToString(txFrame)}");
          reprogrammingResponse = await dongleComm!.canTxRx(
            txFrame.length,
            byteArrayToString(txFrame),
          );

          // Handle Time Delay Error
          while (reprogrammingResponse?.ecuResponseStatus ==
              "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
            await Future.delayed(const Duration(milliseconds: 300));
            reprogrammingResponse = await dongleComm!.canTxRx(
              txFrame.length,
              byteArrayToString(txFrame),
            );
          }

          writeParameterResponse.status =
              reprogrammingResponse?.ecuResponseStatus;

          if (reprogrammingResponse?.ecuResponseStatus != "NOERROR") {
            print(
              "ELMZ : --------- reprogrammingResponse ERROR------------==${reprogrammingResponse?.ecuResponseStatus}",
            );
            return writeParameterResponse;
          }

          // Handle Routine Loop
          if (command == "sendroutine") {
            // Equivalent of 3103 + substring after first 4 chars of splitData[0]
            String routineReqCommand =
                "3103" + splitData[0].trim().substring(4);

            bool isRoutineLoop = true;
            while (isRoutineLoop) {
              await Future.delayed(const Duration(milliseconds: 500));
              print("RoutineSend : Sending Command $routineReqCommand");
              reprogrammingResponse = await dongleComm!.canTxRx(
                routineReqCommand.length ~/ 2,
                routineReqCommand,
              );

              if (reprogrammingResponse.ecuResponseStatus != "NOERROR") {
                print(
                  "ELMZ : --------- Routine ERROR------------==${reprogrammingResponse.ecuResponseStatus}",
                );
                isRoutineLoop = false;
                writeParameterResponse.status =
                    reprogrammingResponse.ecuResponseStatus;
                return writeParameterResponse;
              } else if (reprogrammingResponse.actualDataBytes![4] != 0x02) {
                // Routine no longer active/finished
                isRoutineLoop = false;
              }
            }
          }
        } else if (command == "sleep") {
          await Future.delayed(Duration(milliseconds: int.parse(info)));
        } else if (command == "function") {
          if (info.contains("CalculateKeyFromSeed")) {
            int startIdx = info.indexOf('[') + 1;
            int endIdx = info.indexOf(']');
            String sqrBktInfo = info.substring(startIdx, endIdx);
            List<String> params = sqrBktInfo.split(',');

            String seedKeyIndexStr = params[0].replaceAll('-', '_');
            int seedKeyNumBytes = int.parse(params[1], radix: 16);

            // Find Enum value in Dart
            SeedKeyIndexType selectedIndex = SeedKeyIndexType.values.firstWhere(
              (e) => e.toString().split('.').last == seedKeyIndexStr,
              orElse: () => SeedKeyIndexType.values.first,
            );

            Uint8List? actualData = reprogrammingResponse!.actualDataBytes;
            Uint8List seedArray = actualData!.sublist(2, 2 + seedKeyNumBytes);

            print("-------seed array = ${byteArrayToString(seedArray)}-------");
            print("-------get key-------");

            // Buffer for result
            List<int> keyBuffer = [];
            await calculateSeedkey!.calculateSeedkey(
              index: selectedIndex,
              seed: seedArray,
              keyOutput: keyBuffer,
            );

            seedKey = Uint8List.fromList(keyBuffer);
            print(
              "-------get key response = ${byteArrayToString(seedKey)}-------",
            );
          }
        }
      }
    } catch (ex, stackTrace) {
      print("Exception : $ex $stackTrace");
      writeParameterResponse.status = "Exception";
    }

    return writeParameterResponse;
  }

  bool testCondition = false;
  bool stopTimer = true;

  /// Dart implementation of IORTestParameters1
  Future<ResponseArrayStatus> iorTestParameters1({
    SeedKeyIndexType? seedKeyIndex,
    WriteParameterIndex? writeParameterIndex,
    String? startCommand,
    String? requestCommand,
    String? stopCommand,
    bool? initialTestCondition,
    int? bitPosition,
    String? activeCommand,
    String? completeCommand,
    String? failCommand,
    bool? isStop,
    int? timeBase,
  }) async {
    print("-------START IOR TEST METHOD-------");
    ResponseArrayStatus response = ResponseArrayStatus();

    if (!isStop!) {
      print("-------Entered-------");
      testCondition = true;

      int diagnosticsMode = 0x03; // Default based on your UDS logic
      int getSeedIndex = 0x01;

      // Logic for WriteParameterIndex mapping
      if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
        getSeedIndex = 0x09;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
        getSeedIndex = 0x0B;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
        getSeedIndex = 0x03;
      } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
        getSeedIndex = 0x05;
      }

      // 1. Session Control
      Uint8List txFrame = Uint8List.fromList([0x10, diagnosticsMode]);
      print("-------Send the parameter ID to the ECU-------");
      response = await dongleComm!.canTxRx(2, byteArrayToString(txFrame));

      if (response.ecuResponseStatus == "NOERROR") {
        // 2. Request Seed
        txFrame[0] = 0x27;
        txFrame[1] = getSeedIndex;
        print("-------Send get seed command to ECU-------");
        response = await dongleComm!.canTxRx(2, byteArrayToString(txFrame));

        if (response.ecuResponseStatus ==
            "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
          await Future.delayed(const Duration(milliseconds: 11000));
          response = await dongleComm!.canTxRx(2, byteArrayToString(txFrame));
        }

        if (response.ecuResponseStatus == "NOERROR") {
          // 3. Security Access (Seed-Key)
          Uint8List seedArray = response.actualDataBytes!.sublist(2);
          List<int> keyBuffer = [];

          await calculateSeedkey!.calculateSeedkey(
            index: seedKeyIndex!,
            seed: seedArray,
            keyOutput: keyBuffer,
          );

          Uint8List actualKey = Uint8List.fromList(keyBuffer);
          Uint8List keyFrame = Uint8List(actualKey.length + 2);
          keyFrame[0] = 0x27;
          keyFrame[1] = getSeedIndex + 1;
          keyFrame.setRange(2, 2 + actualKey.length, actualKey);

          response = await dongleComm!.canTxRx(
            keyFrame.length,
            byteArrayToString(keyFrame),
          );

          if (response.ecuResponseStatus == "NOERROR") {
            // 4. Start Test Command
            print("-------START COMMAND SENDING-------");
            response = await dongleComm!.canTxRx(
              startCommand!.length ~/ 2,
              startCommand,
            );

            if (response.ecuResponseStatus == "NOERROR") {
              int currentTimerCount = timeBase!;

              // Handle Countdown Timer
              if (currentTimerCount > 0) {
                stopTimer = true;
                testCondition = true;

                Timer.periodic(const Duration(seconds: 1), (timer) async {
                  currentTimerCount--;
                  print("Count : $currentTimerCount");

                  if (currentTimerCount < 1 && testCondition) {
                    print("Condition True : $currentTimerCount");
                    stopTimer = false;
                    testCondition = false;
                    timer.cancel();

                    print("-------STOP COMMAND SENDING-------");
                    var stopRes = await dongleComm!.canTxRx(
                      stopCommand!.length ~/ 2,
                      stopCommand,
                    );
                    if (stopRes.ecuResponseStatus == "NOERROR") {
                      // Update external status via a callback or provider if needed
                    }
                  }
                  if (!stopTimer) timer.cancel();
                });
              }

              // 5. Monitoring Loop (Request Status)
              while (testCondition) {
                response = await dongleComm!.canTxRx(
                  requestCommand!.length ~/ 2,
                  requestCommand,
                );

                if (response.ecuResponseStatus == "NOERROR") {
                  int statusByte = response.actualDataBytes![bitPosition! - 1];
                  int activeByte = hexStringToByteArray(activeCommand!)[0];
                  int completeByte = hexStringToByteArray(completeCommand!)[0];
                  int failByte = hexStringToByteArray(failCommand!)[0];

                  if (statusByte != activeByte) {
                    testCondition = false;
                    stopTimer = false;

                    if (statusByte == completeByte) {
                      response.ecuResponseStatus = "Test Completed";
                    } else if (statusByte == failByte) {
                      response.ecuResponseStatus = "Test Aborted";
                    }
                  }
                } else {
                  testCondition = false;
                  stopTimer = false;
                }
                // Prevent CPU hogging in while loop
                await Future.delayed(const Duration(milliseconds: 100));
              }
            }
          }
        }
      }
    } else {
      // Handling Stop Logic
      stopTimer = false;
      testCondition = false;
      print("-------STOP COMMAND SENDING------- Stop");
      response = await dongleComm!.canTxRx(
        stopCommand!.length ~/ 2,
        stopCommand,
      );
      if (response.ecuResponseStatus == "NOERROR") {
        response.ecuResponseStatus = "Test Stopped";
      }
    }

    return response;
  }

  bool activeCon = false;

  Future<ResponseArrayStatus> iorTestParameters2({
    SeedKeyIndexType? seedKeyIndex,
    WriteParameterIndex? writeParameterIndex,
    String? startCommand,
    String? requestCommand,
    String? stopCommand,
    bool? initialTestCondition,
    int? bitPosition,
    List<String>? activeCommands, // Changed to List
    String? completeCommand,
    String? failCommand,
    bool? isStop,
    int? timeBase,
    bool? isTimebase,
  }) async {
    print("-------START IOR TEST METHOD-------");
    ResponseArrayStatus responseArrayStatus = ResponseArrayStatus();

    if (!isStop!) {
      // If timebase is enabled, start the countdown timer
      if (isTimebase! && timeBase! > 0) {
        stopTimer = true;
        testCondition = true;
        int currentTimerCount = timeBase;

        Timer.periodic(const Duration(seconds: 1), (timer) async {
          currentTimerCount -= 1;
          print("Count : $currentTimerCount");

          if (currentTimerCount < 1 && testCondition) {
            print("Condition True : $currentTimerCount");
            stopTimer = false;
            testCondition = false;
            timer.cancel();

            print("-------STOP COMMAND SENDING-------");
            var stopRes = await dongleComm!.canTxRx(
              stopCommand!.length ~/ 2,
              stopCommand,
            );
            if (stopRes.ecuResponseStatus == "NOERROR") {
              // In a real app, you'd likely use a Listenable or Stream to update the UI here
              responseArrayStatus.ecuResponseStatus = "Test Stopped";
            }
          }

          if (!stopTimer) timer.cancel();
        });
      }

      // Main monitoring loop
      while (testCondition) {
        responseArrayStatus = await dongleComm!.canTxRx(
          requestCommand!.length ~/ 2,
          requestCommand,
        );

        if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
          int currentByteValue =
              responseArrayStatus.actualDataBytes![bitPosition! - 1];
          int completeByte = hexStringToByteArray(completeCommand!)[0];

          activeCon = false;

          // Check if current byte matches any of the active commands in the list
          for (String active in activeCommands!) {
            int activeByte = hexStringToByteArray(active)[0];
            if (currentByteValue == activeByte) {
              activeCon = true;
            }
            print(
              "Compare Byte = $currentByteValue - $completeByte - $activeByte",
            );
          }

          // If the status is no longer "Active", determine if it's Completed or Failed
          if (!activeCon) {
            testCondition = false;
            stopTimer = false;

            if (currentByteValue == completeByte) {
              responseArrayStatus.ecuResponseStatus = "Test Completed";
            } else if (currentByteValue ==
                hexStringToByteArray(failCommand!)[0]) {
              responseArrayStatus.ecuResponseStatus = "Test Aborted";
            }
          }
        } else {
          testCondition = false;
          stopTimer = false;
        }

        // Essential: Yield control to the event loop so the Timer and UI can run
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      // Immediate Stop Logic
      stopTimer = false;
      testCondition = false;
      print("-------STOP COMMAND SENDING------- Stop");
      responseArrayStatus = await dongleComm!.canTxRx(
        stopCommand!.length ~/ 2,
        stopCommand,
      );

      if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
        responseArrayStatus.ecuResponseStatus = "Test Stopped";
      }
    }

    return responseArrayStatus;
  }

  Future<ResponseArrayStatus> startIdIOR(
    SeedKeyIndexType seedKeyIndex1,
    WriteParameterIndex writeParameterIndex,
    String startCommand,
  ) async {
    print("-------START IOR TEST METHOD-------");
    ResponseArrayStatus responseArrayStatus = ResponseArrayStatus();
    print("-------Entered-------");

    // Logic used in earlier methods to keep the test state

    int diagnosticsMode = 0x00;
    int getSeedIndex = 0x00;

    // Map the session and seed requirements based on the index
    if (writeParameterIndex == WriteParameterIndex.UDS) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x01;
    } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK090A) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x09;
    } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0102) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x01;
    } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0B0C) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x0B;
    } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0304) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x03;
    } else if (writeParameterIndex == WriteParameterIndex.UDS_DS1003_SK0506) {
      diagnosticsMode = 0x03;
      getSeedIndex = 0x05;
    }

    Uint8List txFrame = Uint8List(2);
    /* 1. Send Diagnostic Session Control (0x10) */
    txFrame[0] = 0x10;
    txFrame[1] = diagnosticsMode;
    int frameLength = 2;

    print("-------Send the parameter ID to the ECU-------");
    responseArrayStatus = await dongleComm!.canTxRx(
      frameLength,
      byteArrayToHex(txFrame),
    );

    if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
      /* 2. Send Security Access - Request Seed (0x27) */
      txFrame[0] = 0x27;
      txFrame[1] = getSeedIndex;
      print("-------Send get seed command to ECU-------");
      responseArrayStatus = await dongleComm!.canTxRx(
        frameLength,
        byteArrayToHex(txFrame),
      );

      // Handle Required Time Delay (usually after multiple failed attempts)
      if (responseArrayStatus.ecuResponseStatus ==
          "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
        await Future.delayed(const Duration(milliseconds: 11000));
        responseArrayStatus = await dongleComm!.canTxRx(
          frameLength,
          byteArrayToHex(txFrame),
        );
      }

      if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
        int seedKeyIndex = getSeedIndex;

        // Extract Seed from response (skipping first 2 bytes)
        Uint8List seedArray = responseArrayStatus.actualDataBytes!.sublist(2);

        // Determine expected key length based on the algorithm index
        if (seedKeyIndex1 == SeedKeyIndexType.sanitasBoschBs6Prod) {
        } else if (seedKeyIndex1 == SeedKeyIndexType.seedkeyalgoVecvDelphiBs6 ||
            seedKeyIndex1 == SeedKeyIndexType.seedkeyalgoVecvAmtBs6) {
        } else if (seedKeyIndex1 ==
            SeedKeyIndexType.seedkeyalgoVecvDelphiTcic) {}

        // Calculate Key using the provided buffer-filling logic
        List<int> actualKeyBuffer = [];
        await calculateSeedkey!.calculateSeedkey(
          index: seedKeyIndex1,
          seed: seedArray,
          keyOutput: actualKeyBuffer,
        );

        // result.numBytes is inferred from the buffer length in Dart
        int numKeyBytes = actualKeyBuffer.length;

        if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
          /* 3. Send Security Access - Send Key (0x27) */
          Uint8List newTxFrame = Uint8List(numKeyBytes + 2);
          newTxFrame[0] = 0x27;
          newTxFrame[1] = seedKeyIndex + 1; // getseedindex + 1

          newTxFrame.setRange(2, 2 + numKeyBytes, actualKeyBuffer);
          frameLength = newTxFrame.length;

          responseArrayStatus = await dongleComm!.canTxRx(
            frameLength,
            byteArrayToHex(newTxFrame),
          );

          if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
            /* 4. Send the specific IOR Start Command */
            print("-------START COMMAND SENDING-------");
            responseArrayStatus = await dongleComm!.canTxRx(
              startCommand.length ~/ 2,
              startCommand,
            );
          } else {
            // Log or handle security access (key) error
            print(
              "Security Access Key Failed: ${responseArrayStatus.ecuResponseStatus}",
            );
          }
        }
      } else {
        print(
          "Security Access Seed Request Failed: ${responseArrayStatus.ecuResponseStatus}",
        );
      }
    }

    return responseArrayStatus;
  }

  Future<ResponseArrayStatus> requestIdIOR(String requestCommand) async {
    print("-------START IOR TEST METHOD-------");

    // Calculate length: command string length divided by 2 (2 hex chars per byte)
    int frameLength = requestCommand.length ~/ 2;

    // Perform the asynchronous TxRx operation
    ResponseArrayStatus responseArrayStatus = await dongleComm!.canTxRx(
      frameLength,
      requestCommand,
    );

    return responseArrayStatus;
  }

  Future<ResponseArrayStatus> stopIdIOR(String stopCommand) async {
    print("-------STOP IOR TEST METHOD-------");
    ResponseArrayStatus responseArrayStatus = ResponseArrayStatus();
    print("STOP COMMAND SENDING : $stopCommand");

    // Calculate length based on hex string pairs
    int frameLength = stopCommand.length ~/ 2;

    // Perform the TxRx operation
    responseArrayStatus = await dongleComm!.canTxRx(frameLength, stopCommand);

    if (responseArrayStatus.ecuResponseStatus == "NOERROR") {
      // Standard UDS success response (0x6F) usually doesn't require extra logic here
    } else {
      // If the stop command fails, force the background loops/timers to stop
      testCondition = false;
      stopTimer = false;
    }

    return responseArrayStatus;
  }

  Future<dynamic> testRoutine(String command) async {
    try {
      // Perform the TxRx operation
      // ~/ is integer division in Dart (replaces command.length / 2)
      var responseBytes = await dongleComm!.canTxRx(
        command.length ~/ 2,
        command,
      );

      return responseBytes;
    } catch (ex) {
      // Log the exception if a logger is available
      print("Error in testRoutine: $ex");
      return null;
    }
  }

  Future<String?> startEcuUnlocking(
    String txFrame,
    String txFrequency,
    String txTotalTime,
  ) async {
    try {
      int frameLen = txFrame.length ~/ 2;

      // Parse strings to integers
      int frequencyMs = int.parse(txFrequency);
      int totalTimeMs = int.parse(txTotalTime);

      // Stopwatch equivalent in Dart
      Stopwatch stopwatch = Stopwatch()..start();

      // Device.StartTimer equivalent in Dart is Timer.periodic
      Timer.periodic(Duration(milliseconds: frequencyMs), (timer) {
        if (stopwatch.elapsedMilliseconds < totalTimeMs) {
          // Fire and forget the TxRx call just like Task.Run
          // We don't await this because we want the timer to keep ticking
          dongleComm!
              .canTxRx(frameLen, txFrame)
              .then((response) {
                // Optional: handle response inside the keep-alive loop
              })
              .catchError((e) {
                print("Unlocking keep-alive error: $e");
              });
        } else {
          // Stop the timer and the stopwatch
          stopwatch.stop();
          timer.cancel();
        }
      });

      // Note: In your C# code, 'response' was never assigned before returning.
      // I am returning an empty string or a success indicator.
      return "Started";
    } catch (ex) {
      print("Exception in startEcuUnlocking: $ex");
      return null;
    }
  }

  Future<List<ReadParameterResponse>?> readParametersFromAddr1(
    int noOfParameters,
    List<ReadParameterPID> readParameterCollection,
    String pidByAddrSeq,
  ) async {
    try {
      // Split by newline and remove carriage returns
      List<String> lineData = pidByAddrSeq.split('\n');

      for (int i = 0; i < lineData.length; i++) {
        String formattedLine = lineData[i].replaceAll('\r', '').trim();

        // Skip comments or empty lines
        if (formattedLine.startsWith("//") || formattedLine.isEmpty) {
          continue;
        }

        // Ensure the line contains a colon before splitting
        if (!formattedLine.contains(':')) continue;

        List<String> parts = formattedLine.split(':');
        String command = parts[0].trim();
        String info = parts[1].trim();

        if (command == "send") {
          // splitData logic
          List<String> splitData = info.split('+');

          // Example of how to convert hex strings to bytes
          List<int> txFrame = [];
          for (String segment in splitData) {
            // This assumes hexStringToByteArray is defined in your project
            txFrame.addAll(hexStringToByteArray(segment.trim()));
          }

          // Convert to Uint8List for CAN transmission
          // ignore: unused_local_variable
          Uint8List requestBytes = Uint8List.fromList(txFrame);

          // Example TxRx call
          // var response = await dongleComm.canTxRx(requestBytes.length, byteArrayToHex(requestBytes));
        }
      }

      // Returning empty list or null as per your C# placeholder
      return null;
    } catch (e) {
      print("Error parsing Address Sequence: $e");
      return null;
    }
  }

  int totalBytesToBeFlashed = 0;
  int realTimeBytesFlashed = 0;

  Future<void> resetPercentage() async {
    totalBytesToBeFlashed = 0;
    realTimeBytesFlashed = 0;
  }

  Future<double> getRuntimeFlashPercent() async {
    // Check to prevent division by zero if flashing hasn't started
    if (totalBytesToBeFlashed == 0) {
      return 0.0;
    }

    // Dart's / operator returns a double by default
    double runtimeFlashPercent = realTimeBytesFlashed / totalBytesToBeFlashed;

    return runtimeFlashPercent;
  }

  List<LoopModel> loopModelList = [];

  Future<String?> flashInterpreter1(
    FlashConfig flashconfigData,
    int noofsectors,
    List<FlashingMatrix> sectordata,
    String interpreterFile,
  ) async {
    ResponseArrayStatus reprogrammingResponse = ResponseArrayStatus();

    try {
      dongleComm!.saveLog("------Start Flashing------\n");

      // ── ENTRY DIAGNOSTICS ─────────────────────────────────────────────────
      print("🚀 flashInterpreter START");
      print("📋 noofsectors: $noofsectors");
      print("📋 sectordata count: ${sectordata.length}");
      print("📋 interpreterFile length: ${interpreterFile.length}");
      print(
        "📋 interpreterFile preview: ${interpreterFile.length > 300 ? interpreterFile.substring(0, 300) : interpreterFile}",
      );

      if (interpreterFile.isEmpty) {
        print("❌ interpreterFile is EMPTY — cannot flash");
        return "ERROR : interpreter file is empty";
      }
      if (noofsectors == 0 || sectordata.isEmpty) {
        print(
          "❌ No sector data — noofsectors=$noofsectors sectordata=${sectordata.length}",
        );
        return "ERROR : no sector data";
      }

      List<String> lineData = interpreterFile.split('\n');
      print("📋 Total interpreter lines: ${lineData.length}");

      // ── TOTAL BYTES CALCULATION ───────────────────────────────────────────
      totalBytesToBeFlashed = 0;
      for (int i = 0; i < noofsectors; i++) {
        Uint8List sectorDataArray = hexStringToByteArray(
          sectordata[i].jsonData ?? "",
        );
        int sectorNumBytes = sectorDataArray.length;
        totalBytesToBeFlashed += sectorNumBytes;
        realTimeBytesFlashed = 0;
        print(
          "📦 Sector[$i] jsonData length (bytes): $sectorNumBytes | startAddr: ${sectordata[i].jsonStartAddress} | endAddr: ${sectordata[i].jsonEndAddress}",
        );
      }
      print("📦 totalBytesToBeFlashed: $totalBytesToBeFlashed");

      Uint8List seedKey = Uint8List(0);
      int currSectorIndex = 0;
      bool isLoopPresent = false;
      int loopInit = 0;
      bool skipKey = false;

      // ── INTERPRETER LOOP ──────────────────────────────────────────────────
      for (int i = 0; i < lineData.length; i++) {
        String formattedLine = lineData[i].replaceAll('\r', '').trim();

        if (formattedLine.isEmpty || formattedLine.startsWith("//")) {
          continue;
        } else if (skipKey) {
          print("⏭ Skipping line (skipKey=true): $formattedLine");
          skipKey = false;
          continue;
        }

        List<String> parts = formattedLine.split(':');
        String command = parts[0];
        String info = parts.length > 1 ? parts[1] : "";

        print("🔄 Line[$i] command='$command' info='$info'");

        if (command == "send" ||
            command == "sendroutine" ||
            command == "sendignore" ||
            command == "sendroutineignore") {
          List<String> splitData = info.split('+');
          List<int> txFrameList = [];

          for (var item in splitData) {
            if (!item.contains("<")) {
              txFrameList.addAll(hexStringToByteArray(item));
            } else {
              int endIndex = item.indexOf('>');
              String bracketString = item.substring(1, endIndex);
              List<String> bParts = bracketString.split(',');
              String reference = bParts[0];
              int copyLength = int.parse(bParts[1]);
              print("   🔧 reference='$reference' copyLength=$copyLength");

              Uint8List copyArray = Uint8List(0);

              if (reference.contains("key")) {
                copyArray = seedKey;
                print("   🔑 key bytes: ${byteArrayToHex(seedKey)}");
              } else if (reference.contains("json_strt_addr") ||
                  reference.contains("ecu_memmap_strt_addr")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                String addrHex = reference.contains("json_strt_addr")
                    ? (sectordata[index].jsonStartAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      )
                    : (sectordata[index].ecuMemMapStartAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      );
                copyArray = hexStringToByteArray(addrHex);
                print("   📍 start_addr[$index]: $addrHex");
              } else if (reference.contains("json_end_addr") ||
                  reference.contains("ecu_memmap_end_addr")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                String addrHex = reference.contains("json_end_addr")
                    ? (sectordata[index].jsonEndAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      )
                    : (sectordata[index].ecuMemMapEndAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      );
                copyArray = hexStringToByteArray(addrHex);
                print("   📍 end_addr[$index]: $addrHex");
              } else if (reference.contains("json_checksum")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                String checkSumHex = (sectordata[index].jsonCheckSum ?? "")
                    .padLeft(copyLength * 2, '0');
                copyArray = hexStringToByteArray(checkSumHex);
                print("   🔢 checksum[$index]: $checkSumHex");
              } else if (reference.contains("json_sector_len") ||
                  reference.contains("ecu_memmap_len")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                int sectorNumBytes;
                if (reference.contains("json_sector_len")) {
                  sectorNumBytes =
                      int.parse(sectordata[index].jsonEndAddress!, radix: 16) -
                      int.parse(
                        sectordata[index].jsonStartAddress!,
                        radix: 16,
                      ) +
                      1;
                } else {
                  sectorNumBytes =
                      int.parse(
                        sectordata[index].ecuMemMapEndAddress!,
                        radix: 16,
                      ) -
                      int.parse(
                        sectordata[index].ecuMemMapStartAddress!,
                        radix: 16,
                      ) +
                      1;
                }
                String hexLen = sectorNumBytes
                    .toRadixString(16)
                    .padLeft(copyLength * 2, '0');
                copyArray = hexStringToByteArray(hexLen);
                print(
                  "   📏 sector_len[$index]: $sectorNumBytes bytes → $hexLen",
                );
              } else if (reference.contains("calculate_sector_len")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                int sectorNumBytes = (sectordata[index].jsonData!.length ~/ 2);
                String hexLen = sectorNumBytes
                    .toRadixString(16)
                    .padLeft(copyLength * 2, '0');
                copyArray = hexStringToByteArray(hexLen);
                print(
                  "   📏 calc_sector_len[$index]: $sectorNumBytes bytes → $hexLen",
                );
              } else if (reference.contains("i")) {
                copyArray = Uint8List.fromList([
                  loopModelList.last.i! + loopInit,
                ]);
                print(
                  "   🔢 loop i value: ${loopModelList.last.i! + loopInit}",
                );
              } else {
                print(
                  "   ⚠️ Unknown reference: '$reference' — copyArray will be empty",
                );
              }

              Uint8List finalBuffer = Uint8List(copyLength);
              int actualToCopy = copyArray.length > copyLength
                  ? copyLength
                  : copyArray.length;
              finalBuffer.setRange(0, actualToCopy, copyArray);
              txFrameList.addAll(finalBuffer);
            }
          }

          Uint8List txFrame = Uint8List.fromList(txFrameList);
          print(
            "📤 send[$command]: ${byteArrayToHex(txFrame)} (${txFrame.length} bytes)",
          );

          var sendResp = await dongleComm!.canTxRx(
            txFrame.length,
            byteArrayToHex(txFrame),
          );
          print("📥 send response: '${sendResp.ecuResponseStatus}'");

          if (command != "sendignore") {
            reprogrammingResponse = sendResp;
          }

          while (reprogrammingResponse.ecuResponseStatus ==
              "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
            print("⏳ RequiredTimeDelay — retrying in 300ms...");
            await Future.delayed(const Duration(milliseconds: 300));
            reprogrammingResponse = await dongleComm!.canTxRx(
              txFrame.length,
              byteArrayToHex(txFrame),
            );
            print(
              "📥 retry response: '${reprogrammingResponse.ecuResponseStatus}'",
            );
          }

          if (reprogrammingResponse.ecuResponseStatus != "NOERROR" &&
              command != "sendignore") {
            print("❌ send ERROR: '${reprogrammingResponse.ecuResponseStatus}'");
            return reprogrammingResponse.ecuResponseStatus;
          }

          if (command == "sendroutine" || command == "sendroutineignore") {
            String routineReqCommand =
                "3103" + splitData[0].trim().substring(4);
            print("🔁 sendroutine polling: $routineReqCommand");
            bool isRoutineLoop = true;
            while (isRoutineLoop) {
              await Future.delayed(const Duration(milliseconds: 500));
              var routineResp = await dongleComm!.canTxRx(
                routineReqCommand.length ~/ 2,
                routineReqCommand,
              );
              print(
                "📥 routine response: '${routineResp.ecuResponseStatus}' data: ${routineResp.actualDataBytes != null ? byteArrayToHex(routineResp.actualDataBytes!) : 'null'}",
              );

              if (command != "sendroutineignore") {
                reprogrammingResponse = routineResp;
              }

              if (reprogrammingResponse.ecuResponseStatus != "NOERROR" &&
                  command != "sendroutineignore") {
                print(
                  "❌ routine ERROR: '${reprogrammingResponse.ecuResponseStatus}'",
                );
                isRoutineLoop = false;
                return reprogrammingResponse.ecuResponseStatus;
              } else if (routineResp.ecuResponseStatus != "NOERROR" &&
                  command == "sendroutineignore") {
                isRoutineLoop = false;
              } else {
                int statusByte = reprogrammingResponse.actualDataBytes![4];
                print(
                  "   routine statusByte[4]: 0x${statusByte.toRadixString(16).padLeft(2, '0')}",
                );
                if (statusByte == 0x02 ||
                    statusByte == 0x01 ||
                    statusByte == 0x04) {
                  print("   ✅ routine complete");
                  isRoutineLoop = false;
                }
              }
            }
          }
        } else if (command == "sleep") {
          int ms = int.parse(info);
          print("💤 sleep ${ms}ms");
          await Future.delayed(Duration(milliseconds: ms));
        } else if (command == "function") {
          print("⚙️ function: $info");
          if (info.contains("CalculateKeyFromSeed")) {
            var firstSplit = info.split('[');
            var secondSplit = firstSplit[1].split(',');
            String index1Str = secondSplit[0];
            String seedKeyNumBytesStr = secondSplit[1].substring(
              0,
              secondSplit[1].length - 1,
            );

            print("   🔑 index1Str (raw): '$index1Str'");
            print("   🔑 seedKeyNumBytesStr: '$seedKeyNumBytesStr'");

            int seedLen = int.parse(seedKeyNumBytesStr);
            print("   🔑 seedLen: $seedLen");
            print(
              "   🔑 reprogrammingResponse data length: ${reprogrammingResponse.actualDataBytes?.length ?? 'null'}",
            );

            Uint8List seedArray = reprogrammingResponse.actualDataBytes!
                .sublist(2, 2 + seedLen);
            print("   🌱 seed array: ${byteArrayToHex(seedArray)}");

            if (seedArray.every((x) => x == 0)) {
              print("   ⚠️ Seed is all zeros — skipKey=true");
              skipKey = true;
            }

            // In flashInterpreter, replace the SeedKeyIndexType lookup:

            final normalizedIndex = index1Str.replaceAll('-', '_');
            print("   🔑 normalized index: '$normalizedIndex'");
            print(
              "   🔑 Available SeedKeyIndexType values: ${SeedKeyIndexType.values.map((e) => e.toString().split('.').last).toList()}",
            );

            // ✅ FIX: strip underscores + lowercase for camelCase vs SNAKE_CASE matching
            SeedKeyIndexType seedKeyIndex = SeedKeyIndexType.values.firstWhere(
              (e) => e.toString().split('.').last == normalizedIndex,
              orElse: () {
                print(
                  "   ⚠️ No exact match — trying snake_case stripped comparison",
                );

                // e.g. 'KOEL_AUTO_BS4' → 'koelautobs4'  vs  'koelAutoBs4' → 'koelautobs4'
                final strippedInput = normalizedIndex
                    .replaceAll('_', '')
                    .toLowerCase();
                print("   🔑 strippedInput: '$strippedInput'");

                SeedKeyIndexType? match;
                try {
                  match = SeedKeyIndexType.values.firstWhere(
                    (e) =>
                        e.toString().split('.').last.toLowerCase() ==
                        strippedInput,
                  );
                } catch (_) {
                  match = null;
                }

                if (match != null) {
                  print("   ✅ Stripped match found: $match");
                  return match;
                }

                print(
                  "   ❌ No match at all — falling back to first: ${SeedKeyIndexType.values.first}",
                );
                print(
                  "   📋 Available values: ${SeedKeyIndexType.values.map((e) => e.toString().split('.').last).toList()}",
                );
                return SeedKeyIndexType.values.first;
              },
            );
            print("   ✅ seedKeyIndex resolved: $seedKeyIndex");
            print("   ✅ seedKeyIndex resolved: $seedKeyIndex");
            print("   ✅ seedKeyIndex resolved: $seedKeyIndex");

            List<int> keyOutput = [];
            await calculateSeedkey!.calculateSeedkey(
              index: seedKeyIndex,
              seed: seedArray,
              keyOutput: keyOutput,
            );
            seedKey = Uint8List.fromList(keyOutput);
            print(
              "   🗝 calculated key: ${byteArrayToHex(seedKey)} (${seedKey.length} bytes)",
            );
          }
        } else if (command == "repeatstart") {
          isLoopPresent = true;
          List<String> sData = info.split(',');
          int maxIdx = sData[3] == "noofsectors"
              ? noofsectors
              : int.parse(sData[3]);
          loopInit = int.parse(sData[2]);
          loopModelList.add(
            LoopModel(
              i: 0,
              loopId: int.parse(sData[0]),
              maxIndex: maxIdx,
              loopLocation: i,
            ),
          );
          print(
            "🔁 repeatstart — loopId=${sData[0]} maxIdx=$maxIdx loopInit=$loopInit",
          );
        } else if (command == "repeatend") {
          loopModelList.last.i = (loopModelList.last.i ?? 0) + 1;
          print(
            "🔁 repeatend — i=${loopModelList.last.i} / maxIndex=${loopModelList.last.maxIndex}",
          );
          if (loopModelList.last.i == loopModelList.last.maxIndex) {
            print("✅ Loop complete — removing from stack");
            loopModelList.removeLast();
          } else {
            i = loopModelList.last.loopLocation ?? 0;
            print("↩️ Loop back to line $i");
          }
        } else if (command == "sendbulkdata") {
          List<String> sInfo = info.split(',');
          int seqVarInitValue = int.parse(sInfo[1]);
          String transferInfo = sInfo[2];

          int startBracket = info.indexOf('[') + 1;
          int endBracket = info.indexOf(']');
          String sqrBktInfo = info.substring(startBracket, endBracket);
          int sectorFrameTransferLen = int.parse(
            sqrBktInfo.split(',')[1].trim(),
            radix: 16,
          );

          int blkSeqCnt = seqVarInitValue;
          int index = isLoopPresent
              ? loopModelList.last.i ?? 0
              : currSectorIndex;

          print(
            "📦 sendbulkdata — sectorIndex=$index seqVarInitValue=$seqVarInitValue sectorFrameTransferLen=$sectorFrameTransferLen",
          );

          Uint8List sectorDataArray = hexStringToByteArray(
            sectordata[index].jsonData ?? "",
          );
          int sectorNumBytes = sectorDataArray.length;
          print("📦 sectorDataArray length: $sectorNumBytes bytes");

          for (int j = 0; j < sectorNumBytes;) {
            try {
              int currentTransferLen =
                  (sectorNumBytes - j) < sectorFrameTransferLen
                  ? (sectorNumBytes - j)
                  : sectorFrameTransferLen;

              List<String> tSplitData = transferInfo.split('+');
              List<int> nTxFrameList = [];

              for (var item in tSplitData) {
                String trimmedItem = item.trim();
                if (RegExp(r'^\d+$').hasMatch(trimmedItem)) {
                  nTxFrameList.addAll(hexStringToByteArray(trimmedItem));
                } else if (trimmedItem.contains("bsc")) {
                  nTxFrameList.add(blkSeqCnt & 0xFF);
                } else if (trimmedItem.contains("json_sectordata")) {
                  nTxFrameList.addAll(
                    sectorDataArray.sublist(j, j + currentTransferLen),
                  );
                }
              }

              j += currentTransferLen;
              Uint8List nTxFrame = Uint8List.fromList(nTxFrameList);
              print(
                "📤 bulk[blk=$blkSeqCnt j=$j/${sectorNumBytes}]: ${nTxFrame.length} bytes",
              );

              var bulkResp = await dongleComm!.canTxRx(
                nTxFrame.length,
                byteArrayToHex(nTxFrame),
              );
              print("📥 bulk response: '${bulkResp.ecuResponseStatus}'");
              blkSeqCnt++;

              if (bulkResp.ecuResponseStatus != "NOERROR") {
                print("❌ bulk ERROR: '${bulkResp.ecuResponseStatus}'");
                return bulkResp.ecuResponseStatus;
              }

              realTimeBytesFlashed += currentTransferLen;
            } catch (e) {
              print("❌ bulk exception: $e");
              return e.toString();
            }
          }
          print(
            "✅ sendbulkdata complete — totalFlashed so far: $realTimeBytesFlashed",
          );
        } else if (command == "sendbulkdata") {
          // ── PRE-CALCULATION (Do not put logic inside the loop) ─────────────
          final List<String> sInfo = info.split(',');
          int blkSeqCnt = int.parse(sInfo[1]);
          final String transferInfo = sInfo[2];
          final int index = isLoopPresent
              ? loopModelList.last.i ?? 0
              : currSectorIndex;

          final Uint8List sectorDataArray = hexStringToByteArray(
            sectordata[index].jsonData ?? "",
          );
          final int sectorStartAddr = int.parse(
            sectordata[index].jsonStartAddress!,
            radix: 16,
          );
          final int sectorNumBytes =
              int.parse(sectordata[index].jsonEndAddress!, radix: 16) -
              sectorStartAddr +
              1;

          // HARD LIMIT: Using your verified buffer size
          const int sectorFrameTransferLen = 2665;
          int offset = 0;

          final bool hasBsc = transferInfo.contains("bsc");
          final bool hasData = transferInfo.contains("json_sectordata");

          // Pre-build the static header once
          final List<int> headerBytes = [];
          for (var part in transferInfo.split('+')) {
            String trimmed = part.trim();
            if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
              headerBytes.addAll(hexStringToByteArray(trimmed));
            }
          }

          // ── THE LOOP (Tightened for maximum speed) ────────────────────────
          while (offset < sectorNumBytes) {
            final int currentChunkLen =
                (sectorNumBytes - offset) < sectorFrameTransferLen
                ? (sectorNumBytes - offset)
                : sectorFrameTransferLen;

            // Use BytesBuilder with 'copy: false' to prevent memory spikes
            final builder = BytesBuilder(copy: false);
            builder.add(headerBytes);
            if (hasBsc) builder.addByte(blkSeqCnt & 0xFF);
            if (hasData) {
              builder.add(
                Uint8List.sublistView(
                  sectorDataArray,
                  offset,
                  offset + currentChunkLen,
                ),
              );
            }

            // TRANSMISSION: Use raw bytes if your plugin supports it.
            // If not, this Hex conversion is your biggest enemy.
            final bulkResp = await dongleComm!.canTxRx(
              builder.length,
              byteArrayToHex(builder.takeBytes()),
            );

            if (bulkResp.ecuResponseStatus != "NOERROR") {
              return "BULK_ERR: ${bulkResp.ecuResponseStatus}";
            }

            offset += currentChunkLen;
            blkSeqCnt = (blkSeqCnt + 1) & 0xFF;

            // UPDATE UI ONLY EVERY 10 CHUNKS (Updating UI too often slows the loop)
            if (blkSeqCnt % 10 == 0) {
              realTimeBytesFlashed += (currentChunkLen * 10);
            }
          }
        } else if (command == "txid") {
          print("🔧 txid: $info");
          await dongleComm!.canSetTxHeader(info);
        } else if (command == "rxid") {
          print("🔧 rxid: $info");
          await dongleComm!.canSetRxHeaderMask(info);
        } else if (command == "startpadding") {
          print("🔧 startpadding: $info");
          await dongleComm!.canStartPadding(info);
        } else if (command == "stoppadding") {
          print("🔧 stoppadding");
          await dongleComm!.canStopPadding();
        } else if (command == "setstmin") {
          print("🔧 setstmin: $info");
          await dongleComm!.canSetP1Min(info.trim());
        } else if (command == "setP2Max") {
          print("🔧 setP2Max: $info");
          await dongleComm!.canSetP2Max(info.trim());
        } else if (command == "stopTP") {
          print("🔧 stopTP");
          await dongleComm!.canStopTP();
        } else if (command == "startTP") {
          print("🔧 startTP");
          await dongleComm!.canStartTP();
        } else {
          print("⚠️ Unknown command '$command' — skipping");
        }
      }

      print(
        "🏁 flashInterpreter END — final status: '${reprogrammingResponse.ecuResponseStatus}'",
      );
    } catch (ex, stack) {
      print("❌ flashInterpreter EXCEPTION: $ex");
      print("❌ StackTrace: $stack");
      return ex.toString();
    }

    return reprogrammingResponse.ecuResponseStatus;
  }

  Future<String?> flashInterpreter(
    FlashConfig flashconfigData,
    int noofsectors,
    List<FlashingMatrix> sectordata,
    String interpreterFile,
  ) async {
    ResponseArrayStatus reprogrammingResponse = ResponseArrayStatus();

    try {
      dongleComm!.saveLog("------Start Flashing------\n");

      // ── ENTRY DIAGNOSTICS ─────────────────────────────────────────────────
      print("🚀 flashInterpreter START");
      print("📋 noofsectors: $noofsectors");
      print("📋 sectordata count: ${sectordata.length}");
      print("📋 interpreterFile length: ${interpreterFile.length}");
      print(
        "📋 interpreterFile preview: ${interpreterFile.length > 300 ? interpreterFile.substring(0, 300) : interpreterFile}",
      );

      if (interpreterFile.isEmpty) {
        print("❌ interpreterFile is EMPTY — cannot flash");
        return "ERROR : interpreter file is empty";
      }
      if (noofsectors == 0 || sectordata.isEmpty) {
        print(
          "❌ No sector data — noofsectors=$noofsectors sectordata=${sectordata.length}",
        );
        return "ERROR : no sector data";
      }

      List<String> lineData = interpreterFile.split('\n');
      print("📋 Total interpreter lines: ${lineData.length}");

      // ── TOTAL BYTES CALCULATION ───────────────────────────────────────────
      totalBytesToBeFlashed = 0;
      for (int i = 0; i < noofsectors; i++) {
        Uint8List sectorDataArray = hexStringToByteArray(
          sectordata[i].jsonData ?? "",
        );
        int sectorNumBytes = sectorDataArray.length;
        totalBytesToBeFlashed += sectorNumBytes;
        realTimeBytesFlashed = 0;
        print(
          "📦 Sector[$i] jsonData length (bytes): $sectorNumBytes | startAddr: ${sectordata[i].jsonStartAddress} | endAddr: ${sectordata[i].jsonEndAddress}",
        );
      }
      print("📦 totalBytesToBeFlashed: $totalBytesToBeFlashed");

      Uint8List seedKey = Uint8List(0);
      int currSectorIndex = 0;
      bool isLoopPresent = false;
      int loopInit = 0;
      bool skipKey = false;

      // ── INTERPRETER LOOP ──────────────────────────────────────────────────
      for (int i = 0; i < lineData.length; i++) {
        String formattedLine = lineData[i].replaceAll('\r', '').trim();

        if (formattedLine.isEmpty || formattedLine.startsWith("//")) {
          continue;
        } else if (skipKey) {
          print("⏭ Skipping line (skipKey=true): $formattedLine");
          skipKey = false;
          continue;
        }

        List<String> parts = formattedLine.split(':');
        String command = parts[0];
        String info = parts.length > 1 ? parts[1] : "";

        print("🔄 Line[$i] command='$command' info='$info'");

        if (command == "send" ||
            command == "sendroutine" ||
            command == "sendignore" ||
            command == "sendroutineignore") {
          List<String> splitData = info.split('+');
          List<int> txFrameList = [];

          for (var item in splitData) {
            if (!item.contains("<")) {
              txFrameList.addAll(hexStringToByteArray(item));
            } else {
              int endIndex = item.indexOf('>');
              String bracketString = item.substring(1, endIndex);
              List<String> bParts = bracketString.split(',');
              String reference = bParts[0];
              int copyLength = int.parse(bParts[1]);
              print("   🔧 reference='$reference' copyLength=$copyLength");

              Uint8List copyArray = Uint8List(0);

              if (reference.contains("key")) {
                copyArray = seedKey;
                print("   🔑 key bytes: ${byteArrayToHex(seedKey)}");
              } else if (reference.contains("json_strt_addr") ||
                  reference.contains("ecu_memmap_strt_addr")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                String addrHex = reference.contains("json_strt_addr")
                    ? (sectordata[index].jsonStartAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      )
                    : (sectordata[index].ecuMemMapStartAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      );
                copyArray = hexStringToByteArray(addrHex);
                print("   📍 start_addr[$index]: $addrHex");
              } else if (reference.contains("json_end_addr") ||
                  reference.contains("ecu_memmap_end_addr")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                String addrHex = reference.contains("json_end_addr")
                    ? (sectordata[index].jsonEndAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      )
                    : (sectordata[index].ecuMemMapEndAddress ?? "").padLeft(
                        copyLength * 2,
                        '0',
                      );
                copyArray = hexStringToByteArray(addrHex);
                print("   📍 end_addr[$index]: $addrHex");
              } else if (reference.contains("json_checksum")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                String checkSumHex = (sectordata[index].jsonCheckSum ?? "")
                    .padLeft(copyLength * 2, '0');
                copyArray = hexStringToByteArray(checkSumHex);
                print("   🔢 checksum[$index]: $checkSumHex");
              } else if (reference.contains("json_sector_len") ||
                  reference.contains("ecu_memmap_len")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                int sectorNumBytes;
                if (reference.contains("json_sector_len")) {
                  sectorNumBytes =
                      int.parse(sectordata[index].jsonEndAddress!, radix: 16) -
                      int.parse(
                        sectordata[index].jsonStartAddress!,
                        radix: 16,
                      ) +
                      1;
                } else {
                  sectorNumBytes =
                      int.parse(
                        sectordata[index].ecuMemMapEndAddress!,
                        radix: 16,
                      ) -
                      int.parse(
                        sectordata[index].ecuMemMapStartAddress!,
                        radix: 16,
                      ) +
                      1;
                }
                String hexLen = sectorNumBytes
                    .toRadixString(16)
                    .padLeft(copyLength * 2, '0');
                copyArray = hexStringToByteArray(hexLen);
                print(
                  "   📏 sector_len[$index]: $sectorNumBytes bytes → $hexLen",
                );
              } else if (reference.contains("calculate_sector_len")) {
                int index;
                if (reference.contains("[i]")) {
                  index = loopModelList.last.i ?? 0;
                } else {
                  String match = RegExp(r'\d+').stringMatch(reference) ?? "0";
                  index = int.parse(match);
                  currSectorIndex = index;
                }
                int sectorNumBytes = (sectordata[index].jsonData!.length ~/ 2);
                String hexLen = sectorNumBytes
                    .toRadixString(16)
                    .padLeft(copyLength * 2, '0');
                copyArray = hexStringToByteArray(hexLen);
                print(
                  "   📏 calc_sector_len[$index]: $sectorNumBytes bytes → $hexLen",
                );
              } else if (reference.contains("i")) {
                copyArray = Uint8List.fromList([
                  loopModelList.last.i! + loopInit,
                ]);
                print(
                  "   🔢 loop i value: ${loopModelList.last.i! + loopInit}",
                );
              } else {
                print(
                  "   ⚠️ Unknown reference: '$reference' — copyArray will be empty",
                );
              }

              Uint8List finalBuffer = Uint8List(copyLength);
              int actualToCopy = copyArray.length > copyLength
                  ? copyLength
                  : copyArray.length;
              finalBuffer.setRange(0, actualToCopy, copyArray);
              txFrameList.addAll(finalBuffer);
            }
          }

          Uint8List txFrame = Uint8List.fromList(txFrameList);
          print(
            "📤 send[$command]: ${byteArrayToHex(txFrame)} (${txFrame.length} bytes)",
          );

          var sendResp = await dongleComm!.canTxRx(
            txFrame.length,
            byteArrayToHex(txFrame),
          );
          print("📥 send response: '${sendResp.ecuResponseStatus}'");

          if (command != "sendignore") {
            reprogrammingResponse = sendResp;
          }

          while (reprogrammingResponse.ecuResponseStatus ==
              "ECUERROR_REQUIREDTIMEDELAYNOTEXPIRED") {
            print("⏳ RequiredTimeDelay — retrying in 300ms...");
            await Future.delayed(const Duration(milliseconds: 300));
            reprogrammingResponse = await dongleComm!.canTxRx(
              txFrame.length,
              byteArrayToHex(txFrame),
            );
            print(
              "📥 retry response: '${reprogrammingResponse.ecuResponseStatus}'",
            );
          }

          if (reprogrammingResponse.ecuResponseStatus != "NOERROR" &&
              command != "sendignore") {
            print("❌ send ERROR: '${reprogrammingResponse.ecuResponseStatus}'");
            return reprogrammingResponse.ecuResponseStatus;
          }

          if (command == "sendroutine" || command == "sendroutineignore") {
            String routineReqCommand =
                "3103" + splitData[0].trim().substring(4);
            print("🔁 sendroutine polling: $routineReqCommand");
            bool isRoutineLoop = true;
            while (isRoutineLoop) {
              await Future.delayed(const Duration(milliseconds: 500));
              var routineResp = await dongleComm!.canTxRx(
                routineReqCommand.length ~/ 2,
                routineReqCommand,
              );
              print(
                "📥 routine response: '${routineResp.ecuResponseStatus}' data: ${routineResp.actualDataBytes != null ? byteArrayToHex(routineResp.actualDataBytes!) : 'null'}",
              );

              if (command != "sendroutineignore") {
                reprogrammingResponse = routineResp;
              }

              if (reprogrammingResponse.ecuResponseStatus != "NOERROR" &&
                  command != "sendroutineignore") {
                print(
                  "❌ routine ERROR: '${reprogrammingResponse.ecuResponseStatus}'",
                );
                isRoutineLoop = false;
                return reprogrammingResponse.ecuResponseStatus;
              } else if (routineResp.ecuResponseStatus != "NOERROR" &&
                  command == "sendroutineignore") {
                isRoutineLoop = false;
              } else {
                int statusByte = reprogrammingResponse.actualDataBytes![4];
                print(
                  "   routine statusByte[4]: 0x${statusByte.toRadixString(16).padLeft(2, '0')}",
                );
                if (statusByte == 0x02 ||
                    statusByte == 0x01 ||
                    statusByte == 0x04) {
                  print("   ✅ routine complete");
                  isRoutineLoop = false;
                }
              }
            }
          }
        } else if (command == "sleep") {
          int ms = int.parse(info);
          print("💤 sleep ${ms}ms");
          await Future.delayed(Duration(milliseconds: ms));
        } else if (command == "function") {
          print("⚙️ function: $info");
          if (info.contains("CalculateKeyFromSeed")) {
            var firstSplit = info.split('[');
            var secondSplit = firstSplit[1].split(',');
            String index1Str = secondSplit[0];
            String seedKeyNumBytesStr = secondSplit[1].substring(
              0,
              secondSplit[1].length - 1,
            );

            print("   🔑 index1Str (raw): '$index1Str'");
            print("   🔑 seedKeyNumBytesStr: '$seedKeyNumBytesStr'");

            int seedLen = int.parse(seedKeyNumBytesStr);
            print("   🔑 seedLen: $seedLen");
            print(
              "   🔑 reprogrammingResponse data length: ${reprogrammingResponse.actualDataBytes?.length ?? 'null'}",
            );

            Uint8List seedArray = reprogrammingResponse.actualDataBytes!
                .sublist(2, 2 + seedLen);
            print("   🌱 seed array: ${byteArrayToHex(seedArray)}");

            if (seedArray.every((x) => x == 0)) {
              print("   ⚠️ Seed is all zeros — skipKey=true");
              skipKey = true;
            }

            // In flashInterpreter, replace the SeedKeyIndexType lookup:

            final normalizedIndex = index1Str.replaceAll('-', '_');
            print("   🔑 normalized index: '$normalizedIndex'");
            print(
              "   🔑 Available SeedKeyIndexType values: ${SeedKeyIndexType.values.map((e) => e.toString().split('.').last).toList()}",
            );

            // ✅ FIX: strip underscores + lowercase for camelCase vs SNAKE_CASE matching
            SeedKeyIndexType seedKeyIndex = SeedKeyIndexType.values.firstWhere(
              (e) => e.toString().split('.').last == normalizedIndex,
              orElse: () {
                print(
                  "   ⚠️ No exact match — trying snake_case stripped comparison",
                );

                // e.g. 'KOEL_AUTO_BS4' → 'koelautobs4'  vs  'koelAutoBs4' → 'koelautobs4'
                final strippedInput = normalizedIndex
                    .replaceAll('_', '')
                    .toLowerCase();
                print("   🔑 strippedInput: '$strippedInput'");

                SeedKeyIndexType? match;
                try {
                  match = SeedKeyIndexType.values.firstWhere(
                    (e) =>
                        e.toString().split('.').last.toLowerCase() ==
                        strippedInput,
                  );
                } catch (_) {
                  match = null;
                }

                if (match != null) {
                  print("   ✅ Stripped match found: $match");
                  return match;
                }

                print(
                  "   ❌ No match at all — falling back to first: ${SeedKeyIndexType.values.first}",
                );
                print(
                  "   📋 Available values: ${SeedKeyIndexType.values.map((e) => e.toString().split('.').last).toList()}",
                );
                return SeedKeyIndexType.values.first;
              },
            );
            print("   ✅ seedKeyIndex resolved: $seedKeyIndex");
            print("   ✅ seedKeyIndex resolved: $seedKeyIndex");
            print("   ✅ seedKeyIndex resolved: $seedKeyIndex");

            List<int> keyOutput = [];
            await calculateSeedkey!.calculateSeedkey(
              index: seedKeyIndex,
              seed: seedArray,
              keyOutput: keyOutput,
            );
            seedKey = Uint8List.fromList(keyOutput);
            print(
              "   🗝 calculated key: ${byteArrayToHex(seedKey)} (${seedKey.length} bytes)",
            );
          }
        } else if (command == "repeatstart") {
          isLoopPresent = true;
          List<String> sData = info.split(',');
          int maxIdx = sData[3] == "noofsectors"
              ? noofsectors
              : int.parse(sData[3]);
          loopInit = int.parse(sData[2]);
          loopModelList.add(
            LoopModel(
              i: 0,
              loopId: int.parse(sData[0]),
              maxIndex: maxIdx,
              loopLocation: i,
            ),
          );
          print(
            "🔁 repeatstart — loopId=${sData[0]} maxIdx=$maxIdx loopInit=$loopInit",
          );
        } else if (command == "repeatend") {
          loopModelList.last.i = (loopModelList.last.i ?? 0) + 1;
          print(
            "🔁 repeatend — i=${loopModelList.last.i} / maxIndex=${loopModelList.last.maxIndex}",
          );
          if (loopModelList.last.i == loopModelList.last.maxIndex) {
            print("✅ Loop complete — removing from stack");
            loopModelList.removeLast();
          } else {
            i = loopModelList.last.loopLocation ?? 0;
            print("↩️ Loop back to line $i");
          }
        } else if (command == "sendbulkdata") {
          // 1. Parse Initial Configuration
          List<String> sInfo = info.split(',');
          int blkSeqCnt = int.parse(sInfo[1]);
          String transferInfo = sInfo[2];

          // 2. Fragmenting Strategy: Avoid OS Buffer Overflow
          // Windows COM buffers often choke above 2KB; 1024 is the safe "sweet spot."
          const int safeChunkSize = 2870;

          int idx = isLoopPresent ? loopModelList.last.i ?? 0 : currSectorIndex;
          Uint8List sectorDataArray = hexStringToByteArray(
            sectordata[idx].jsonData ?? "",
          );

          // 3. Address and Size Calculation
          int sectorStartAddr = int.parse(
            sectordata[idx].jsonStartAddress!,
            radix: 16,
          );
          int totalSectorSize =
              int.parse(sectordata[idx].jsonEndAddress!, radix: 16) -
              sectorStartAddr +
              1;

          int offset = 0;
          List<String> tSplitData = transferInfo.split('+');

          // 4. Fragmented Transfer Loop
          while (offset < totalSectorSize) {
            int currentChunkLen = (totalSectorSize - offset) < safeChunkSize
                ? (totalSectorSize - offset)
                : safeChunkSize;

            final builder = BytesBuilder(copy: false);

            // 5. Build the Transfer Frame
            for (var item in tSplitData) {
              String part = item.trim();
              if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(part)) {
                // Static Hex Header
                builder.add(hexStringToByteArray(part));
              } else if (part.contains("bsc")) {
                // Block Sequence Counter (0x00 - 0xFF)
                builder.addByte(blkSeqCnt & 0xFF);
              } else if (part.contains("json_sectordata")) {
                // The Data Fragment
                builder.add(
                  Uint8List.sublistView(
                    sectorDataArray,
                    offset,
                    offset + currentChunkLen,
                  ),
                );
              } else if (part.contains("json_strt_addr")) {
                // Dynamic Start Address for this specific chunk
                final bd = ByteData(4)
                  ..setUint32(0, sectorStartAddr, Endian.big);
                builder.add(bd.buffer.asUint8List());
              }
            }

            Uint8List finalFrame = builder.takeBytes();

            // 6. Transmission
            // canTxRx handles the request-response cycle for the chunk
            var bulkResp = await dongleComm!.canTxRx(
              finalFrame.length,
              byteArrayToHex(finalFrame),
            );

            if (bulkResp.ecuResponseStatus != "NOERROR") {
              return "BULK_ERR: ${bulkResp.ecuResponseStatus}";
            }

            // 7. Update Pointers and Counters
            offset += currentChunkLen;
            sectorStartAddr +=
                currentChunkLen; // Increment address for the next chunk
            blkSeqCnt = (blkSeqCnt + 1) & 0xFF; // Wrap at 255
            realTimeBytesFlashed += currentChunkLen;

            // 8. Driver "Breathing" Delay
            // Essential for Windows to clear the physical UART buffer
            await Future.delayed(const Duration(milliseconds: 1));
          }
        } else if (command == "txid") {
          print("🔧 txid: $info");
          await dongleComm!.canSetTxHeader(info);
        } else if (command == "rxid") {
          print("🔧 rxid: $info");
          await dongleComm!.canSetRxHeaderMask(info);
        } else if (command == "startpadding") {
          print("🔧 startpadding: $info");
          await dongleComm!.canStartPadding(info);
        } else if (command == "stoppadding") {
          print("🔧 stoppadding");
          await dongleComm!.canStopPadding();
        } else if (command == "setstmin") {
          print("🔧 setstmin: $info");
          await dongleComm!.canSetP1Min(info.trim());
        } else if (command == "setP2Max") {
          print("🔧 setP2Max: $info");
          await dongleComm!.canSetP2Max(info.trim());
        } else if (command == "stopTP") {
          print("🔧 stopTP");
          await dongleComm!.canStopTP();
        } else if (command == "startTP") {
          print("🔧 startTP");
          await dongleComm!.canStartTP();
        } else {
          print("⚠️ Unknown command '$command' — skipping");
        }
      }

      print(
        "🏁 flashInterpreter END — final status: '${reprogrammingResponse.ecuResponseStatus}'",
      );
    } catch (ex, stack) {
      print("❌ flashInterpreter EXCEPTION: $ex");
      print("❌ StackTrace: $stack");
      return ex.toString();
    }

    return reprogrammingResponse.ecuResponseStatus;
  }

  Future<ResponseArrayStatus> setDataData(String command) async {
    // ~/ is the integer division operator in Dart
    // It replaces (int)(command.Length / 2) from C#
    int frameLength = command.length ~/ 2;

    // Await the asynchronous CAN transmission
    ResponseArrayStatus pidResponse = await dongleComm!.canTxRx(
      frameLength,
      command,
    );

    return pidResponse;
  }
}
