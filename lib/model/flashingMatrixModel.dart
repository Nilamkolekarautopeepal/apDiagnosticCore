class FlashingMatrix {
  String? jsonStartAddress;
  String? jsonEndAddress;
  String? jsonData;

  String? ecuMemMapStartAddress;
  String? ecuMemMapEndAddress;

  String? jsonCheckSum;

  FlashingMatrix({
    this.jsonStartAddress,
    this.jsonEndAddress,
    this.jsonData,
    this.ecuMemMapStartAddress,
    this.ecuMemMapEndAddress,
    this.jsonCheckSum,
  });

  factory FlashingMatrix.fromJson(Map<String, dynamic> json) {
    return FlashingMatrix(
      jsonStartAddress: json['JsonStartAddress'],
      jsonEndAddress: json['JsonEndAddress'],
      jsonData: json['JsonData'],
      ecuMemMapStartAddress: json['ECUMemMapStartAddress'],
      ecuMemMapEndAddress: json['ECUMemMapEndAddress'],
      jsonCheckSum: json['JsonCheckSum'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'JsonStartAddress': jsonStartAddress,
      'JsonEndAddress': jsonEndAddress,
      'JsonData': jsonData,
      'ECUMemMapStartAddress': ecuMemMapStartAddress,
      'ECUMemMapEndAddress': ecuMemMapEndAddress,
      'JsonCheckSum': jsonCheckSum,
    };
  }
}

class FlashingMatrixData {
  int? noOfSectors;
  List<FlashingMatrix>? sectorData;

  FlashingMatrixData({
    this.noOfSectors,
    this.sectorData,
  });

  factory FlashingMatrixData.fromJson(Map<String, dynamic> json) {
    return FlashingMatrixData(
      noOfSectors: json['NoOfSectors'],
      sectorData: json['SectorData'] != null
          ? (json['SectorData'] as List)
              .map((e) => FlashingMatrix.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'NoOfSectors': noOfSectors,
      'SectorData': sectorData?.map((e) => e.toJson()).toList(),
    };
  }
}