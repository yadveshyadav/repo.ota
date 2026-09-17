/// Strongly typed Inventory Summary KPI Model
class InventorySummaryModel {
  final double? totalIssuedMaterial;
  final int? drumsInventoryCount;
  final double? reservedQuantity;
  final int? activeCirclesCount;

  const InventorySummaryModel({
    this.totalIssuedMaterial,
    this.drumsInventoryCount,
    this.reservedQuantity,
    this.activeCirclesCount,
  });

  factory InventorySummaryModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const InventorySummaryModel();
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

    return InventorySummaryModel(
      totalIssuedMaterial: parseDouble(json['totalIssuedMaterial'] ?? json['total_issued_material']),
      drumsInventoryCount: parseInt(json['drumsInventoryCount'] ?? json['drums_inventory_count']),
      reservedQuantity: parseDouble(json['reservedQuantity'] ?? json['reserved_quantity']),
      activeCirclesCount: parseInt(json['activeCirclesCount'] ?? json['active_circles_count']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (totalIssuedMaterial != null) 'totalIssuedMaterial': totalIssuedMaterial,
        if (drumsInventoryCount != null) 'drumsInventoryCount': drumsInventoryCount,
        if (reservedQuantity != null) 'reservedQuantity': reservedQuantity,
        if (activeCirclesCount != null) 'activeCirclesCount': activeCirclesCount,
      };
}
