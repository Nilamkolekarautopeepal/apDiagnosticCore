// class WriteParameterPID {
//   int? writePamIndex; // enum -> int (or replace with Dart enum later)
//   int? seedKeyIndex;  // enum -> int
//   String? ioCtrlPid;
//   String? writePid;
//   int? writeInputSize;

//   int? writeParaNo;
//   int? writeParaName;

//   List<int>? writeInput; // byte[] -> List<int>

//   String? readParameterPidDataType;
//   String? pid;

//   int? totalLen;
//   int? totalBytes;
//   int? startByte;
//   int? noOfBytes;

//   bool? isBitcoded;
//   int? startBit;
//   int? noofBits;

//   String? datatype;
//   double? resolution;
//   double? offset;
//   String? unit;
//   String? pidName;

//   List<VariantDataList>? variantList;

//   WriteParameterPID({
//     this.writePamIndex,
//     this.seedKeyIndex,
//     this.ioCtrlPid,
//     this.writePid,
//     this.writeInputSize,
//     this.writeParaNo,
//     this.writeParaName,
//     this.writeInput,
//     this.readParameterPidDataType,
//     this.pid,
//     this.totalLen,
//     this.totalBytes,
//     this.startByte,
//     this.noOfBytes,
//     this.isBitcoded,
//     this.startBit,
//     this.noofBits,
//     this.datatype,
//     this.resolution,
//     this.offset,
//     this.unit,
//     this.pidName,
//     this.variantList,
//   });

//   factory WriteParameterPID.fromJson(Map<String, dynamic> json) {
//     return WriteParameterPID(
//       writePamIndex: json['writepamindex'],
//       seedKeyIndex: json['seedkeyindex'],
//       ioCtrlPid: json['io_ctrl_pid'],
//       writePid: json['write_pid'],
//       writeInputSize: json['writeinput_size'],
//       writeParaNo: json['writeparano'],
//       writeParaName: json['writeparaName'],
//       writeInput: json['writeinput'] != null
//           ? List<int>.from(json['writeinput'])
//           : null,
//       readParameterPidDataType: json['ReadParameterPID_DataType'],
//       pid: json['pid'],
//       totalLen: json['totalLen'],
//       totalBytes: json['totalBytes'],
//       startByte: json['startByte'],
//       noOfBytes: json['noOfBytes'],
//       isBitcoded: json['IsBitcoded'],
//       startBit: json['startBit'],
//       noofBits: json['noofBits'],
//       datatype: json['datatype'],
//       resolution: (json['resolution'] as num?)?.toDouble(),
//       offset: (json['offset'] as num?)?.toDouble(),
//       unit: json['unit'],
//       pidName: json['pidName'],
//       variantList: json['variantList'] != null
//           ? (json['variantList'] as List)
//               .map((e) => VariantDataList.fromJson(e))
//               .toList()
//           : null,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'writepamindex': writePamIndex,
//       'seedkeyindex': seedKeyIndex,
//       'io_ctrl_pid': ioCtrlPid,
//       'write_pid': writePid,
//       'writeinput_size': writeInputSize,
//       'writeparano': writeParaNo,
//       'writeparaName': writeParaName,
//       'writeinput': writeInput,
//       'ReadParameterPID_DataType': readParameterPidDataType,
//       'pid': pid,
//       'totalLen': totalLen,
//       'totalBytes': totalBytes,
//       'startByte': startByte,
//       'noOfBytes': noOfBytes,
//       'IsBitcoded': isBitcoded,
//       'startBit': startBit,
//       'noofBits': noofBits,
//       'datatype': datatype,
//       'resolution': resolution,
//       'offset': offset,
//       'unit': unit,
//       'pidName': pidName,
//       'variantList': variantList?.map((e) => e.toJson()).toList(),
//     };
//   }
// }


import 'dart:typed_data';

import 'package:ap_dongle_diagnostic_core/enums/writeParameterIndex.dart';
import 'package:ecu_seedkeypcl_core/ecu_seedkeypcl_core.dart';

class WriteParameterPID {
  WriteParameterIndex? writePamIndex;
  SeedKeyIndexType? seedKeyIndex;
  String? ioCtrlPid;
  String? writePid;
  int? writeInputSize;
  int? writeParaNo;
  int? writeParaName;
  Uint8List? writeInput;
  String? readParameterPidDataType;
  String? pid;
  int? totalLen;
  int? totalBytes;
  int? startByte;
  int? noOfBytes;
  bool? isBitcoded;
  int? startBit;
  int? noofBits;
  String? datatype;
  double? resolution;
  double? offset;
  String? unit;
  String? pidName;
  List<VariantDataList>? variantList;

 

  WriteParameterPID({
    this.writePamIndex,
    this.seedKeyIndex,
    this.ioCtrlPid,
    this.writePid,
    this.writeInputSize,
    this.writeParaNo,
    this.writeParaName,
    this.writeInput,
    this.readParameterPidDataType,
    this.pid,
    this.totalLen,
    this.totalBytes,
    this.startByte,
    this.noOfBytes,
    this.isBitcoded,
    this.startBit,
    this.noofBits,
    this.datatype,
    this.resolution,
    this.offset,
    this.unit,
    this.pidName,
    this.variantList,
  });

  factory WriteParameterPID.fromJson(Map<String, dynamic> json) {
    return WriteParameterPID(
      // Handling Enum parsing from String if necessary
     writePamIndex: json['writepamindex'] != null
    ? WriteParameterIndex.values.firstWhere(
        (e) => e.name == json['writepamindex'],
        orElse: () => WriteParameterIndex.values.first,
      )
    : null,
      seedKeyIndex: json['seedkeyindex'] != null
    ? SeedKeyIndexType.values.firstWhere(
        (e) => e.name == json['seedkeyindex'],
        orElse: () => SeedKeyIndexType.values.first,
      )
    : null,
      ioCtrlPid: json['io_ctrl_pid'],
      writePid: json['write_pid'],
      writeInputSize: json['writeinput_size'],
      writeParaNo: json['writeparano'],
      writeParaName: json['writeparaName'],
      // Converting List<int> from JSON to Uint8List
      writeInput: json['writeinput'] != null 
          ? Uint8List.fromList(List<int>.from(json['writeinput'])) 
          : null,
      readParameterPidDataType: json['ReadParameterPID_DataType'],
      pid: json['pid'],
      totalLen: json['totalLen'],
      totalBytes: json['totalBytes'],
      startByte: json['startByte'],
      noOfBytes: json['noOfBytes'],
      isBitcoded: json['IsBitcoded'],
      startBit: json['startBit'],
      noofBits: json['noofBits'],
      datatype: json['datatype'],
      resolution: json['resolution']?.toDouble(),
      offset: json['offset']?.toDouble(),
      unit: json['unit'],
      pidName: json['pidName'],
      variantList: json['variantList'] != null
          ? (json['variantList'] as List)
              .map((i) => VariantDataList.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'writepamindex': writePamIndex?.toString().split('.').last,
      'seedkeyindex': seedKeyIndex?.toString().split('.').last,
      'io_ctrl_pid': ioCtrlPid,
      'write_pid': writePid,
      'writeinput_size': writeInputSize,
      'writeparano': writeParaNo,
      'writeparaName': writeParaName,
      'writeinput': writeInput?.toList(),
      'ReadParameterPID_DataType': readParameterPidDataType,
      'pid': pid,
      'totalLen': totalLen,
      'totalBytes': totalBytes,
      'startByte': startByte,
      'noOfBytes': noOfBytes,
      'IsBitcoded': isBitcoded,
      'startBit': startBit,
      'noofBits': noofBits,
      'datatype': datatype,
      'resolution': resolution,
      'offset': offset,
      'unit': unit,
      'pidName': pidName,
      'variantList': variantList?.map((v) => v.toJson()).toList(),
    };
  }
}

// class VariantDataList {
//   int? pidId;
//   String? pidName;

//   int? startByte;
//   int? noOfBytes;

//   bool? isBitcoded;
//   int? startBit;
//   int? noofBits;

//   String? datatype;
//   double? resolution;
//   double? offset;
//   String? unit;

//   VariantDataList({
//     this.pidId,
//     this.pidName,
//     this.startByte,
//     this.noOfBytes,
//     this.isBitcoded,
//     this.startBit,
//     this.noofBits,
//     this.datatype,
//     this.resolution,
//     this.offset,
//     this.unit,
//   });

//   factory VariantDataList.fromJson(Map<String, dynamic> json) {
//     return VariantDataList(
//       pidId: json['pid_id'],
//       pidName: json['pid_name'],
//       startByte: json['startByte'],
//       noOfBytes: json['noOfBytes'],
//       isBitcoded: json['IsBitcoded'],
//       startBit: json['startBit'],
//       noofBits: json['noofBits'],
//       datatype: json['datatype'],
//       resolution: (json['resolution'] as num?)?.toDouble(),
//       offset: (json['offset'] as num?)?.toDouble(),
//       unit: json['unit'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'pid_id': pidId,
//       'pid_name': pidName,
//       'startByte': startByte,
//       'noOfBytes': noOfBytes,
//       'IsBitcoded': isBitcoded,
//       'startBit': startBit,
//       'noofBits': noofBits,
//       'datatype': datatype,
//       'resolution': resolution,
//       'offset': offset,
//       'unit': unit,
//     };
//   }
// }

class VariantDataList {
  int? pidId;
  String? pidName;
  int? startByte;
  int? noOfBytes;
  bool? isBitcoded;
  int? startBit;
  int? noofBits;
  String? datatype;
  double? resolution;
  double? offset;
  String? unit;
  String? beforeValue;

  VariantDataList({
    this.pidId,
    this.pidName,
    this.startByte,
    this.noOfBytes,
    this.isBitcoded,
    this.startBit,
    this.noofBits,
    this.datatype,
    this.resolution,
    this.offset,
    this.unit,
    this.beforeValue,
  });

  factory VariantDataList.fromJson(Map<String, dynamic> json) {
    return VariantDataList(
      pidId: json['pid_id'],
      pidName: json['pid_name'],
      startByte: json['startByte'],
      noOfBytes: json['noOfBytes'],
      isBitcoded: json['IsBitcoded'],
      startBit: json['startBit'],
      noofBits: json['noofBits'],
      datatype: json['datatype'],
      resolution: json['resolution'] != null
          ? (json['resolution'] as num).toDouble()
          : null,
      offset: json['offset'] != null
          ? (json['offset'] as num).toDouble()
          : null,
      unit: json['unit'],
      beforeValue: json['beforeValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid_id': pidId,
      'pid_name': pidName,
      'startByte': startByte,
      'noOfBytes': noOfBytes,
      'IsBitcoded': isBitcoded,
      'startBit': startBit,
      'noofBits': noofBits,
      'datatype': datatype,
      'resolution': resolution,
      'offset': offset,
      'unit': unit,
      'beforeValue': beforeValue,
    };
  }
}