/// Data model for Engine Hours breakdown
class EngineHours {
  final Duration total;
  final Duration working;
  final Duration moving;
  final Duration idle;
  final Duration averagePerMachine;
  final double workingPercentage;
  final double idlePercentage;
  final DateTime date;

  const EngineHours({
    required this.total,
    required this.working,
    required this.moving,
    required this.idle,
    required this.averagePerMachine,
    required this.workingPercentage,
    required this.idlePercentage,
    required this.date,
  });

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  factory EngineHours.fromJson(Map<String, dynamic> json) {
    return EngineHours(
      total: Duration(minutes: json['totalMinutes'] as int? ?? 1236), // 20h 36m
      working: Duration(minutes: json['workingMinutes'] as int? ?? 900), // 15h 0m
      moving: Duration(minutes: json['movingMinutes'] as int? ?? 42), // 0h 42m
      idle: Duration(minutes: json['idleMinutes'] as int? ?? 288), // 4h 48m
      averagePerMachine: Duration(minutes: json['avgMinutes'] as int? ?? 56),
      workingPercentage: (json['workingPercentage'] as num?)?.toDouble() ?? 73.0,
      idlePercentage: (json['idlePercentage'] as num?)?.toDouble() ?? 23.5,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalMinutes': total.inMinutes,
        'workingMinutes': working.inMinutes,
        'movingMinutes': moving.inMinutes,
        'idleMinutes': idle.inMinutes,
        'avgMinutes': averagePerMachine.inMinutes,
        'workingPercentage': workingPercentage,
        'idlePercentage': idlePercentage,
        'date': date.toIso8601String(),
      };
}
