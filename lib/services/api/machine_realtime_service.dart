import 'dart:async';
import '../../models/machine.dart';

/// Abstract service providing real-time telemetry streams for machines.
/// Decouples the UI and Controller from underlying transport mechanisms
/// (WebSocket, Server-Sent Events (SSE), or Configurable Polling).
abstract class MachineRealtimeService {
  /// Stream emitting individual updated machines as telemetry arrives
  Stream<Machine> get machineUpdates;

  /// Stream emitting full fleet updates
  Stream<List<Machine>> get fleetUpdates;

  /// Connect to real-time endpoint
  Future<void> connect();

  /// Disconnect and release resources
  Future<void> disconnect();

  /// Check if real-time stream is active
  bool get isConnected;
}

/// Fallback / Mock Realtime Provider simulating subtle telemetry ticks
class MockMachineRealtimeService implements MachineRealtimeService {
  final StreamController<Machine> _machineController =
      StreamController<Machine>.broadcast();
  final StreamController<List<Machine>> _fleetController =
      StreamController<List<Machine>>.broadcast();

  bool _connected = false;
  Timer? _timer;

  @override
  Stream<Machine> get machineUpdates => _machineController.stream;

  @override
  Stream<List<Machine>> get fleetUpdates => _fleetController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Simulate a push update for a specific machine
  void emitMachineUpdate(Machine machine) {
    if (_connected && !_machineController.isClosed) {
      _machineController.add(machine);
    }
  }

  /// Simulate a full fleet update
  void emitFleetUpdate(List<Machine> fleet) {
    if (_connected && !_fleetController.isClosed) {
      _fleetController.add(fleet);
    }
  }

  void dispose() {
    disconnect();
    _machineController.close();
    _fleetController.close();
  }
}
