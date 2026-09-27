import 'package:flutter/material.dart';
import 'package:hero_app/app/routes.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/screens/breakdown/close_open_issues_screen.dart';
import 'package:hero_app/screens/breakdown/machine_issue_screens.dart';
import 'package:hero_app/services/api/breakdown_api_service.dart';
import 'package:hero_app/widgets/machines/machine_card_widget.dart';

/// Machine Breakdown Dashboard & Listing screen.
/// Displays real-time breakdown status of machines with red blinking indicators
/// matching machine attendance, allowing users to report or resolve issues.
class BreakdownMachinesScreen extends StatefulWidget {
  final MachineRepository? repository;

  const BreakdownMachinesScreen({super.key, this.repository});

  @override
  State<BreakdownMachinesScreen> createState() => _BreakdownMachinesScreenState();
}

class _BreakdownMachinesScreenState extends State<BreakdownMachinesScreen>
    with SingleTickerProviderStateMixin {
  late final MachineRepository _repository;
  final _breakdownApi = BreakdownApiService();
  final _searchController = TextEditingController();

  late final AnimationController _blinkController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Machine> _allMachines = [];
  List<Machine> _filteredMachines = [];
  Map<String, MachineOpenIssuesBucket> _openByChassis = {};

  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // All | Under Breakdown | Working

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMachineRepository();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fetchMachines();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMachines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var machines = await _repository.getAllMachines();
      if (!mounted) return;

      final user = AuthStorageService().currentUser;
      if (user != null) {
        final vendorNameClean = user.vendorName?.trim().toLowerCase();
        final vendorNames = (user.vendors.isNotEmpty)
            ? user.vendors
                .map((v) => v['name']?.toString().toLowerCase())
                .whereType<String>()
                .toSet()
            : <String>{};

        if (vendorNameClean != null && vendorNameClean.isNotEmpty && vendorNameClean != 'unassigned vendor') {
          vendorNames.add(vendorNameClean);
        }

        if (vendorNames.isNotEmpty) {
          final filteredByVendor = machines.where((m) {
            final mVendor = m.vendorName?.toLowerCase();
            if (mVendor == null || mVendor.isEmpty) return true;
            return vendorNames.contains(mVendor) ||
                vendorNames.any((v) => mVendor.contains(v) || v.contains(mVendor));
          }).toList();

          if (filteredByVendor.isNotEmpty) {
            machines = filteredByVendor;
          }
        }
      }

      // Fetch open breakdown issues for all machines
      final chassisList = machines
          .map((m) => m.chassisNumber)
          .where((c) => c.isNotEmpty && c != 'N/A')
          .toSet()
          .toList();

      Map<String, MachineOpenIssuesBucket> openByChassis = {};
      if (chassisList.isNotEmpty) {
        try {
          final result = await _breakdownApi.fetchOpenIssues(chassisList: chassisList);
          openByChassis = Map<String, MachineOpenIssuesBucket>.from(result.byChassis);
          for (final row in result.results) {
            if (row.machineChassisNo.isNotEmpty) {
              openByChassis[row.machineChassisNo] = row;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _allMachines = machines;
        _openByChassis = openByChassis;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  MachineOpenIssuesBucket? _issuesFor(Machine machine) {
    final chassisList = [
      machine.chassisNumber,
      machine.machineChassisNo,
      if (machine.serialNumber != null) machine.serialNumber!,
      if (machine.id.isNotEmpty) machine.id,
    ].where((c) => c.isNotEmpty && c != 'N/A').toSet();

    for (final c in chassisList) {
      if (_openByChassis.containsKey(c)) return _openByChassis[c];
      final lower = c.toLowerCase().trim();
      for (final entry in _openByChassis.entries) {
        final keyLower = entry.key.toLowerCase().trim();
        if (keyLower == lower ||
            (keyLower.isNotEmpty && (keyLower.contains(lower) || lower.contains(keyLower)))) {
          return entry.value;
        }
      }
    }
    return null;
  }

  int get _breakdownCount {
    return _allMachines.where((m) {
      final bucket = _issuesFor(m);
      return bucket?.hasOpenIssue == true || m.isMaintenance || m.isUnderBreakdown;
    }).length;
  }

  int get _workingCount => _allMachines.length - _breakdownCount;

  void _applyFilters() {
    setState(() {
      final q = _searchQuery.trim().toLowerCase();
      final filter = _selectedStatusFilter.toLowerCase();

      _filteredMachines = _allMachines.where((machine) {
        final bucket = _issuesFor(machine);
        final hasOpen = bucket?.hasOpenIssue == true || machine.isMaintenance;

        // 1. Status Pill Filter
        if (filter == 'under breakdown' && !hasOpen) {
          return false;
        } else if (filter == 'working' && hasOpen) {
          return false;
        }

        // 2. Search Query Filter
        if (q.isEmpty) return true;

        return machine.chassisNumber.toLowerCase().contains(q) ||
            machine.machineName.toLowerCase().contains(q) ||
            machine.model.toLowerCase().contains(q) ||
            machine.site.toLowerCase().contains(q) ||
            machine.operatorName.toLowerCase().contains(q) ||
            machine.displayName.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _onMachineTap(Machine machine) async {
    final openBucket = _issuesFor(machine);
    final hasOpenIssue = openBucket?.hasOpenIssue == true;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            machine.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          Text(
                            'Chassis: ${machine.chassisNumber}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedTextGray,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasOpenIssue)
                      FadeTransition(
                        opacity: _blinkController.drive(CurveTween(curve: Curves.easeInOut)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.criticalRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.criticalRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'UNDER BREAKDOWN',
                                style: TextStyle(
                                  color: AppColors.criticalRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasOpenIssue && openBucket != null && openBucket.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.criticalRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.criticalRed.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OPEN ISSUES (${openBucket.openCount})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.criticalRed,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...openBucket.issues.map((issue) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 6, color: AppColors.criticalRed),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${issue.isOem ? 'OEM' : 'Ops'} Ticket ${issue.ttNumber ?? ''}: ${issue.reason}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.deepNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (hasOpenIssue && openBucket != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop('resolve'),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: const Text(
                        'Resolve & Close Open Issues',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('oem'),
                    icon: const Icon(Icons.build_circle_outlined, size: 20),
                    label: const Text(
                      'Report OEM Breakdown (External)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasOpenIssue ? AppColors.deepNavy : AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('ops'),
                    icon: const Icon(Icons.handyman_outlined, size: 20),
                    label: const Text(
                      'Report Ops Stop (Internal)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepNavy,
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'resolve' && openBucket != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CloseOpenIssuesScreen(
            machine: machine,
            initialBucket: openBucket,
          ),
        ),
      );
      if (mounted) {
        _fetchMachines();
      }
      return;
    }

    final isExternal = action == 'oem';
    final reported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => isExternal
            ? ReportOemBreakdownScreen(machine: machine)
            : OpenOpsStopScreen(machine: machine),
      ),
    );

    if (!mounted) return;
    _fetchMachines();

    if (reported == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExternal
                ? 'OEM breakdown reported for ${machine.displayName}'
                : 'Ops stop opened for ${machine.displayName}',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: InkWell(
          onTap: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.dashboard,
              (route) => false,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breakdown Management',
                  style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Live status & issue reporting for fleet machines',
                  style: TextStyle(color: AppColors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: _isLoading ? null : _fetchMachines,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
              style: const TextStyle(fontSize: 13, color: AppColors.deepNavy),
              decoration: InputDecoration(
                hintText: 'Search chassis, model, site…',
                hintStyle: const TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedTextGray, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _applyFilters();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.focusBorder, width: 1.4),
                ),
              ),
            ),
          ),

          // Status Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterPill('All', 'All (${_allMachines.length})'),
                const SizedBox(width: 8),
                _buildFilterPill(
                  'Under Breakdown',
                  'Under Breakdown ($_breakdownCount)',
                  isDanger: true,
                ),
                const SizedBox(width: 8),
                _buildFilterPill('Working', 'Working ($_workingCount)'),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key, String label, {bool isDanger = false}) {
    final isSelected = _selectedStatusFilter.toLowerCase() == key.toLowerCase();
    final activeBg = isDanger ? AppColors.criticalRed : AppColors.deepNavy;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatusFilter = key;
        });
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBg : AppColors.borderGray,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDanger && _breakdownCount > 0) ...[
              FadeTransition(
                opacity: _blinkController.drive(CurveTween(curve: Curves.easeInOut)),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.white : AppColors.criticalRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.white : AppColors.deepNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.criticalRed, size: 36),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.criticalRed, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _fetchMachines,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredMachines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 42, color: AppColors.mutedTextGray),
            const SizedBox(height: 12),
            Text(
              _selectedStatusFilter.toLowerCase() == 'under breakdown'
                  ? 'No machines under breakdown'
                  : 'No machines found',
              style: const TextStyle(color: AppColors.deepNavy, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try clearing search or changing status filter.',
              style: TextStyle(color: AppColors.mutedTextGray, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _fetchMachines,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filteredMachines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final machine = _filteredMachines[index];
          final openBucket = _issuesFor(machine);
          final hasOpenIssue = openBucket?.hasOpenIssue == true || machine.isMaintenance;
          final openCount = openBucket?.openCount ?? (machine.isMaintenance ? 1 : 0);
          final topIssue = (openBucket?.issues.isNotEmpty == true) ? openBucket!.issues.first : null;

          return MachineCardWidget(
            machine: machine,
            hasOpenIssue: hasOpenIssue,
            openCount: openCount,
            topIssue: topIssue,
            blinkController: _blinkController,
            onTap: () => _onMachineTap(machine),
          );
        },
      ),
    );
  }
}

