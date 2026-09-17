/// Data model for Fuel Analytics & refill metrics
class FuelAnalytics {
  final double fuelConsumed;
  final double fuelRefilled;
  final int refillCount;
  final String periodLabel;
  final List<double> consumptionDataPoints;
  final List<double> refillDataPoints;

  const FuelAnalytics({
    required this.fuelConsumed,
    required this.fuelRefilled,
    required this.refillCount,
    this.periodLabel = '30 Days',
    this.consumptionDataPoints = const [12, 18, 15, 22, 28, 24, 30, 26],
    this.refillDataPoints = const [10, 20, 14, 25, 20, 32, 28, 35],
  });

  factory FuelAnalytics.fromJson(Map<String, dynamic> json) {
    return FuelAnalytics(
      fuelConsumed: (json['fuelConsumed'] as num?)?.toDouble() ?? 2321.6,
      fuelRefilled: (json['fuelRefilled'] as num?)?.toDouble() ?? 2508.8,
      refillCount: json['refillCount'] as int? ?? 76,
      periodLabel: json['periodLabel'] as String? ?? '30 Days',
      consumptionDataPoints: (json['consumptionDataPoints'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [12, 18, 15, 22, 28, 24, 30, 26],
      refillDataPoints: (json['refillDataPoints'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [10, 20, 14, 25, 20, 32, 28, 35],
    );
  }

  Map<String, dynamic> toJson() => {
        'fuelConsumed': fuelConsumed,
        'fuelRefilled': fuelRefilled,
        'refillCount': refillCount,
        'periodLabel': periodLabel,
        'consumptionDataPoints': consumptionDataPoints,
        'refillDataPoints': refillDataPoints,
      };
}
