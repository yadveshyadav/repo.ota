import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/services/api/breakdown_api_service.dart';

/// Report OEM / External machine breakdown.
class ReportOemBreakdownScreen extends StatefulWidget {
  final Machine machine;

  const ReportOemBreakdownScreen({super.key, required this.machine});

  @override
  State<ReportOemBreakdownScreen> createState() => _ReportOemBreakdownScreenState();
}

class _ReportOemBreakdownScreenState extends State<ReportOemBreakdownScreen> {
  final _api = BreakdownApiService();
  final _reasonController = TextEditingController();

  OemBreakdownOptions? _options;
  final Set<int> _selectedReasonIds = {};
  String _severity = 'MEDIUM';
  DateTime? _occurredAt;
  bool _loadingOptions = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _error = null;
    });
    try {
      final opts = await _api.fetchOemOptions();
      if (!mounted) return;
      setState(() {
        _options = opts;
        if (opts.severities.isNotEmpty) {
          _severity = opts.severities
              .firstWhere(
                (s) => s.value.toUpperCase() == 'MEDIUM',
                orElse: () => opts.severities.first,
              )
              .value;
        }
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickOccurredAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt ?? now,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.deepNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.deepNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final hasKeys = _selectedReasonIds.isNotEmpty;
    final hasText = _reasonController.text.trim().isNotEmpty;
    if (!hasKeys && !hasText) {
      setState(() => _error = 'Select a reason or enter a description.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await _api.createOemBreakdown(
        machineChassisNo: widget.machine.chassisNumber,
        reason: hasText ? _reasonController.text.trim() : null,
        reasonKeyIds: _selectedReasonIds.toList(),
        severity: _selectedReasonIds.isEmpty ? _severity : null,
        occurredAtIso: _occurredAt?.toIso8601String(),
      );
      if (!mounted) return;
      final ticket = created['tt_number']?.toString() ??
          (created['id'] != null ? 'BD-${created['id']}' : 'Breakdown');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ticket reported successfully'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final machine = widget.machine;
    final reasons = _options?.reasonKeys ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report OEM Breakdown',
              style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'External / OEM issue',
              style: TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MachineCard(machine: machine),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 12),
                        ],
                        _FormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Reason',
                                subtitle: reasons.isEmpty
                                    ? 'Describe the issue below'
                                    : 'Tap one or more reasons',
                              ),
                              const SizedBox(height: 8),
                              if (reasons.isEmpty)
                                const Text(
                                  'No reason catalog loaded. Use description.',
                                  style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                                )
                              else
                                _ReasonChipWrap(
                                  items: reasons,
                                  selectedIds: _selectedReasonIds,
                                  enabled: !_submitting,
                                  onToggle: (id, selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedReasonIds.add(id);
                                      } else {
                                        _selectedReasonIds.remove(id);
                                      }
                                    });
                                  },
                                ),
                              const SizedBox(height: 14),
                              _SectionHeader(
                                title: 'Description',
                                subtitle: 'Optional if a reason is selected',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _reasonController,
                                enabled: !_submitting,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 13, color: AppColors.deepNavy),
                                decoration: _inputDecoration('Add details if needed'),
                              ),
                              const SizedBox(height: 14),
                              _SectionHeader(
                                title: 'Severity',
                                subtitle: _selectedReasonIds.isNotEmpty
                                    ? 'Using highest selected reason severity'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              _SeverityDropdown(
                                value: _severity,
                                options: _options?.severities.isNotEmpty == true
                                    ? _options!.severities
                                    : const [
                                        BreakdownChoice(value: 'LOW', label: 'Low'),
                                        BreakdownChoice(value: 'MEDIUM', label: 'Medium'),
                                        BreakdownChoice(value: 'HIGH', label: 'High'),
                                        BreakdownChoice(value: 'CRITICAL', label: 'Critical'),
                                      ],
                                enabled: !_submitting && _selectedReasonIds.isEmpty,
                                onChanged: (v) {
                                  if (v != null) setState(() => _severity = v);
                                },
                              ),
                              const SizedBox(height: 14),
                              const _SectionHeader(title: 'Occurred at'),
                              const SizedBox(height: 8),
                              _DateTimePickerField(
                                value: _occurredAt,
                                emptyLabel: 'Now (server time)',
                                enabled: !_submitting,
                                onTap: _pickOccurredAt,
                                onClear: () => setState(() => _occurredAt = null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomSubmitBar(
                  label: 'Create breakdown',
                  submitting: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
    );
  }
}

/// Open Internal Ops Stop.
class OpenOpsStopScreen extends StatefulWidget {
  final Machine machine;

  const OpenOpsStopScreen({super.key, required this.machine});

  @override
  State<OpenOpsStopScreen> createState() => _OpenOpsStopScreenState();
}

class _OpenOpsStopScreenState extends State<OpenOpsStopScreen> {
  final _api = BreakdownApiService();
  final _noteController = TextEditingController();

  OpsStopOptions? _options;
  final Set<int> _selectedReasonIds = {};
  DateTime? _startedAt;
  bool _loadingOptions = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _error = null;
    });
    try {
      final opts = await _api.fetchOpsOptions();
      if (!mounted) return;
      setState(() {
        _options = opts;
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickStartedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt ?? now,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.deepNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.deepNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;
    setState(() {
      _startedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final hasKeys = _selectedReasonIds.isNotEmpty;
    final hasText = _noteController.text.trim().isNotEmpty;
    if (!hasKeys && !hasText) {
      setState(() => _error = 'Select a reason or enter a note.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await _api.createOpsStop(
        machineChassisNo: widget.machine.chassisNumber,
        note: hasText ? _noteController.text.trim() : null,
        reasonKeyIds: _selectedReasonIds.toList(),
        startedAtIso: _startedAt?.toIso8601String(),
      );
      if (!mounted) return;
      final ticket = created['tt_number']?.toString() ??
          (created['id'] != null ? 'OS-${created['id']}' : 'Ops Stop');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ticket opened successfully'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final machine = widget.machine;
    final reasons = _options?.reasonKeys ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open Ops Stop',
              style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Internal operational stop',
              style: TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MachineCard(machine: machine),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 12),
                        ],
                        _FormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'Reason',
                                subtitle: reasons.isEmpty
                                    ? 'Describe the stop below'
                                    : 'Tap one or more reasons',
                              ),
                              const SizedBox(height: 8),
                              if (reasons.isEmpty)
                                const Text(
                                  'No reason catalog loaded. Use note.',
                                  style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                                )
                              else
                                _ReasonChipWrap(
                                  items: reasons,
                                  selectedIds: _selectedReasonIds,
                                  enabled: !_submitting,
                                  onToggle: (id, selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedReasonIds.add(id);
                                      } else {
                                        _selectedReasonIds.remove(id);
                                      }
                                    });
                                  },
                                ),
                              const SizedBox(height: 14),
                              _SectionHeader(
                                title: 'Note',
                                subtitle: 'Optional if a reason is selected',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _noteController,
                                enabled: !_submitting,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 13, color: AppColors.deepNavy),
                                decoration: _inputDecoration('Why the machine is stopped'),
                              ),
                              const SizedBox(height: 14),
                              const _SectionHeader(title: 'Started at'),
                              const SizedBox(height: 8),
                              _DateTimePickerField(
                                value: _startedAt,
                                emptyLabel: 'Now (server time)',
                                enabled: !_submitting,
                                onTap: _pickStartedAt,
                                onClear: () => setState(() => _startedAt = null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomSubmitBar(
                  label: 'Open Ops Stop',
                  submitting: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
    );
  }
}

// ── Shared compact UI pieces ───────────────────────────────────────────────

class _ReasonChipWrap extends StatelessWidget {
  final List<BreakdownCatalogItem> items;
  final Set<int> selectedIds;
  final bool enabled;
  final void Function(int id, bool selected) onToggle;

  const _ReasonChipWrap({
    required this.items,
    required this.selectedIds,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((key) {
        final selected = selectedIds.contains(key.id);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onToggle(key.id, !selected) : null,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryGreen.withValues(alpha: 0.14)
                    : AppColors.softGray,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryGreen.withValues(alpha: 0.55)
                      : AppColors.borderGray,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check_rounded, size: 13, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    key.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: selected ? AppColors.primaryGreen : AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
          ),
        ],
      ],
    );
  }
}

class _SeverityDropdown extends StatelessWidget {
  final String value;
  final List<BreakdownChoice> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _SeverityDropdown({
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.deepNavy,
            ),
            items: options
                .map((s) => DropdownMenuItem(value: s.value, child: Text(s.label)))
                .toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}

class _DateTimePickerField extends StatelessWidget {
  final DateTime? value;
  final String emptyLabel;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateTimePickerField({
    required this.value,
    required this.emptyLabel,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: AppColors.mutedTextGray),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null ? emptyLabel : _formatDt(value!),
                style: TextStyle(
                  color: value == null ? AppColors.mutedTextGray : AppColors.deepNavy,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: enabled ? onClear : null,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.mutedTextGray),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y, $h:$min';
  }
}

class _BottomSubmitBar extends StatelessWidget {
  final String label;
  final bool submitting;
  final VoidCallback onPressed;

  const _BottomSubmitBar({
    required this.label,
    required this.submitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderGray.withValues(alpha: 0.8))),
        ),
        child: SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: submitting ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
    filled: true,
    fillColor: AppColors.softGray,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      borderSide: const BorderSide(color: AppColors.focusBorder, width: 1.4),
    ),
  );
}

class _MachineCard extends StatelessWidget {
  final Machine machine;

  const _MachineCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.precision_manufacturing_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  machine.chassisNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedTextGray,
                    fontFamily: 'monospace',
                  ),
                ),
                if (machine.site.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    machine.site,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.criticalRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.criticalRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.criticalRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
