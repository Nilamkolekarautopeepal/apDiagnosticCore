class ReadParameterPID {
  int? pidId;
  String? pid;
  int? totalLen;
  List<PidVariable>? variables;
  int? priority;

  ReadParameterPID({
    this.pidId,
    this.pid,
    this.totalLen,
    this.variables,
    this.priority,
  });

  factory ReadParameterPID.fromJson(Map<String, dynamic> json) {
    return ReadParameterPID(
      pidId: json['pid_id'],
      pid: json['pid'],
      totalLen: json['totalLen'],
      priority: json['priority'],
      variables: json['variables'] != null
          ? (json['variables'] as List)
              .map((e) => PidVariable.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid_id': pidId,
      'pid': pid,
      'totalLen': totalLen,
      'priority': priority,
      'variables': variables?.map((e) => e.toJson()).toList(),
    };
  }
}

class PidVariable {
  int? totalBytes;
  int? startByte;
  int? noOfBytes;
  bool? isBitcoded;
  int? startBit;
  int? noofBits;
  String? datatype;
  double? resolution;
  double? offset;
  int? pidNumber;
  String? pidName;
  String? numType;
  int? readParameterIndex;
  List<SelectedParameterMessage>? messages;

  PidVariable({
    this.totalBytes,
    this.startByte,
    this.noOfBytes,
    this.isBitcoded,
    this.startBit,
    this.noofBits,
    this.datatype,
    this.resolution,
    this.offset,
    this.pidNumber,
    this.pidName,
    this.numType,
    this.readParameterIndex,
    this.messages,
  });

  factory PidVariable.fromJson(Map<String, dynamic> json) {
    return PidVariable(
      totalBytes: json['totalBytes'],
      startByte: json['startByte'],
      noOfBytes: json['noOfBytes'],
      isBitcoded: json['IsBitcoded'],
      startBit: json['startBit'],
      noofBits: json['noofBits'],
      datatype: json['datatype'],
      resolution: (json['resolution'] as num?)?.toDouble(),
      offset: (json['offset'] as num?)?.toDouble(),
      pidNumber: json['pidNumber'],
      pidName: json['pidName'],
      numType: json['num_type'],
      readParameterIndex: json['readParameterIndex'],
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((e) => SelectedParameterMessage.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBytes': totalBytes,
      'startByte': startByte,
      'noOfBytes': noOfBytes,
      'IsBitcoded': isBitcoded,
      'startBit': startBit,
      'noofBits': noofBits,
      'datatype': datatype,
      'resolution': resolution,
      'offset': offset,
      'pidNumber': pidNumber,
      'pidName': pidName,
      'num_type': numType,
      'readParameterIndex': readParameterIndex,
      'messages': messages?.map((e) => e.toJson()).toList(),
    };
  }
}

class SelectedParameterMessage {
  String? code;
  String? message;

  SelectedParameterMessage({
    this.code,
    this.message,
  });

  factory SelectedParameterMessage.fromJson(Map<String, dynamic> json) {
    return SelectedParameterMessage(
      code: json['code'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
    };
  }
}

class PIDFrameId {
  String? framId;
  String? pidDescription;
  String? startByte;
  String? byte;
  String? bitCoded;
  String? startBit;
  String? noOfBits;
  String? resolution;
  String? offset;
  String? unit;
  dynamic messageType;
  List<FrameOfPidMessage>? frameOfPidMessage;
  String? endian;
  String? numType;

  PIDFrameId({
    this.framId,
    this.pidDescription,
    this.startByte,
    this.byte,
    this.bitCoded,
    this.startBit,
    this.noOfBits,
    this.resolution,
    this.offset,
    this.unit,
    this.messageType,
    this.frameOfPidMessage,
    this.endian,
    this.numType,
  });

  factory PIDFrameId.fromJson(Map<String, dynamic> json) {
    return PIDFrameId(
      framId: json['FramID'],
      pidDescription: json['pid_description'],
      startByte: json['start_byte'],
      byte: json['byte'],
      bitCoded: json['bit_coded'],
      startBit: json['start_bit'],
      noOfBits: json['no_of_bits'],
      resolution: json['resolution'],
      offset: json['offset'],
      unit: json['unit'],
      messageType: json['message_type'],
      endian: json['endian'],
      numType: json['num_type'],
      frameOfPidMessage: json['frame_of_pid_message'] != null
          ? (json['frame_of_pid_message'] as List)
              .map((e) => FrameOfPidMessage.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'FramID': framId,
      'pid_description': pidDescription,
      'start_byte': startByte,
      'byte': byte,
      'bit_coded': bitCoded,
      'start_bit': startBit,
      'no_of_bits': noOfBits,
      'resolution': resolution,
      'offset': offset,
      'unit': unit,
      'message_type': messageType,
      'endian': endian,
      'num_type': numType,
      'frame_of_pid_message': frameOfPidMessage?.map((e) => e.toJson()).toList(),
    };
  }
}

class FrameOfPidMessage {
  String? code;
  String? message;

  FrameOfPidMessage({
    this.code,
    this.message,
  });

  factory FrameOfPidMessage.fromJson(Map<String, dynamic> json) {
    return FrameOfPidMessage(
      code: json['code'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
    };
  }
}

class IVNSelectedPID {
  String? frameId;
  List<PIDFrameId>? frameIds;

  IVNSelectedPID({
    this.frameId,
    this.frameIds,
  });

  factory IVNSelectedPID.fromJson(Map<String, dynamic> json) {
    return IVNSelectedPID(
      frameId: json['frame_id'],
      frameIds: json['frame_ids'] != null
          ? (json['frame_ids'] as List)
              .map((e) => PIDFrameId.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frame_id': frameId,
      'frame_ids': frameIds?.map((e) => e.toJson()).toList(),
    };
  }
}