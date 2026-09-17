/// Filter state model for Task Management module
class TaskFilterModel {
  final String taskType;
  final String status;
  final String vendor;
  final String supervisor;
  final String district;
  final String circle;
  final String stage;
  final String approvalStatus;

  const TaskFilterModel({
    this.taskType = 'ALL',
    this.status = 'ALL',
    this.vendor = 'ALL',
    this.supervisor = 'ALL',
    this.district = 'ALL',
    this.circle = 'ALL',
    this.stage = 'ALL',
    this.approvalStatus = 'ALL',
  });

  bool get hasActiveFilters =>
      taskType != 'ALL' ||
      status != 'ALL' ||
      vendor != 'ALL' ||
      supervisor != 'ALL' ||
      district != 'ALL' ||
      circle != 'ALL' ||
      stage != 'ALL' ||
      approvalStatus != 'ALL';

  int get activeFilterCount {
    int count = 0;
    if (taskType != 'ALL') count++;
    if (status != 'ALL') count++;
    if (vendor != 'ALL') count++;
    if (supervisor != 'ALL') count++;
    if (district != 'ALL') count++;
    if (circle != 'ALL') count++;
    if (stage != 'ALL') count++;
    if (approvalStatus != 'ALL') count++;
    return count;
  }

  TaskFilterModel copyWith({
    String? taskType,
    String? status,
    String? vendor,
    String? supervisor,
    String? district,
    String? circle,
    String? stage,
    String? approvalStatus,
  }) {
    return TaskFilterModel(
      taskType: taskType ?? this.taskType,
      status: status ?? this.status,
      vendor: vendor ?? this.vendor,
      supervisor: supervisor ?? this.supervisor,
      district: district ?? this.district,
      circle: circle ?? this.circle,
      stage: stage ?? this.stage,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  TaskFilterModel reset() {
    return const TaskFilterModel();
  }
}
