class WriteParameterResponse {
  String? status;
  List<int>? dataArray; // byte[] -> List<int> in Dart
  int? pidNumber;
  String? pidName;
  String? responseValue;

  WriteParameterResponse({
    this.status,
    this.dataArray,
    this.pidNumber,
    this.pidName,
    this.responseValue,
  });

  factory WriteParameterResponse.fromJson(Map<String, dynamic> json) {
    return WriteParameterResponse(
      status: json['Status'],
      dataArray: json['DataArray'] != null
          ? List<int>.from(json['DataArray'])
          : null,
      pidNumber: json['pidNumber'],
      pidName: json['pidName'],
      responseValue: json['responseValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Status': status,
      'DataArray': dataArray,
      'pidNumber': pidNumber,
      'pidName': pidName,
      'responseValue': responseValue,
    };
  }
}

class WriteParameterResponseStatus {
  String? status;

  WriteParameterResponseStatus({
    this.status,
  });

  factory WriteParameterResponseStatus.fromJson(Map<String, dynamic> json) {
    return WriteParameterResponseStatus(
      status: json['Status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Status': status,
    };
  }
}