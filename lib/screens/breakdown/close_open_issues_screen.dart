import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/services/api/breakdown_api_service.dart';

/// Close & verify open OEM breakdowns / Ops stops before machine attendance.
class CloseOpenIssuesScreen extends StatefulWidget {
  final Machine machine;
  final MachineOpenIssuesBucket initialBucket;

  const CloseOpenIssuesScreen({
    super.key,
    required this.machine,
    required this.initialBucket,
  });

  @override
  State<CloseOpenIssuesScreen> createState() => _CloseOpenIssuesScreenState();
}

class _CloseOpenIssuesScreenState extends State<CloseOpenIssuesScreen> {
  final _api = BreakdownApiService();
  late List<MachineOpenIssue> _issues;
  final Map<int, TextEditingController> _noteControllers = {};
  final Set<int> _closingIds = {};
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _issues = List<MachineOpenIssue>.from(widget.initialBucket.issues);
    for (final issue in _issues) {
      _noteControllers[issue.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final result = await _api.fetchOpenIssues(
        machineChassisNo: widget.machine.chassisNumber,
      );
      final bucket = result.forChassis(widget.machine.chassisNumber);
      final next = bucket?.issues ?? const <MachineOpenIssue>[];
      if (!mounted) return;

      // dispose removed controllers
      final keepIds = next.map((e) => e.id).toSet();
      _noteControllers.keys.where((id) => !keepIds.contains(id)).toList().forEach((id) {
        _noteControllers.remove(id)?.dispose();
      });
      for (final issue in next) {
        _noteControllers.putIfAbsent(issue.id, TextEditingController.new);
      }

      setState(() {
        _issues = List<MachineOpenIssue>.from(next);
        _refreshing = false;
      });

      if (_issues.isEmpty && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _closeIssue(MachineOpenIssue issue) async {
    final note = (_noteControllers[issue.id]?.text ?? '').trim();
    if (note.isEmpty) {
      setState(() => _error = 'Enter a close / resolution note for ${issue.ttNumber ?? issue.id}.');
      return;
    }

    setState(() {
      _closingIds.add(issue.id);
      _error = null;
    });

    try {
      if (issue.isOem) {
        await _api.closeOemBreakdown(
          breakdownId: issue.id,
          resolutionNote: note,
          machineChassisNo: widget.machine.chassisNumber,
        );
      } else {
        await _api.closeOpsStop(
          opsStopId: issue.id,
          closeNote: note,
          machineChassisNo: widget.machine.chassisNumber,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${issue.ttNumber ?? issue.kind} closed'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _closingIds.remove(issue.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final machine = widget.machine;
    final allClear = _issues.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Close open issues',
              style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Verify before marking attendance',
              style: TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.criticalRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chassis: ${machine.chassisNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedTextGray,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  allClear
                      ? 'All open issues are closed. You can continue to attendance.'
                      : 'This machine has ${_issues.length} open ticket(s). Close and verify each before marking attendance.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: allClear ? AppColors.primaryGreen : AppColors.criticalRed,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.criticalRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.criticalRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _refreshing && _issues.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : allClear
                    ? const Center(
                        child: Text(
                          'No open issues',
                          style: TextStyle(color: AppColors.mutedTextGray, fontWeight: FontWeight.w600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _issues.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final issue = _issues[index];
                          final closing = _closingIds.contains(issue.id);
                          final controller = _noteControllers[issue.id]!;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: issue.isOem
                                            ? const Color(0xFFFFF7ED)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: issue.isOem
                                              ? const Color(0xFFFED7AA)
                                              : const Color(0xFFBFDBFE),
                                        ),
                                      ),
                                      child: Text(
                                        issue.isOem ? 'OEM Breakdown' : 'Ops Stop',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: issue.isOem
                                              ? const Color(0xFFC2410C)
                                              : const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      issue.ttNumber ?? '#${issue.id}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deepNavy,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  issue.reason.isNotEmpty ? issue.reason : 'No reason provided',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.deepNavy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: controller,
                                  enabled: !closing,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: issue.isOem
                                        ? 'Resolution note (required)'
                                        : 'Close note (required)',
                                    hintStyle: const TextStyle(
                                      color: AppColors.mutedTextGray,
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.backgroundGray,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.borderGray),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.borderGray),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.focusBorder,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: closing ? null : () => _closeIssue(issue),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.criticalRed,
                                      foregroundColor: AppColors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: closing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Close & verify',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: allClear && !_refreshing
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.borderGray,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    allClear ? 'Continue to attendance' : 'Close all issues to continue',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
