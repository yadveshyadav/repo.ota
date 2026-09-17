import 'package:intl/intl.dart';
import '../core/utils/date_parser_utils.dart';

/// Strongly-typed Data Model for Machine Refuel Entries from GET /api/v1/refuel/
class RefuelModel {
  final String id;
  final String machineName;
  final String machineCode;
  final String machineNo;
  final String performedByName;
  final double quantityLiters;
  final double pricePerLiter;
  final double totalCost;
  final String meterReading;
  final DateTime refuelDate;
  final String notes;
  final String machineId;
  final String performedById;

  const RefuelModel({
    required this.id,
    required this.machineName,
    required this.machineCode,
    required this.machineNo,
    required this.performedByName,
    required this.quantityLiters,
    this.pricePerLiter = 0.0,
    this.totalCost = 0.0,
    this.meterReading = '0.0',
    required this.refuelDate,
    this.notes = '',
    required this.machineId,
    required this.performedById,
  });

  String get formattedAmount =>
      '+${quantityLiters.toStringAsFixed(quantityLiters.truncateToDouble() == quantityLiters ? 0 : 1)} L';

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(refuelDate.toLocal());

  String get formattedCost => '₹${totalCost.toStringAsFixed(2)}';

  String get formattedMeterReading => meterReading.contains('h') || meterReading.contains('m')
      ? meterReading
      : '${meterReading}h';

  factory RefuelModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    double parseNumDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString().replaceAll(',', '').trim()) ?? 0.0;
    }

    final rawId = source['id'] ?? source['refuel_id'] ?? source['refuelId'] ?? '';
    final mName = source['machine_name']?.toString() ??
        source['machineName']?.toString() ??
        source['machine_code']?.toString() ??
        'Machine';
    final mCode = source['machine_code']?.toString() ??
        source['machine_no']?.toString() ??
        source['machineNo']?.toString() ??
        '';
    final mNo = source['machine_no']?.toString() ??
        source['machineNo']?.toString() ??
        mCode;

    final pName = source['performed_by_name']?.toString() ??
        source['refueled_by']?.toString() ??
        source['refueledBy']?.toString() ??
        source['user_name']?.toString() ??
        'Operator';

    final qty = parseNumDouble(
        source['quantity_liters'] ?? source['quantity'] ?? source['liters'] ?? source['amount']);
    final price = parseNumDouble(source['price_per_liter'] ?? source['price']);
    var cost = parseNumDouble(source['total_cost'] ?? source['cost']);
    if (cost == 0.0 && qty > 0 && price > 0) {
      cost = qty * price;
    }

    final meter = source['meter_reading']?.toString() ??
        source['meterReading']?.toString() ??
        source['engine_hours']?.toString() ??
        '0.0';

    final dt = DateParserUtils.parse(
        source['refuel_date'] ?? source['refuelDate'] ?? source['dateTime'] ?? source['created_at']);

    final mId = source['machine']?.toString() ??
        source['machine_id']?.toString() ??
        source['machineId']?.toString() ??
        '';

    final pId = source['performed_by']?.toString() ??
        source['performed_by_id']?.toString() ??
        source['userId']?.toString() ??
        '';

    return RefuelModel(
      id: rawId.toString(),
      machineName: mName,
      machineCode: mCode,
      machineNo: mNo,
      performedByName: pName,
      quantityLiters: qty,
      pricePerLiter: price,
      totalCost: cost,
      meterReading: meter,
      refuelDate: dt ?? DateTime.now(),
      notes: source['notes']?.toString() ?? '',
      machineId: mId,
      performedById: pId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'machine_name': machineName,
        'machine_code': machineCode,
        'machine_no': machineNo,
        'performed_by_name': performedByName,
        'quantity_liters': quantityLiters.toStringAsFixed(2),
        'price_per_liter': pricePerLiter.toStringAsFixed(2),
        'total_cost': totalCost.toStringAsFixed(2),
        'meter_reading': meterReading,
        'refuel_date': refuelDate.toIso8601String(),
        'notes': notes,
        'machine': machineId,
        'performed_by': performedById,
      };
}
