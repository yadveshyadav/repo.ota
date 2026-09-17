/// Strongly typed Circle-wise Stock Summary Model
class CircleStockSummaryModel {
  final String? warehouseCode;
  final String? circleName;
  final double? totalMaterial;
  final int? drumCount;
  final double? reservedQuantity;
  final int? vendorsIssued;

  const CircleStockSummaryModel({
    this.warehouseCode,
    this.circleName,
    this.totalMaterial,
    this.drumCount,
    this.reservedQuantity,
    this.vendorsIssued,
  });

  factory CircleStockSummaryModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const CircleStockSummaryModel();
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return CircleStockSummaryModel(
      warehouseCode: json['warehouseCode']?.toString() ?? json['warehouse_code']?.toString(),
      circleName: json['circleName']?.toString() ?? json['circle_name']?.toString() ?? json['circle']?.toString(),
      totalMaterial: parseDouble(json['totalMaterial'] ?? json['total_material']),
      drumCount: parseInt(json['drumCount'] ?? json['drum_count']),
      reservedQuantity: parseDouble(json['reservedQuantity'] ?? json['reserved_quantity']),
      vendorsIssued: parseInt(json['vendorsIssued'] ?? json['vendors_issued']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (warehouseCode != null) 'warehouseCode': warehouseCode,
        if (circleName != null) 'circleName': circleName,
        if (totalMaterial != null) 'totalMaterial': totalMaterial,
        if (drumCount != null) 'drumCount': drumCount,
        if (reservedQuantity != null) 'reservedQuantity': reservedQuantity,
        if (vendorsIssued != null) 'vendorsIssued': vendorsIssued,
      };
}
