class FlashCurtisModel {
  String? type;
  int? noOfSectors;
  List<SectorData1>? sectorData;

  FlashCurtisModel({
    this.type,
    this.noOfSectors,
    this.sectorData,
  });

  factory FlashCurtisModel.fromJson(Map<String, dynamic> json) {
    return FlashCurtisModel(
      type: json['Type'],
      noOfSectors: json['NoOfSectors'],
      sectorData: json['SectorData'] != null
          ? (json['SectorData'] as List)
              .map((e) => SectorData1.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Type': type,
      'NoOfSectors': noOfSectors,
      'SectorData': sectorData?.map((e) => e.toJson()).toList(),
    };
  }
}

class SectorData1 {
  String? sectorLength;
  String? jsonData;

  SectorData1({
    this.sectorLength,
    this.jsonData,
  });

  factory SectorData1.fromJson(Map<String, dynamic> json) {
    return SectorData1(
      sectorLength: json['SectorLength'],
      jsonData: json['JsonData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SectorLength': sectorLength,
      'JsonData': jsonData,
    };
  }
}