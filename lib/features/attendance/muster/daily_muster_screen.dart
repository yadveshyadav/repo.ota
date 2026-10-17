import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/services/auth_storage_service.dart';
import '../../../models/task_model.dart';
import '../../../services/api/task_api_service.dart';
import 'daily_muster_api_service.dart';
import 'daily_muster_local_store.dart';
import 'daily_muster_photo_capture_screen.dart';

/// Separate workforce muster flow, intentionally independent from legacy
/// employee/machine attendance check-in and repository state.
class DailyMusterScreen extends StatefulWidget {
  const DailyMusterScreen({super.key});

  @override
  State<DailyMusterScreen> createState() => _DailyMusterScreenState();
}

class _DailyMusterScreenState extends State<DailyMusterScreen> {
  final _taskApi = TaskApiService();
  final _api = DailyMusterApiService();
  final _store = DailyMusterLocalStore();
  final _uuid = const Uuid();
  final _headcount = <String, TextEditingController>{
    'vendorLabour': TextEditingController(),
    'ownLabour': TextEditingController(),
    'technicians': TextEditingController(),
    'ownTeamMembers': TextEditingController(),
  };
  final _reason = TextEditingController();
  final _remarks = TextEditingController();
  final _vendorId = TextEditingController();
  final _vendorName = TextEditingController();

  List<TaskModel> _tasks = [];
  TaskModel? _task;
  Map<String, dynamic>? _muster;
  String? _clientId;
  String _teamSource = 'OWN';
  bool _nilWork = false;
  final Map<String, bool> _resources = {
    'VENDOR_TEAM': false,
    'OWN_TEAM': true,
    'OTDR_SPLICING_MACHINE': false,
    'JCB': false,
    'NE_IE': false,
    'AM_FE': false,
  };
  final Map<String, Map<String, dynamic>> _photos = {};
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _notice;

  String get _ownerId => AuthStorageService().currentUser?.id ?? 'unknown';
  String get _status => (_muster?['status'] ?? '').toString().toUpperCase();
  bool get _readOnly => const {'SUBMITTED', 'APPROVED'}.contains(_status);
  bool get _hasServerMuster => (_muster?['id'] ?? '').toString().isNotEmpty;
  bool get _canStartTask =>
      _task != null &&
      const {
        'CREATED',
        'PARTIALLY_SAVED',
        'REJECTED',
      }.contains(_task!.status.toUpperCase());

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    for (final controller in _headcount.values) {
      controller.dispose();
    }
    _reason.dispose();
    _remarks.dispose();
    _vendorId.dispose();
    _vendorName.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final response = await _taskApi.fetchTasks(page: 0, size: 100);
      final roots = response.tasks.where((task) {
        final block = task.taskLevelProvided
            ? task.taskLevel.toUpperCase() == 'BLOCK'
            : (task.parentTaskId == null || task.parentTaskId!.isEmpty) &&
                  (task.rootTaskId == null ||
                      task.rootTaskId!.isEmpty ||
                      task.rootTaskId == task.id);
        return block && task.id.isNotEmpty;
      }).toList();
      if (!mounted) return;
      setState(() {
        final selectedId = _task?.id;
        _tasks = roots;
        if (selectedId != null) {
          final matches = roots.where((task) => task.id == selectedId);
          _task = matches.isEmpty ? null : matches.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectTask(TaskModel? task) async {
    if (task == null) return;
    setState(() {
      _task = task;
      _muster = null;
      _photos.clear();
      _error = null;
      _notice = null;
      _loading = true;
    });
    try {
      final remote = await _api.today(task.id);
      final local = await _store.read(_ownerId, task.id);
      final data = remote ?? local;
      if (data != null) _apply(data);
      if (remote != null) {
        final remoteId = (remote['id'] ?? '').toString();
        if (remoteId.isNotEmpty && local != null) {
          // Server data is authoritative while local paths fill in only absent media metadata.
          final localPhotos = local['localPhotos'];
          if (localPhotos is Map) {
            _photos.addAll(
              Map<String, Map<String, dynamic>>.from(
                localPhotos.map(
                  (k, v) => MapEntry(
                    k.toString(),
                    Map<String, dynamic>.from(v as Map),
                  ),
                ),
              ),
            );
          }
          if (mounted) {
            setState(
              () => _notice =
                  'Today’s server muster loaded. Unsynced local photos are retained.',
            );
          }
        }
      } else if (local != null) {
        if (mounted) {
          setState(() => _notice = 'Restored saved draft from this device.');
        }
      }
    } catch (e) {
      final local = await _store.read(_ownerId, task.id);
      if (local != null) {
        _apply(local);
        if (mounted) {
          setState(
            () => _notice =
                'Offline: showing the locally saved draft. Sync when connected.',
          );
        }
      } else if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(Map<String, dynamic> data) {
    _muster = data;
    _clientId =
        (data['clientMusterId'] ?? data['clientId'])?.toString() ?? _uuid.v4();
    _teamSource = (data['teamSource'] ?? 'OWN').toString();
    _nilWork = data['nilWork'] == true;
    _reason.text = (data['nilWorkReason'] ?? '').toString();
    _remarks.text = (data['remarks'] ?? '').toString();
    _vendorId.text = (data['vendorId'] ?? '').toString();
    _vendorName.text = (data['vendorName'] ?? '').toString();
    final headcount = data['headcount'];
    if (headcount is Map) {
      for (final key in _headcount.keys) {
        _headcount[key]!.text = (headcount[key] ?? '').toString();
      }
    }
    final resources = data['resources'];
    if (resources is Map) {
      for (final key in _resources.keys) {
        _resources[key] = resources[key] == true;
      }
    }
    final localPhotos = data['localPhotos'];
    if (localPhotos is Map) {
      _photos
        ..clear()
        ..addAll(
          localPhotos.map(
            (k, v) =>
                MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
          ),
        );
    }
    for (final slot in const ['team', 'jcb']) {
      final serverPhoto = data['${slot}Photo'];
      if (serverPhoto is Map && serverPhoto['photoKey'] != null) {
        _photos.putIfAbsent(slot, () => Map<String, dynamic>.from(serverPhoto));
      }
    }
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _payload() {
    final payload = <String, dynamic>{
      'clientMusterId': _clientId ??= _uuid.v4(),
      'nilWork': _nilWork,
      'nilWorkReason': _nilWork ? _reason.text.trim() : null,
      'remarks': _remarks.text.trim(),
    };
    if (!_nilWork) {
      final user = AuthStorageService().currentUser;
      payload.addAll({
        'teamSource': _teamSource,
        if (_teamSource != 'OWN' && _vendorId.text.trim().isNotEmpty)
          'vendorId': _vendorId.text.trim(),
        if (_teamSource != 'OWN' && _vendorName.text.trim().isNotEmpty)
          'vendorName': _vendorName.text.trim(),
        if (_teamSource != 'OWN' &&
            _vendorId.text.trim().isEmpty &&
            user?.vendorId != null)
          'vendorId': user!.vendorId,
        if (_teamSource != 'OWN' &&
            _vendorName.text.trim().isEmpty &&
            user?.vendorName != null)
          'vendorName': user!.vendorName,
        'headcount': {
          for (final item in _headcount.entries)
            item.key: int.tryParse(item.value.text) ?? 0,
        },
        'resources': Map<String, bool>.from(_resources),
      });
    }
    return payload;
  }

  Future<void> _persistLocal({String? status}) async {
    final task = _task;
    if (task == null) return;
    final data = <String, dynamic>{
      ...?_muster,
      ..._payload(),
      if (_muster?['id'] != null) 'id': _muster!['id'],
      ...?(status == null ? null : <String, dynamic>{'status': status}),
      'localPhotos': _photos,
      'localSavedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.write(_ownerId, task.id, data);
  }

  Future<void> _startIfNeeded() async {
    if (_hasServerMuster) return;
    final task = _task!;
    final local = await _store.read(_ownerId, task.id);
    if (local != null && (local['id'] ?? '').toString().isNotEmpty) {
      _muster = local;
      return;
    }
    final created = await _api.create(task.id, {
      'clientMusterId': _clientId ??= _uuid.v4(),
    });
    _muster = created;
  }

  Future<Map<String, dynamic>> _uploadedPhoto(String slot) async {
    final metadata = _photos[slot];
    if (metadata == null) throw Exception('$slot photo is required.');
    if ((metadata['photoKey'] ?? '').toString().isNotEmpty) return metadata;
    final musterId = (_muster?['id'] ?? '').toString();
    final upload = await _api.photoUploadUrl(
      musterId: musterId,
      entryId: slot.toLowerCase(),
    );
    final url = (upload['uploadUrl'] ?? '').toString();
    final key = (upload['photoKey'] ?? '').toString();
    if (url.isEmpty || key.isEmpty) {
      throw Exception('Photo upload URL response is incomplete.');
    }
    await _api.uploadPhoto(url: url, path: metadata['localPath'].toString());
    return {...metadata, 'photoKey': key};
  }

  Map<String, dynamic> _serverPhoto(Map<String, dynamic> photo) => {
    for (final key in const [
      'photoKey',
      'photoCapturedAt',
      'latitude',
      'longitude',
      'accuracyMeters',
      'fixCapturedAt',
      'provider',
      'mockLocationFlagged',
    ])
      if (photo[key] != null) key: photo[key],
    'cameraLive': true,
  };

  Future<void> _save({bool submit = false}) async {
    final task = _task;
    if (task == null || _working || _readOnly) return;
    if (!_hasServerMuster && !_canStartTask) {
      setState(
        () =>
            _error = 'This task status does not allow starting a daily muster.',
      );
      return;
    }
    if (_nilWork && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter a reason for nil-work.');
      return;
    }
    final fallbackVendorName = AuthStorageService().currentUser?.vendorName;
    if (!_nilWork &&
        _teamSource != 'OWN' &&
        _vendorName.text.trim().isEmpty &&
        (fallbackVendorName == null || fallbackVendorName.trim().isEmpty)) {
      setState(
        () => _error = 'Enter the vendor name for the selected team source.',
      );
      return;
    }
    if (submit && !_nilWork) {
      final total = _headcount.values.fold<int>(
        0,
        (sum, c) => sum + (int.tryParse(c.text) ?? 0),
      );
      if (total < 1) {
        setState(() => _error = 'Enter at least one person in the headcount.');
        return;
      }
      if (_photos['team'] == null) {
        setState(
          () => _error =
              'Capture the required live Team photo before submitting.',
        );
        return;
      }
      if (_photos['team']?['mockLocationFlagged'] == true) {
        setState(
          () => _error =
              'Mock location was detected. Retake the Team photo at the work location.',
        );
        return;
      }
      if (_resources['JCB'] == true && _photos['jcb'] == null) {
        setState(
          () =>
              _error = 'Capture the JCB photo because JCB is marked available.',
        );
        return;
      }
    }
    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      await _persistLocal(status: 'LOCAL_DRAFT');
      await _startIfNeeded();
      final payload = _payload()..remove('clientMusterId');
      if (!_nilWork && _photos['team'] != null) {
        final p = await _uploadedPhoto('team');
        _photos['team'] = p;
        payload['teamPhoto'] = _serverPhoto(p);
      }
      if (!_nilWork && _resources['JCB'] == true && _photos['jcb'] != null) {
        final p = await _uploadedPhoto('jcb');
        _photos['jcb'] = p;
        payload['jcbPhoto'] = _serverPhoto(p);
      }
      final id = (_muster?['id'] ?? '').toString();
      if (id.isEmpty) {
        throw Exception(
          'Server did not return a muster ID. Your local draft is preserved.',
        );
      }
      final updated = await _api.update(id, payload);
      _muster = {...?_muster, ...updated, ...payload, 'id': id};
      if (submit) {
        await _api.submit(id);
        _muster = {...?_muster, 'status': 'SUBMITTED'};
        await _store.remove(_ownerId, task.id);
        if (mounted) setState(() => _notice = 'Muster submitted successfully.');
      } else {
        await _persistLocal(status: _status.isEmpty ? 'DRAFT' : _status);
        if (mounted) {
          setState(
            () => _notice = 'Draft saved to the server and this device.',
          );
        }
      }
    } catch (e) {
      await _persistLocal(status: _status.isEmpty ? 'LOCAL_DRAFT' : _status);
      if (mounted) {
        setState(
          () => _error =
              'Could not ${submit ? 'submit' : 'save'} muster. Local draft retained. $e',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _capturePhoto(String slot) async {
    final result = await Navigator.of(context).push<MusterPhotoCapture>(
      MaterialPageRoute(
        builder: (_) => DailyMusterPhotoCaptureScreen(
          title: slot == 'team' ? 'Team Photo' : 'JCB Photo',
        ),
      ),
    );
    if (result == null || _task == null) return;
    try {
      final path = await _store.persistPhoto(result.path, _task!.id, slot);
      final loc = result.location;
      final meta = <String, dynamic>{
        'localPath': path,
        'photoCapturedAt': result.photoCapturedAt.toIso8601String(),
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'accuracyMeters': loc.accuracy,
        'fixCapturedAt': (loc.capturedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'provider': loc.source.toUpperCase() == 'GPS' ? 'GPS' : 'FUSED',
        'mockLocationFlagged': loc.isMocked || loc.isTestLocation,
        'cameraLive': true,
      };
      setState(() => _photos[slot] = meta);
      await _persistLocal(status: _status.isEmpty ? 'LOCAL_DRAFT' : _status);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not save captured photo locally: $e');
      }
    }
  }

  Widget _section(String title, Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  Widget _photoTile(String slot, String label) {
    final photo = _photos[slot];
    final path = photo?['localPath']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photo != null && path != null && File(path).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              height: 145,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 90,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.photo_camera_outlined, size: 32),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _readOnly || _working ? null : () => _capturePhoto(slot),
          icon: const Icon(Icons.camera_alt),
          label: Text(photo == null ? 'Capture $label' : 'Retake $label'),
        ),
        if (photo?['mockLocationFlagged'] == true)
          const Text(
            'Mock/test location flagged; submission is blocked.',
            style: TextStyle(color: Colors.red),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status.isEmpty
        ? (_muster == null ? 'NOT STARTED' : 'LOCAL DRAFT')
        : _status.replaceAll('_', ' ');
    final rejected = _status == 'REJECTED';
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Muster')),
      body: _loading && _tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) _message(_error!, true),
                  if (_notice != null) _message(_notice!, false),
                  DropdownButtonFormField<TaskModel>(
                    initialValue: _task,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Root / Block Task',
                      border: OutlineInputBorder(),
                    ),
                    items: _tasks
                        .map(
                          (task) => DropdownMenuItem(
                            value: task,
                            child: Text(
                              '${task.displayName} · ${task.taskCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _working ? null : _selectTask,
                  ),
                  if (_task != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Today’s status: '),
                        Chip(label: Text(status)),
                        if (rejected)
                          Expanded(
                            child: Text(
                              '  ${_muster?['rejectionReason'] ?? ''}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                    if (_loading) const LinearProgressIndicator(),
                    if (_muster == null && !_canStartTask)
                      _message(
                        'This task is currently ${_task!.status}. Daily Muster can only start for CREATED, PARTIALLY_SAVED, or REJECTED tasks.',
                        true,
                      ),
                    if (!_readOnly) ...[
                      _section(
                        'Work status',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Nil-work day'),
                              subtitle: const Text(
                                'No site work was performed today',
                              ),
                              value: _nilWork,
                              onChanged: (v) {
                                setState(() => _nilWork = v);
                                _persistLocal(status: 'LOCAL_DRAFT');
                              },
                            ),
                            if (_nilWork)
                              TextFormField(
                                controller: _reason,
                                maxLength: 500,
                                decoration: const InputDecoration(
                                  labelText: 'Nil-work reason',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) =>
                                    _persistLocal(status: 'LOCAL_DRAFT'),
                              ),
                          ],
                        ),
                      ),
                      if (!_nilWork) ...[
                        _section(
                          'Team and headcount',
                          Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _teamSource,
                                decoration: const InputDecoration(
                                  labelText: 'Team source',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'VENDOR',
                                    child: Text('Vendor'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'OWN',
                                    child: Text('Own team'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'BOTH',
                                    child: Text('Both'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _teamSource = v ?? 'OWN');
                                  _persistLocal(status: 'LOCAL_DRAFT');
                                },
                              ),
                              if (_teamSource != 'OWN') ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _vendorName,
                                  decoration: const InputDecoration(
                                    labelText: 'Vendor name',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) =>
                                      _persistLocal(status: 'LOCAL_DRAFT'),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _vendorId,
                                  decoration: const InputDecoration(
                                    labelText: 'Vendor ID (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) =>
                                      _persistLocal(status: 'LOCAL_DRAFT'),
                                ),
                              ],
                              const SizedBox(height: 10),
                              ..._headcount.entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TextField(
                                    controller: entry.value,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: _label(entry.key),
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) {
                                      _persistLocal(status: 'LOCAL_DRAFT');
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _section(
                          'Resources',
                          Column(
                            children: _resources.entries
                                .map(
                                  (entry) => SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(_label(entry.key)),
                                    value: entry.value,
                                    onChanged: (v) {
                                      setState(() => _resources[entry.key] = v);
                                      _persistLocal(status: 'LOCAL_DRAFT');
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        _section(
                          'Required live evidence',
                          Column(
                            children: [
                              _photoTile('team', 'Team Photo'),
                              if (_resources['JCB'] == true) ...[
                                const Divider(height: 24),
                                _photoTile('jcb', 'JCB Photo'),
                              ],
                            ],
                          ),
                        ),
                      ],
                      _section(
                        'Remarks',
                        TextField(
                          controller: _remarks,
                          maxLength: 500,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Optional remarks',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) =>
                              _persistLocal(status: 'LOCAL_DRAFT'),
                        ),
                      ),
                      if (!_hasServerMuster && _muster == null)
                        FilledButton.icon(
                          onPressed: _working || _loading || !_canStartTask
                              ? null
                              : () => _save(),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Day'),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _working ? null : () => _save(),
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Draft'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _save(submit: true),
                                icon: _working
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: Text(
                                  _working
                                      ? 'Saving…'
                                      : rejected
                                      ? 'Resubmit'
                                      : 'Submit',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ] else
                      _section(
                        'Submission',
                        const Text(
                          'This muster has been submitted and is read-only while it is under review.',
                        ),
                      ),
                  ] else if (!_loading && _tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No root/block tasks are assigned to your account.',
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _message(String text, bool error) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? Colors.red.shade50 : Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: error ? Colors.red.shade900 : Colors.green.shade900,
      ),
    ),
  );

  String _label(String key) => key
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}')
      .replaceAll('_', ' ')
      .trim()
      .split(' ')
      .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}
