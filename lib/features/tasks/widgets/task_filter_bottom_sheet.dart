import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/task_filter.dart';

class TaskFilterBottomSheet extends StatefulWidget {
  final TaskFilterModel initialFilter;
  final ValueChanged<TaskFilterModel> onApplyFilters;
  final Set<String> availableVendors;
  final Set<String> availableSupervisors;
  final Set<String> availableDistricts;
  final Set<String> availableCircles;

  const TaskFilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.onApplyFilters,
    this.availableVendors = const {},
    this.availableSupervisors = const {},
    this.availableDistricts = const {},
    this.availableCircles = const {},
  });

  static void show(
    BuildContext context, {
    required TaskFilterModel initialFilter,
    required ValueChanged<TaskFilterModel> onApplyFilters,
    Set<String> availableVendors = const {},
    Set<String> availableSupervisors = const {},
    Set<String> availableDistricts = const {},
    Set<String> availableCircles = const {},
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFilterBottomSheet(
        initialFilter: initialFilter,
        onApplyFilters: onApplyFilters,
        availableVendors: availableVendors,
        availableSupervisors: availableSupervisors,
        availableDistricts: availableDistricts,
        availableCircles: availableCircles,
      ),
    );
  }

  @override
  State<TaskFilterBottomSheet> createState() => _TaskFilterBottomSheetState();
}

class _TaskFilterBottomSheetState extends State<TaskFilterBottomSheet> {
  late TaskFilterModel _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  List<DropdownMenuItem<String>> _buildDynamicItems({
    required String defaultLabel,
    required Set<String> availableValues,
    required String selectedValue,
  }) {
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'ALL', child: Text(defaultLabel)),
    ];

    final uniqueSet = Set<String>.from(availableValues);
    if (selectedValue != 'ALL' && selectedValue.isNotEmpty && !uniqueSet.contains(selectedValue)) {
      uniqueSet.add(selectedValue);
    }

    for (final val in uniqueSet) {
      if (val.trim().isEmpty || val == 'ALL') continue;
      items.add(DropdownMenuItem(value: val, child: Text(val)));
    }
    return items;
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
                    const Icon(Icons.filter_list_rounded,
                        color: AppColors.primaryGreen, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter Tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    if (_filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.mutedTextGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderGray),

          // Scrollable Filter Sections
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownSection(
                    title: 'Task Type',
                    value: _filter.taskType,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Task Types')),
                      DropdownMenuItem(
                          value: 'FIBER_TRENCHING_DUCTING_TASK',
                          child: Text('Fiber Trenching / Ducting')),
                      DropdownMenuItem(
                          value: 'GP_SURVEY', child: Text('GP Survey')),
                      DropdownMenuItem(
                          value: 'OTDR_SURVEY', child: Text('OTDR Survey')),
                      DropdownMenuItem(
                          value: 'FIBER_SURVEY', child: Text('Fiber Survey')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = _filter.copyWith(taskType: val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownSection(
                    title: 'Status',
                    value: _filter.status,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'CREATED', child: Text('Created')),
                      DropdownMenuItem(value: 'PLANNING', child: Text('Planning')),
                      DropdownMenuItem(
                          value: 'IN_PROGRESS', child: Text('In Progress')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'APPROVAL_PENDING',
                          child: Text('Approval Pending')),
                      DropdownMenuItem(
                          value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'CANCELLED', child: Text('Cancelled')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
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

                  _buildDropdownSection(
                    title: 'Vendor',
                    value: _filter.vendor,
                    items: _buildDynamicItems(
                      defaultLabel: 'All Vendors',
                      availableValues: widget.availableVendors,
                      selectedValue: _filter.vendor,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = _filter.copyWith(vendor: val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownSection(
                    title: 'Supervisor',
                    value: _filter.supervisor,
                    items: _buildDynamicItems(
                      defaultLabel: 'All Supervisors',
                      availableValues: widget.availableSupervisors,
                      selectedValue: _filter.supervisor,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = _filter.copyWith(supervisor: val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownSection(
                          title: 'District',
                          value: _filter.district,
                          items: _buildDynamicItems(
                            defaultLabel: 'All Districts',
                            availableValues: widget.availableDistricts,
                            selectedValue: _filter.district,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _filter = _filter.copyWith(district: val);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownSection(
                          title: 'Circle',
                          value: _filter.circle,
                          items: _buildDynamicItems(
                            defaultLabel: 'All Circles',
                            availableValues: widget.availableCircles,
                            selectedValue: _filter.circle,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _filter = _filter.copyWith(circle: val);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownSection(
                          title: 'Stage',
                          value: _filter.stage,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Stages')),
                            DropdownMenuItem(
                                value: 'PLANNING', child: Text('Planning')),
                            DropdownMenuItem(
                                value: 'SURVEY', child: Text('Survey')),
                            DropdownMenuItem(
                                value: 'EXECUTION', child: Text('Execution')),
                            DropdownMenuItem(
                                value: 'REVIEW', child: Text('Review')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _filter = _filter.copyWith(stage: val);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownSection(
                          title: 'Approval Status',
                          value: _filter.approvalStatus,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All')),
                            DropdownMenuItem(
                                value: 'PENDING', child: Text('Pending')),
                            DropdownMenuItem(
                                value: 'APPROVED', child: Text('Approved')),
                            DropdownMenuItem(
                                value: 'REJECTED', child: Text('Rejected')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _filter = _filter.copyWith(approvalStatus: val);
                              });
                            }
                          },
                        ),
                      ),
                    ],
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
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              borderSide:
                  const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
