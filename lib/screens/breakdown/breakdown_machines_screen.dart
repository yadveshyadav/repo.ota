import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/repositories/machine_repository.dart';
import 'package:hero_app/screens/breakdown/machine_issue_screens.dart';
import 'package:hero_app/widgets/machines/machine_card_widget.dart';

/// First page from Dashboard → Breakdown card.
/// Lists all machines; tapping one opens OEM breakdown (or Ops Stop).
class BreakdownMachinesScreen extends StatefulWidget {
  final MachineRepository? repository;

  const BreakdownMachinesScreen({super.key, this.repository});

  @override
  State<BreakdownMachinesScreen> createState() => _BreakdownMachinesScreenState();
}

class _BreakdownMachinesScreenState extends State<BreakdownMachinesScreen> {
  late final MachineRepository _repository;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Machine> _allMachines = [];
  List<Machine> _filteredMachines = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiMachineRepository();
    _fetchMachines();
  }

  @override
  void dispose() {
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
      if (user != null && user.isVendorUser && user.vendors.isNotEmpty) {
        final vendorNames = user.vendors
            .map((v) => v['name']?.toString().toLowerCase())
            .whereType<String>()
            .toSet();

        machines = machines.where((m) {
          final mVendor = m.vendorName?.toLowerCase();
          if (mVendor == null) return false;
          return vendorNames.contains(mVendor) ||
              vendorNames.any((v) => mVendor.contains(v));
        }).toList();
      }

      setState(() {
        _allMachines = machines;
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

  void _applyFilters() {
    setState(() {
      final q = _searchQuery.trim().toLowerCase();
      _filteredMachines = _allMachines.where((machine) {
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
    final isExternal = await showModalBottomSheet<bool>(
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
                const Text(
                  'Report issue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  machine.displayName,
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedTextGray),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chassis: ${machine.chassisNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedTextGray,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.build_circle_outlined, size: 20),
                    label: const Text(
                      'External (OEM Breakdown)',
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
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.handyman_outlined, size: 20),
                    label: const Text(
                      'Internal (Ops Stop)',
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

    if (!mounted || isExternal == null) return;

    final reported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => isExternal
            ? ReportOemBreakdownScreen(machine: machine)
            : OpenOpsStopScreen(machine: machine),
      ),
    );

    if (!mounted || reported != true) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppColors.headerGreen,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Breakdown',
              style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Select a machine to report OEM / Ops issue',
              style: TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _isLoading
                      ? 'Loading machines…'
                      : '${_filteredMachines.length} machine${_filteredMachines.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedTextGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
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
      return const Center(
        child: Text(
          'No machines found',
          style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13),
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
          return MachineCardWidget(
            machine: machine,
            onTap: () => _onMachineTap(machine),
          );
        },
      ),
    );
  }
}
