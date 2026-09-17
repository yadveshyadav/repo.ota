/// Filter state model for Team & Staff Management module
class TeamFilterModel {
  final String status; // 'ALL', 'ACTIVE', 'INACTIVE'
  final String role; // 'ALL' or specific role
  final String vendor; // 'ALL' or specific vendor name

  const TeamFilterModel({
    this.status = 'ALL',
    this.role = 'ALL',
    this.vendor = 'ALL',
  });

  bool get hasActiveFilters =>
      status != 'ALL' || role != 'ALL' || vendor != 'ALL';

  int get activeFilterCount {
    int count = 0;
    if (status != 'ALL') count++;
    if (role != 'ALL') count++;
    if (vendor != 'ALL') count++;
    return count;
  }

  TeamFilterModel copyWith({
    String? status,
    String? role,
    String? vendor,
  }) {
    return TeamFilterModel(
      status: status ?? this.status,
      role: role ?? this.role,
      vendor: vendor ?? this.vendor,
    );
  }

  TeamFilterModel reset() {
    return const TeamFilterModel();
  }
}
