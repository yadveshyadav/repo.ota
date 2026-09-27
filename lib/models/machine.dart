enum ConnectivityState {
  live,
  offline,
  weak;

  String get label {
    switch (this) {
      case ConnectivityState.live:
        return 'Live';
      case ConnectivityState.offline:
        return 'Offline';
      case ConnectivityState.weak:
        return 'Weak';
    }
  }
}

enum OperationalState {
  working,
  moving,
  idle,
  onBattery,
  towing,
  powerCut,
  keyOnEngineOff,
  offline;

  String get label {
    switch (this) {
      case OperationalState.working:
        return 'Working';
      case OperationalState.moving:
        return 'Moving';
      case OperationalState.idle:
        return 'Idle';
      case OperationalState.onBattery:
        return 'On battery';
      case OperationalState.towing:
        return 'Towing';
      case OperationalState.powerCut:
        return 'Power cut';
      case OperationalState.keyOnEngineOff:
        return 'Key on · engine off';
      case OperationalState.offline:
        return 'Offline';
    }
  }
}

/// Data model for HERO APP heavy equipment machine entity (Hero/Fiberforce API)
class Machine {
  final String machineChassisNo;
  final String? engineNo;
  final String? modelCode;
  final String? modelName;
  final int? siteId;
  final String? siteName;
  final bool? isCommissioned;
  final dynamic vehicleNo;
  final dynamic fuelCard;
  final dynamic operatorInfo;
  final List<dynamic>? partners;

  // Telemetry & Live Status Fields
  final String id;
  final String currentStep;
  final String status;
  final String lastActive;
  final double latitude;
  final double longitude;
  final double speed;
  final double course;
  final double fuelLevelPercent;
  final double rpm;
  final double coolantTemperature;
  final double oilLevel;
  final bool keyOn;
  final bool engineOn;
  final ConnectivityState connectivity;
  final OperationalState operationalState;
  final String lastPacketAt;
  final String lastLocationAt;

  // Real API Extended Telemetry Fields
  final String? vendorName;
  final String? serialNumber;
  final String? code;
  final String? category;
  final String? runtimeStr;
  final double? engineHours;
  final String? lastFilledText;

  const Machine({
    required this.machineChassisNo,
    this.engineNo,
    this.modelCode,
    this.modelName,
    this.siteId,
    this.siteName,
    this.isCommissioned,
    this.vehicleNo,
    this.fuelCard,
    this.operatorInfo,
    this.partners,
    this.id = '',
    this.currentStep = 'Operation',
    this.status = 'Online LIVE',
    this.lastActive = 'Just now',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.speed = 0.0,
    this.course = 0.0,
    this.fuelLevelPercent = 0.0,
    this.rpm = 0.0,
    this.coolantTemperature = 74.0,
    this.oilLevel = 3.5,
    this.keyOn = true,
    this.engineOn = true,
    this.connectivity = ConnectivityState.live,
    this.operationalState = OperationalState.working,
    this.lastPacketAt = 'just now',
    this.lastLocationAt = 'just now',
    this.vendorName,
    this.serialNumber,
    this.code,
    this.category,
    this.runtimeStr,
    this.engineHours,
    this.lastFilledText,
  });

  // Convenient Getters for Live Status & HERO Web UI
  String get uniqueKey {
    if (machineChassisNo.isNotEmpty && machineChassisNo != 'N/A') {
      return machineChassisNo;
    }
    if (id.isNotEmpty && id != 'N/A') {
      return id;
    }
    if (serialNumber != null && serialNumber!.isNotEmpty && serialNumber != 'N/A') {
      return serialNumber!;
    }
    if (code != null && code!.isNotEmpty) {
      return code!;
    }
    return '$machineName-$siteId';
  }

  String get chassisNumber => machineChassisNo.isNotEmpty ? machineChassisNo : (serialNumber ?? 'N/A');
  String get registrationNo => vehicleNo?.toString() ?? code ?? chassisNumber;
  String get model => modelCode ?? modelName ?? 'A600';
  String get machineName =>
      modelName ?? modelCode ?? (machineChassisNo.isNotEmpty ? 'Machine $machineChassisNo' : 'Heavy Machine');
  String get machineType => modelCode ?? category ?? 'HDD Drill Rig';
  String get site => siteName ?? (siteId != null ? 'Site $siteId' : 'Primary Fleet Site');
  String get location => siteName ?? (siteId != null ? 'Site $siteId' : 'Primary Fleet Site');
  double get fuelLevel => fuelLevelPercent;

  bool get hasOperator {
    final name = operatorName.trim();
    return name.isNotEmpty &&
        name != 'Not Assigned' &&
        name != 'Unassigned' &&
        name != 'None' &&
        name != 'N/A' &&
        name != 'Ravi Kumar';
  }

  String get operatorName {
    String? rawName;
    if (operatorInfo is Map) {
      final map = operatorInfo as Map;
      rawName = map['name']?.toString() ??
          map['operator_name']?.toString() ??
          map['operatorName']?.toString() ??
          map['user_name']?.toString() ??
          map['userName']?.toString() ??
          map['username']?.toString() ??
          map['full_name']?.toString() ??
          map['fullName']?.toString() ??
          map['displayName']?.toString() ??
          map['title']?.toString();
      if (rawName == null || rawName.trim().isEmpty) {
        final first = map['first_name']?.toString() ?? map['firstName']?.toString() ?? '';
        final last = map['last_name']?.toString() ?? map['lastName']?.toString() ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) rawName = combined;
      }
    } else if (operatorInfo is String && (operatorInfo as String).trim().isNotEmpty) {
      rawName = (operatorInfo as String).trim();
    }

    if (rawName != null) {
      final cleaned = rawName.trim();
      if (cleaned.isNotEmpty &&
          cleaned != 'Ravi Kumar' &&
          cleaned != 'None' &&
          cleaned != 'N/A' &&
          cleaned != 'Unassigned') {
        return cleaned;
      }
    }
    return 'Not Assigned';
  }

  String? get fuelCardText {
    if (fuelCard is Map) {
      final name = fuelCard['name']?.toString() ?? 'Indian Oil';
      final cardNo = fuelCard['card_number']?.toString() ?? fuelCard['cardNumber']?.toString() ?? '';
      if (cardNo.length >= 4) {
        final last4 = cardNo.substring(cardNo.length - 4);
        return '$name ($last4)';
      }
      return name;
    } else if (fuelCard is String && (fuelCard as String).trim().isNotEmpty) {
      return (fuelCard as String).trim();
    }
    return null;
  }

  String get displayRuntime => runtimeStr ?? lastActive;

  String get displayName {
    if (modelName != null && modelName!.isNotEmpty) {
      if (code != null && code!.isNotEmpty && code != modelName) {
        return '$modelName ($code)';
      }
      return modelName!;
    }
    return modelCode ?? machineChassisNo;
  }

  bool get isLive => connectivity == ConnectivityState.live;

  bool get isOnline =>
      connectivity == ConnectivityState.live ||
      operationalState != OperationalState.offline ||
      status.toLowerCase().contains('online') ||
      status.toLowerCase().contains('working') ||
      status.toLowerCase().contains('running') ||
      status.toLowerCase().contains('idle');

  bool get isOffline =>
      connectivity == ConnectivityState.offline ||
      operationalState == OperationalState.offline ||
      status.toLowerCase().contains('offline');

  bool get isMaintenance =>
      status.toLowerCase().contains('maintenance') ||
      status.toLowerCase().contains('breakdown') ||
      status.toLowerCase().contains('under breakdown') ||
      status.toLowerCase().contains('repair');

  bool get isUnderBreakdown => isMaintenance;
  bool get isWorking => operationalState == OperationalState.working || status.toLowerCase() == 'running';
  bool get isMoving => operationalState == OperationalState.moving || speed > 1.0;
  bool get isIdle => operationalState == OperationalState.idle;
  bool get isOnBattery => operationalState == OperationalState.onBattery;
  bool get isKeyOnEngineOff => operationalState == OperationalState.keyOnEngineOff || (keyOn && !engineOn);
  bool get isPowerCut => operationalState == OperationalState.powerCut;

  factory Machine.fromJson(Map<String, dynamic> json) {
    final machineObj = json['machine'] is Map<String, dynamic>
        ? json['machine'] as Map<String, dynamic>
        : json['equipment'] is Map<String, dynamic>
            ? json['equipment'] as Map<String, dynamic>
            : null;

    final chassis = json['machine_chassis_no']?.toString() ??
        json['machine_no']?.toString() ??
        json['machineNo']?.toString() ??
        json['chassis_no']?.toString() ??
        json['chassisNo']?.toString() ??
        json['chassisNumber']?.toString() ??
        json['chassis']?.toString() ??
        json['serial_number']?.toString() ??
        json['serialNumber']?.toString() ??
        machineObj?['machine_chassis_no']?.toString() ??
        machineObj?['chassis_no']?.toString() ??
        machineObj?['chassis']?.toString() ??
        machineObj?['serial_number']?.toString() ??
        machineObj?['id']?.toString() ??
        json['id']?.toString() ??
        '';

    final isOnlineBool = json['is_online'] as bool?;
    final connStr = json['connectivity']?.toString() ?? '';
    ConnectivityState conn = ConnectivityState.live;
    if (isOnlineBool == false || connStr.toLowerCase() == 'offline') {
      conn = ConnectivityState.offline;
    } else if (connStr.toLowerCase() == 'weak') {
      conn = ConnectivityState.weak;
    }

    final rawStatus = json['status']?.toString() ?? '';
    final opStr = json['operationalState']?.toString() ?? rawStatus;
    OperationalState opState = _parseOperationalState(opStr, conn);

    final lat = (json['current_latitude'] as num?)?.toDouble() ??
        (json['latitude'] as num?)?.toDouble() ??
        (machineObj?['latitude'] as num?)?.toDouble() ??
        0.0;

    final lng = (json['current_longitude'] as num?)?.toDouble() ??
        (json['longitude'] as num?)?.toDouble() ??
        (machineObj?['longitude'] as num?)?.toDouble() ??
        0.0;

    final fuelPct = (json['fuel_percentage'] as num?)?.toDouble() ??
        (json['fuelLevelPercent'] as num?)?.toDouble() ??
        (json['fuel_level'] as num?)?.toDouble() ??
        double.tryParse('${json['current_fuel_level']}') ??
        0.0;

    final engineOnBool = json['engine_on'] as bool? ??
        (rawStatus.toUpperCase() == 'RUNNING');

    final mName = json['name']?.toString() ??
        json['model_name']?.toString() ??
        json['modelName']?.toString() ??
        json['machineName']?.toString() ??
        json['title']?.toString() ??
        machineObj?['name']?.toString() ??
        machineObj?['model_name']?.toString() ??
        machineObj?['title']?.toString();

    final mCode = json['model_code']?.toString() ??
        json['model']?.toString() ??
        json['modelCode']?.toString() ??
        machineObj?['model_code']?.toString() ??
        machineObj?['model']?.toString();

    final sName = json['site_name']?.toString() ??
        json['location_name']?.toString() ??
        json['siteName']?.toString() ??
        json['location']?.toString() ??
        machineObj?['site_name']?.toString() ??
        machineObj?['location_name']?.toString();

    return Machine(
      machineChassisNo: chassis,
      engineNo: json['engine_no']?.toString() ?? json['engineNo']?.toString(),
      modelCode: mCode,
      modelName: mName,
      siteId: json['site_id'] is int
          ? json['site_id'] as int
          : int.tryParse(json['site_id']?.toString() ?? ''),
      siteName: sName,
      isCommissioned: json['is_commissioned'] as bool? ??
          json['isCommissioned'] as bool?,
      vehicleNo: json['vehicle_no'] ?? json['vehicleNo'],
      fuelCard: json['fuel_card'] ?? json['fuelCard'],
      operatorInfo: json['operator'] ??
          json['operator_info'] ??
          json['operatorInfo'] ??
          json['operator_name'] ??
          json['operatorName'] ??
          json['assigned_operator'] ??
          json['assignedOperator'] ??
          json['driver'] ??
          json['driver_name'] ??
          json['driver_info'],
      partners: json['partners'] as List<dynamic>?,
      id: json['id']?.toString() ?? chassis,
      currentStep: json['currentStep']?.toString() ?? json['state_label']?.toString() ?? 'Operation',
      status: rawStatus.isNotEmpty ? rawStatus : 'IDLE',
      lastActive: json['runtime_str']?.toString() ?? json['lastActive']?.toString() ?? '00h 00m',
      latitude: lat,
      longitude: lng,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      course: (json['course'] as num?)?.toDouble() ?? 167.0,
      fuelLevelPercent: fuelPct,
      rpm: (json['rpm'] as num?)?.toDouble() ?? 0.0,
      coolantTemperature: (json['coolantTemperature'] as num?)?.toDouble() ??
          (json['coolant_temp'] as num?)?.toDouble() ??
          85.0,
      oilLevel: (json['oilLevel'] as num?)?.toDouble() ??
          (json['oil_pressure'] as num?)?.toDouble() ??
          (json['oil_level'] as num?)?.toDouble() ??
          3.5,
      keyOn: json['keyOn'] as bool? ?? json['key_on'] as bool? ?? (engineOnBool || rawStatus == 'IDLE'),
      engineOn: engineOnBool,
      connectivity: conn,
      operationalState: opState,
      lastPacketAt: json['lastPacketAt']?.toString() ?? json['updated_at']?.toString() ?? 'just now',
      lastLocationAt: json['lastLocationAt']?.toString() ?? json['updated_at']?.toString() ?? 'just now',
      vendorName: json['vendor_name']?.toString() ?? json['vendorName']?.toString(),
      serialNumber: json['serial_number']?.toString() ?? json['machine_no']?.toString(),
      code: json['code']?.toString(),
      category: json['category']?.toString() ?? 'HDD',
      runtimeStr: json['runtime_str']?.toString(),
      engineHours: (json['engine_hours'] as num?)?.toDouble() ?? 0.0,
      lastFilledText: json['last_filled_text']?.toString(),
    );
  }

  static OperationalState _parseOperationalState(String str, ConnectivityState conn) {
    if (conn == ConnectivityState.offline) return OperationalState.offline;
    final lower = str.toLowerCase();
    if (lower.contains('running') || lower.contains('working')) return OperationalState.working;
    if (lower.contains('moving')) return OperationalState.moving;
    if (lower.contains('idle')) return OperationalState.idle;
    if (lower.contains('maintenance')) return OperationalState.idle;
    if (lower.contains('battery')) return OperationalState.onBattery;
    if (lower.contains('towing')) return OperationalState.towing;
    if (lower.contains('power cut') || lower.contains('powercut')) return OperationalState.powerCut;
    if (lower.contains('key on') || lower.contains('keyon')) return OperationalState.keyOnEngineOff;
    if (lower.contains('offline')) return OperationalState.offline;
    return OperationalState.working;
  }

  Map<String, dynamic> toJson() => {
        'machine_chassis_no': machineChassisNo,
        'engine_no': engineNo,
        'model_code': modelCode,
        'model_name': modelName,
        'site_id': siteId,
        'site_name': siteName,
        'is_commissioned': isCommissioned,
        'vehicle_no': vehicleNo,
        'fuel_card': fuelCard,
        'operator': operatorInfo,
        'partners': partners,
        'id': id,
        'chassisNumber': chassisNumber,
        'machineName': machineName,
        'machineType': machineType,
        'location': location,
        'currentStep': currentStep,
        'status': status,
        'lastActive': lastActive,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'course': course,
        'fuelLevelPercent': fuelLevelPercent,
        'rpm': rpm,
        'coolantTemperature': coolantTemperature,
        'oilLevel': oilLevel,
        'keyOn': keyOn,
        'engineOn': engineOn,
        'connectivity': connectivity.name,
        'operationalState': operationalState.name,
        'lastPacketAt': lastPacketAt,
        'lastLocationAt': lastLocationAt,
        'vendor_name': vendorName,
        'serial_number': serialNumber,
        'code': code,
        'category': category,
        'runtime_str': runtimeStr,
        'engine_hours': engineHours,
        'last_filled_text': lastFilledText,
      };
}
