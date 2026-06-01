class ReadParameterResponse {
  int? pidId;
  String? pidName;
  String? status;
  List<int>? dataArray; // byte[] -> List<int> in Dart
  List<ReadParameterVariableResponse>? variables;

  ReadParameterResponse({
    this.pidId,
    this.pidName,
    this.status,
    this.dataArray,
    this.variables,
  });

  factory ReadParameterResponse.fromJson(Map<String, dynamic> json) {
    return ReadParameterResponse(
      pidId: json['pid_id'],
      pidName: json['pid_name'],
      status: json['Status'],
      dataArray: json['DataArray'] != null
          ? List<int>.from(json['DataArray'])
          : null,
      variables: json['Variables'] != null
          ? (json['Variables'] as List)
              .map((e) => ReadParameterVariableResponse.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pid_id': pidId,
      'pid_name': pidName,
      'Status': status,
      'DataArray': dataArray,
      'Variables': variables?.map((e) => e.toJson()).toList(),
    };
  }
}

class ReadParameterVariableResponse {
  int? pidNumber;
  String? pidName;
  String? responseValue;

  ReadParameterVariableResponse({
    this.pidNumber,
    this.pidName,
    this.responseValue,
  });

  factory ReadParameterVariableResponse.fromJson(Map<String, dynamic> json) {
    return ReadParameterVariableResponse(
      pidNumber: json['pidNumber'],
      pidName: json['pidName'],
      responseValue: json['responseValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pidNumber': pidNumber,
      'pidName': pidName,
      'responseValue': responseValue,
    };
  }
}

class ReadParameterResponseIvn {
  String? status;
  String? pidName;
  String? responseValue;
  String? unit;

  ReadParameterResponseIvn({
    this.status,
    this.pidName,
    this.responseValue,
    this.unit,
  });

  factory ReadParameterResponseIvn.fromJson(Map<String, dynamic> json) {
    return ReadParameterResponseIvn(
      status: json['Status'],
      pidName: json['pidName'],
      responseValue: json['responseValue'],
      unit: json['Unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Status': status,
      'pidName': pidName,
      'responseValue': responseValue,
      'Unit': unit,
    };
  }
}