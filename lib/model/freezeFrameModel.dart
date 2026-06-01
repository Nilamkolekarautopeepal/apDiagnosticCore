class FreezeFrameModel {
  int? id;
  String? ffSet;
  bool? isActive;
  List<FreezeFrameCode>? freezeFrameCode;

  FreezeFrameModel({
    this.id,
    this.ffSet,
    this.isActive,
    this.freezeFrameCode,
  });

  factory FreezeFrameModel.fromJson(Map<String, dynamic> json) {
    return FreezeFrameModel(
      id: json['id'],
      ffSet: json['ff_set'],
      isActive: json['is_active'],
      freezeFrameCode: json['freeze_frame_code'] != null
          ? (json['freeze_frame_code'] as List)
              .map((e) => FreezeFrameCode.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ff_set': ffSet,
      'is_active': isActive,
      'freeze_frame_code': freezeFrameCode?.map((e) => e.toJson()).toList(),
    };
  }
}

class FreezeFrameCode {
  int? id;
  String? code;
  String? desc;
  int? bytePosition;
  int? length;
  int? priority;
  bool? bitcoded;
  int? noofBits;
  int? startBit;
  int? startBitPosition;
  int? endBitPosition;
  double? resolution;
  double? offset;
  String? messageType;
  String? unit;
  String? endian;
  String? numType;
  List<FFMessage>? freezeFrameMessages;

  FreezeFrameCode({
    this.id,
    this.code,
    this.desc,
    this.bytePosition,
    this.length,
    this.priority,
    this.bitcoded,
    this.noofBits,
    this.startBit,
    this.startBitPosition,
    this.endBitPosition,
    this.resolution,
    this.offset,
    this.messageType,
    this.unit,
    this.endian,
    this.numType,
    this.freezeFrameMessages,
  });

  factory FreezeFrameCode.fromJson(Map<String, dynamic> json) {
    return FreezeFrameCode(
      id: json['id'],
      code: json['code'],
      desc: json['desc'],
      bytePosition: json['byte_position'],
      length: json['length'],
      priority: json['priority'],
      bitcoded: json['bitcoded'],
      noofBits: json['noofBits'],
      startBit: json['startBit'],
      startBitPosition: json['start_bit_position'],
      endBitPosition: json['end_bit_position'],
      resolution: (json['resolution'] as num?)?.toDouble(),
      offset: (json['offset'] as num?)?.toDouble(),
      messageType: json['message_type'],
      unit: json['unit'],
      endian: json['endian'],
      numType: json['num_type'],
      freezeFrameMessages: json['freezframe_messages'] != null
          ? (json['freezframe_messages'] as List)
              .map((e) => FFMessage.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'desc': desc,
      'byte_position': bytePosition,
      'length': length,
      'priority': priority,
      'bitcoded': bitcoded,
      'noofBits': noofBits,
      'startBit': startBit,
      'start_bit_position': startBitPosition,
      'end_bit_position': endBitPosition,
      'resolution': resolution,
      'offset': offset,
      'message_type': messageType,
      'unit': unit,
      'endian': endian,
      'num_type': numType,
      'freezframe_messages': freezeFrameMessages?.map((e) => e.toJson()).toList(),
    };
  }
}

class FFMessage {
  String? code;
  String? message;

  FFMessage({
    this.code,
    this.message,
  });

  factory FFMessage.fromJson(Map<String, dynamic> json) {
    return FFMessage(
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

class FreezeFrameResponseModel {
  String? status;
  List<FreezeFrame>? dtcs;
  int? noofdtc;

  FreezeFrameResponseModel({
    this.status,
    this.dtcs,
    this.noofdtc,
  });

  factory FreezeFrameResponseModel.fromJson(Map<String, dynamic> json) {
    return FreezeFrameResponseModel(
      status: json['status'],
      noofdtc: json['noofdtc'],
      dtcs: json['dtcs'] != null
          ? (json['dtcs'] as List)
              .map((e) => FreezeFrame.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'noofdtc': noofdtc,
      'dtcs': dtcs?.map((e) => e.toJson()).toList(),
    };
  }
}

class FreezeFrame {
  String? code;
  int? priority;
  String? value;

  FreezeFrame({
    this.code,
    this.priority,
    this.value,
  });

  factory FreezeFrame.fromJson(Map<String, dynamic> json) {
    return FreezeFrame(
      code: json['code'],
      priority: json['priority'],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'priority': priority,
      'value': value,
    };
  }
}