/// Data model for machine fleet utilization percentages
class Utilization {
  final double working;
  final double moving;
  final double idle;
  final String periodLabel;

  const Utilization({
    required this.working,
    required this.moving,
    required this.idle,
    this.periodLabel = 'Today',
  });

  factory Utilization.fromJson(Map<String, dynamic> json) {
    return Utilization(
      working: (json['working'] as num?)?.toDouble() ?? 73.0,
      moving: (json['moving'] as num?)?.toDouble() ?? 3.0,
      idle: (json['idle'] as num?)?.toDouble() ?? 23.0,
      periodLabel: json['periodLabel'] as String? ?? 'Today',
    );
  }

  Map<String, dynamic> toJson() => {
        'working': working,
        'moving': moving,
        'idle': idle,
        'periodLabel': periodLabel,
      };
}
