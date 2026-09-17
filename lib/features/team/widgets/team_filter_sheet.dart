import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/team_filter.dart';

class TeamFilterSheet extends StatefulWidget {
  final TeamFilterModel initialFilter;
  final List<String> availableRoles;
  final List<String> availableVendors;
  final ValueChanged<TeamFilterModel> onApplyFilters;

  const TeamFilterSheet({
    super.key,
    required this.initialFilter,
    required this.availableRoles,
    required this.availableVendors,
    required this.onApplyFilters,
  });

  static void show(
    BuildContext context, {
    required TeamFilterModel initialFilter,
    required List<String> availableRoles,
    required List<String> availableVendors,
    required ValueChanged<TeamFilterModel> onApplyFilters,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeamFilterSheet(
        initialFilter: initialFilter,
        availableRoles: availableRoles,
        availableVendors: availableVendors,
        onApplyFilters: onApplyFilters,
      ),
    );
  }

  @override
  State<TeamFilterSheet> createState() => _TeamFilterSheetState();
}

class _TeamFilterSheetState extends State<TeamFilterSheet> {
  late TeamFilterModel _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, color: AppColors.primaryGreen, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter Team Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    if (_filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filter.activeFilterCount}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.mutedTextGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderGray),

          // Scrollable Filter Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  _buildDropdownSection(
                    title: 'Status',
                    value: _filter.status,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                      DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = _filter.copyWith(status: val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role Filter (Dynamic from API)
                  _buildDropdownSection(
                    title: 'Role / Designation',
                    value: _filter.role,
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
                      ...widget.availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = _filter.copyWith(role: val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Vendor Filter (Dynamic from API)
                  _buildDropdownSection(
                    title: 'Assigned Vendor',
                    value: _filter.vendor,
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Vendors')),
                      ...widget.availableVendors.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = _filter.copyWith(vendor: val);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.borderGray, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _filter = _filter.reset();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: AppColors.deepNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApplyFilters(_filter);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = items.any((i) => i.value == value) ? value : 'ALL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: validValue,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: AppColors.softGray.withValues(alpha: 0.5),
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
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
