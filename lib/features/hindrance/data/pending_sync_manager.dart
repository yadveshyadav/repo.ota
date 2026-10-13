import 'dart:async';

import 'package:flutter/foundation.dart';

class PendingSyncJob {
  final String id;
  final String formType;
  final List<String> files;
  final int totalBytes;
  final int sentBytes;
  final String state;
  final String? error;

  const PendingSyncJob({
    required this.id,
    required this.formType,
    this.files = const [],
    required this.totalBytes,
    required this.sentBytes,
    required this.state,
    this.error,
  });

  double get progress => totalBytes <= 0
      ? (state == 'COMPLETE' ? 1 : 0)
      : (sentBytes / totalBytes).clamp(0, 1).toDouble();

  PendingSyncJob copyWith({
    int? totalBytes,
    List<String>? files,
    int? sentBytes,
    String? state,
    String? error,
    bool clearError = false,
  }) => PendingSyncJob(
    id: id,
    formType: formType,
    files: files ?? this.files,
    totalBytes: totalBytes ?? this.totalBytes,
    sentBytes: sentBytes ?? this.sentBytes,
    state: state ?? this.state,
    error: clearError ? null : error ?? this.error,
  );
}

/// Tracks uploads while their form route is closed. The form data and progress
/// checkpoints are persisted by the submitter; this notifier drives the live UI.
class PendingSyncManager {
  PendingSyncManager._();

  static final PendingSyncManager instance = PendingSyncManager._();

  final ValueNotifier<List<PendingSyncJob>> jobs =
      ValueNotifier<List<PendingSyncJob>>(<PendingSyncJob>[]);
  final Set<String> _active = <String>{};
  final Map<String, Future<void> Function(Future<void> Function(int))>
  _runners = {};

  bool isActive(String id) => _active.contains(id);

  void restore(Iterable<Map<String, dynamic>> reports) {
    for (final report in reports) {
      final state = report['queueState']?.toString().toUpperCase() ?? '';
      if (!const {'PENDING_SYNC', 'SYNCING', 'SYNC_FAILED'}.contains(state)) {
        continue;
      }
      final id = report['reportId']?.toString() ?? '';
      if (id.isEmpty || _find(id) != null) continue;
      final media = (report['media'] as List? ?? const [])
          .whereType<Map>()
          .toList();
      final shpFiles = (report['shpFiles'] as List? ?? const [])
          .whereType<Map>()
          .toList();
      int bytesFor(Iterable<Map> files, String key) => files.fold<int>(
        0,
        (sum, item) => sum + (int.tryParse(item[key]?.toString() ?? '') ?? 0),
      );
      final totalBytes =
          int.tryParse(report['syncBytesTotal']?.toString() ?? '') ??
          bytesFor([...media, ...shpFiles], 'sizeBytes');
      final sentBytes =
          int.tryParse(report['syncBytesSent']?.toString() ?? '') ??
          bytesFor(
            [...media, ...shpFiles].where((item) => item['uploadKey'] != null),
            'sizeBytes',
          );
      _put(
        PendingSyncJob(
          id: id,
          formType: report['recordType']?.toString() ?? 'Form',
          files: [
            ...media.map((item) => fileLabel(item)),
            ...shpFiles.map((item) => fileLabel(item)),
          ],
          totalBytes: totalBytes,
          sentBytes: sentBytes.clamp(0, totalBytes).toInt(),
          state: state == 'SYNC_FAILED' ? 'FAILED' : 'QUEUED',
          error:
              report['syncError']?.toString() ??
              (state == 'SYNC_FAILED'
                  ? 'Sync stopped before its failure details were saved.'
                  : null),
        ),
      );
    }
  }

  /// Reattaches a durable report to its submitter after process restart.
  /// Restored jobs have no live closure until their owning screen rebuilds it.
  void registerRunner(
    String id,
    Future<void> Function(Future<void> Function(int)) run,
  ) {
    _runners[id] = run;
    final current = _find(id);
    if (current != null) _put(current);
  }

  void start({
    required String id,
    required String formType,
    required int totalBytes,
    List<String> files = const [],
    required Future<void> Function(Future<void> Function(int) onBytesSent) run,
  }) {
    if (!_active.add(id)) return;
    _runners[id] = run;
    _put(
      _find(id)?.copyWith(
            totalBytes: totalBytes,
            files: files,
            state: 'SYNCING',
            sentBytes: 0,
            clearError: true,
          ) ??
          PendingSyncJob(
            id: id,
            formType: formType,
            files: files,
            totalBytes: totalBytes,
            sentBytes: 0,
            state: 'SYNCING',
          ),
    );
    unawaited(_run(id, totalBytes, run));
  }

  bool canRetry(String id) => !_active.contains(id) && _runners.containsKey(id);

  void retry(String id) {
    final runner = _runners[id];
    final current = _find(id);
    if (runner == null || current == null || !_active.add(id)) return;
    _put(current.copyWith(state: 'SYNCING', sentBytes: 0, clearError: true));
    unawaited(_run(id, current.totalBytes, runner));
  }

  Future<void> _run(
    String id,
    int totalBytes,
    Future<void> Function(Future<void> Function(int) onBytesSent) run,
  ) async {
    try {
      await run((count) async {
        final current = _find(id);
        if (current == null) return;
        _put(current.copyWith(sentBytes: current.sentBytes + count));
      });
      final current = _find(id);
      if (current != null) {
        _put(current.copyWith(sentBytes: totalBytes, state: 'COMPLETE'));
      }
      _runners.remove(id);
    } catch (error) {
      final current = _find(id);
      if (current != null) {
        _put(current.copyWith(state: 'FAILED', error: error.toString()));
      }
    } finally {
      _active.remove(id);
    }
  }

  PendingSyncJob? _find(String id) =>
      jobs.value.where((job) => job.id == id).firstOrNull;

  void _put(PendingSyncJob job) {
    final next = [...jobs.value];
    final index = next.indexWhere((item) => item.id == job.id);
    if (index < 0) {
      next.insert(0, job);
    } else {
      next[index] = job;
    }
    jobs.value = next;
  }

  static String fileLabel(Map item) {
    final name =
        item['filename']?.toString() ??
        item['name']?.toString() ??
        item['slot']?.toString() ??
        'Attachment';
    final size = int.tryParse(item['sizeBytes']?.toString() ?? '') ?? 0;
    final displaySize = size < 1024
        ? '$size B'
        : size < 1024 * 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '$name · $displaySize';
  }
}
