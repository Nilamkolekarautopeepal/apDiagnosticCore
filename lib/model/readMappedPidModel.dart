class ReadMappedPID {
  int? id;
  String? name;
  String? pidCode;
  int? totalLen;
  int? length;
  String? unit;
  double? resolution;
  double? offset;
  String? numType;

  ReadMappedPID({
    this.id,
    this.name,
    this.pidCode,
    this.totalLen,
    this.length,
    this.unit,
    this.resolution,
    this.offset,
    this.numType,
  });

  factory ReadMappedPID.fromJson(Map<String, dynamic> json) {
    return ReadMappedPID(
      id: json['id'],
      name: json['name'],
      pidCode: json['pid_code'],
      totalLen: json['total_len'],
      length: json['length'],
      unit: json['unit'],
      resolution: (json['resolution'] as num?)?.toDouble(),
      offset: (json['offset'] as num?)?.toDouble(),
      numType: json['num_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pid_code': pidCode,
      'total_len': totalLen,
      'length': length,
      'unit': unit,
      'resolution': resolution,
      'offset': offset,
      'num_type': numType,
    };
  }
}

class MappedPIDResponse {
  int? id;
  String? name;
  String? pidCode;
  String? unit;
  String? status;
  List<String>? values;

  MappedPIDResponse({
    this.id,
    this.name,
    this.pidCode,
    this.unit,
    this.status,
    this.values,
  });

  factory MappedPIDResponse.fromJson(Map<String, dynamic> json) {
    return MappedPIDResponse(
      id: json['id'],
      name: json['name'],
      pidCode: json['pid_code'],
      unit: json['unit'],
      status: json['status'],
      values: json['values'] != null
          ? List<String>.from(json['values'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pid_code': pidCode,
      'unit': unit,
      'status': status,
      'values': values,
    };
  }
}