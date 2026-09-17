import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Combined search input and status filter chips bar.
class LiveStatusFilterBar extends StatefulWidget {
  final String searchQuery;
  final String selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterSelected;

  const LiveStatusFilterBar({
    super.key,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterSelected,
  });

  @override
  State<LiveStatusFilterBar> createState() => _LiveStatusFilterBarState();
}

class _LiveStatusFilterBarState extends State<LiveStatusFilterBar> {
  late final TextEditingController _searchController;

  static const List<String> _filters = [
    'All',
    'Online',
    'Offline',
    'Moving',
    'Working',
    'Idle',
    'Key on',
    'Battery',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant LiveStatusFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search TextField
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray, width: 1),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Find chassis, model, or site...',
              hintStyle: const TextStyle(
                color: AppColors.mutedTextGray,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.mutedTextGray,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = widget.selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  child: InkWell(
                    onTap: () => widget.onFilterSelected(filter),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.borderGray,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.deepNavy,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
