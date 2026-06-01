// enum SeedKeyIndexType {

//   greavesAdvantekBs6A46(0), // Defaulting to 0 if not specified in C#
//   sanitasBoschBs6Prod(1),
//   sanitasAdvantekBs6Prod(2),
//   sanitasAdvantekBs4Prod(3),
//   koelBoschBs4(4),
//   flashKoelBoschF6Cpcb4(5),
//   sanitasAdvantekBs6A46(6),
//   seedkeyalgoVecvBoschBs6(7),
//   seedkeyalgoVecvDelphiBs6(8),
//   seedkeyalgoVecvAmtBs6(9),
//   seedkeyalgoBoschCv54(10),
//   seedkeyalgoVecvDelphiTcic(11),
//   greavesBoschBs6Prod(2), // Note: C# allows duplicate values; Dart logic might need unique names
//   atulAdvantekBs6A46(4),
//   tvsAdvantekBs6A46(5),
//   greavesSedemacBlBs6(7),
//   greavesSedemacAppBs6(8),
//   greavesSedemacBs6(9),
//   seedkeyalgoVecvBoschBs6_01(11),
//   koelAutoBs4(12),
//   koelCpcb4LowHpEcu(13),
//   koelCpcb4HighHpEcu(14),
//   koelCpcb4MidHpEcu(15),
//   koelNiraSeedkeyalgo(16),
//   koelGcuSeedkeyalgo(17),
//   tataDnox(31);
  

//   final int value;
//   const SeedKeyIndexType(this.value);

//   /// Helper to find the enum by its integer value (useful for raw ECU data)
//   static SeedKeyIndexType? fromValue(int val) {
//     for (var type in SeedKeyIndexType.values) {
//       if (type.value == val) return type;
//     }
//     return null;
//   }
// }

enum SeedKeyIndexType {

  greavesAdvantekBs6A46(0),
  sanitasBoschBs6Prod(1),
  sanitasAdvantekBs6Prod(2),
  sanitasAdvantekBs4Prod(3),
  koelBoschBs4(4),
  flashKoelBoschF6Cpcb4(5),
  sanitasAdvantekBs6A46(6),
  seedkeyalgoVecvBoschBs6(7),
  seedkeyalgoVecvDelphiBs6(8),
  seedkeyalgoVecvAmtBs6(9),
  seedkeyalgoBoschCv54(10),
  seedkeyalgoVecvDelphiTcic(11),
  greavesBoschBs6Prod(2),
  atulAdvantekBs6A46(4),
  tvsAdvantekBs6A46(5),
  greavesSedemacBlBs6(7),
  greavesSedemacAppBs6(8),
  greavesSedemacBs6(9),
  seedkeyalgoVecvBoschBs6_01(11),
  koelAutoBs4(12),
  koelCpcb4LowHpEcu(13),
  koelCpcb4HighHpEcu(14),
  koelCpcb4MidHpEcu(15),
  koelNiraSeedkeyalgo(16),
  koelGcuSeedkeyalgo(17),
  tataDnox(31);

  final int value;

  const SeedKeyIndexType(this.value);

  /// Helper to find enum from int value
  static SeedKeyIndexType? fromValue(int val) {
    for (var type in SeedKeyIndexType.values) {
      if (type.value == val) return type;
    }
    return null;
  }

  /// ✅ Helper to parse backend string safely
  static SeedKeyIndexType? fromApi(String? value) {
    switch (value) {

      case "GREAVES_ADVANTEK_BS6_A46":
        return SeedKeyIndexType.greavesAdvantekBs6A46;

      case "SANITAS_BOSCH_BS6_PROD":
        return SeedKeyIndexType.sanitasBoschBs6Prod;

      case "SANITAS_ADVANTEK_BS6_PROD":
        return SeedKeyIndexType.sanitasAdvantekBs6Prod;

      case "SANITAS_ADVANTEK_BS4_PROD":
        return SeedKeyIndexType.sanitasAdvantekBs4Prod;

      case "KOEL_BOSCH_BS4":
        return SeedKeyIndexType.koelBoschBs4;

      case "FLASH_KOEL_BOSCH_F6_CPCB4":
        return SeedKeyIndexType.flashKoelBoschF6Cpcb4;

      case "SANITAS_ADVANTEK_BS6_A46":
        return SeedKeyIndexType.sanitasAdvantekBs6A46;

      case "SEEDKEYALGO_VECV_BOSCH_BS6":
        return SeedKeyIndexType.seedkeyalgoVecvBoschBs6;

      case "SEEDKEYALGO_VECV_DELPHI_BS6":
        return SeedKeyIndexType.seedkeyalgoVecvDelphiBs6;

      case "SEEDKEYALGO_VECV_AMT_BS6":
        return SeedKeyIndexType.seedkeyalgoVecvAmtBs6;

      case "SEEDKEYALGO_BOSCH_CV54":
        return SeedKeyIndexType.seedkeyalgoBoschCv54;

      case "SEEDKEYALGO_VECV_DELPHI_TCIC":
        return SeedKeyIndexType.seedkeyalgoVecvDelphiTcic;

      case "GREAVES_BOSCH_BS6_PROD":
        return SeedKeyIndexType.greavesBoschBs6Prod;

      case "ATUL_ADVANTEK_BS6_A46":
        return SeedKeyIndexType.atulAdvantekBs6A46;

      case "TVS_ADVANTEK_BS6_A46":
        return SeedKeyIndexType.tvsAdvantekBs6A46;

      case "GREAVES_SEDEMAC_BL_BS6":
        return SeedKeyIndexType.greavesSedemacBlBs6;

      case "GREAVES_SEDEMAC_APP_BS6":
        return SeedKeyIndexType.greavesSedemacAppBs6;

      case "GREAVES_SEDEMAC_BS6":
        return SeedKeyIndexType.greavesSedemacBs6;

      case "SEEDKEYALGO_VECV_BOSCH_BS6_01":
        return SeedKeyIndexType.seedkeyalgoVecvBoschBs6_01;

      case "KOEL_AUTO_BS4":
        return SeedKeyIndexType.koelAutoBs4;

      case "KOEL_CPCB4_LOW_HP_ECU":
        return SeedKeyIndexType.koelCpcb4LowHpEcu;

      case "KOEL_CPCB4_HIGH_HP_ECU":
        return SeedKeyIndexType.koelCpcb4HighHpEcu;

      case "KOEL_CPCB4_MID_HP_ECU":
        return SeedKeyIndexType.koelCpcb4MidHpEcu;

      case "KOEL_NIRA_SEEDKEYALGO":
        return SeedKeyIndexType.koelNiraSeedkeyalgo;

      case "KOEL_GCU_SEEDKEYALGO":
        return SeedKeyIndexType.koelGcuSeedkeyalgo;

      case "TATA_DNOX":
        return SeedKeyIndexType.tataDnox;

      default:
        return null;
    }
  }
}