class ApReadDtcResponseModel {
  String? status;
  List<List<String>>? dtcs;
  int? noOfDtc;

  ApReadDtcResponseModel({
    this.status,
    this.dtcs,
    this.noOfDtc,
  });

  factory ApReadDtcResponseModel.fromJson(Map<String, dynamic> json) {
    return ApReadDtcResponseModel(
      status: json['status'],
      noOfDtc: json['noofdtc'],
      dtcs: json['dtcs'] != null
          ? (json['dtcs'] as List)
              .map((e) => (e as List).map((i) => i.toString()).toList())
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'noofdtc': noOfDtc,
      'dtcs': dtcs,
    };
  }
}