import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/permission_model.dart';
import '../../../models/role_model.dart';
import '../../../repositories/role_repository.dart';
import '../../../services/authorization_service.dart';

/// Modal dialog or full screen form to Create or Edit a Role with category-grouped permissions
class CreateEditRoleDialog extends StatefulWidget {
  final RoleModel? existingRole;
  final List<PermissionModel> allPermissions;
  final RoleRepository repository;

  const CreateEditRoleDialog({
    super.key,
    this.existingRole,
    required this.allPermissions,
    required this.repository,
  });

  @override
  State<CreateEditRoleDialog> createState() => _CreateEditRoleDialogState();
}

class _CreateEditRoleDialogState extends State<CreateEditRoleDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descController;
  late final TextEditingController _searchPermissionController;

  final Set<int> _selectedPermissionIds = <int>{};
  String _permissionSearchQuery = '';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final role = widget.existingRole;

    _nameController = TextEditingController(text: role?.name ?? '');
    _codeController = TextEditingController(text: role?.code ?? '');
    _descController = TextEditingController(text: role?.description ?? '');
    _searchPermissionController = TextEditingController();

    if (role != null) {
      _selectedPermissionIds.addAll(role.permissions);
      // Fallback matching by code if permission IDs were empty
      if (_selectedPermissionIds.isEmpty && role.permissionCodes.isNotEmpty) {
        for (final p in widget.allPermissions) {
          if (role.permissionCodes.contains(p.code)) {
            _selectedPermissionIds.add(p.id);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _searchPermissionController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (widget.existingRole == null) {
      _codeController.text = val.trim().toUpperCase().replaceAll(' ', '_');
    }
  }

  Map<String, List<PermissionModel>> get _groupedPermissions {
    final Map<String, List<PermissionModel>> map = {};
    for (final perm in widget.allPermissions) {
      if (_permissionSearchQuery.isNotEmpty) {
        final q = _permissionSearchQuery.toLowerCase();
        final matches = perm.name.toLowerCase().contains(q) ||
            perm.code.toLowerCase().contains(q) ||
            perm.category.toLowerCase().contains(q) ||
            perm.description.toLowerCase().contains(q);
        if (!matches) continue;
      }

      final cat = perm.category.isNotEmpty ? perm.category : 'General';
      map.putIfAbsent(cat, () => []).add(perm);
    }
    return map;
  }

  void _toggleCategoryAll(List<PermissionModel> perms, bool selectAll) {
    setState(() {
      for (final p in perms) {
        if (selectAll) {
          _selectedPermissionIds.add(p.id);
        } else {
          _selectedPermissionIds.remove(p.id);
        }
      }
    });
  }

  void _selectAllFiltered() {
    setState(() {
      for (final catList in _groupedPermissions.values) {
        for (final p in catList) {
          _selectedPermissionIds.add(p.id);
        }
      }
    });
  }

  void _clearAllFiltered() {
    setState(() {
      for (final catList in _groupedPermissions.values) {
        for (final p in catList) {
          _selectedPermissionIds.remove(p.id);
        }
      }
    });
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final code = _codeController.text.trim();
      final desc = _descController.text.trim();
      final permIds = _selectedPermissionIds.toList();

      if (widget.existingRole != null) {
        await widget.repository.updateRole(
          id: widget.existingRole!.id,
          name: name,
          code: code,
          description: desc,
          permissionIds: permIds,
        );
      } else {
        await widget.repository.createRole(
          name: name,
          code: code,
          description: desc,
          permissionIds: permIds,
        );
      }

      // Refresh Authorization Service state if current user belongs to this role
      final currentUser = AuthorizationService.instance.currentUser;
      if (currentUser != null && currentUser.roles.map((r) => r.toUpperCase()).contains(code.toUpperCase())) {
        final allRoles = await widget.repository.getRoles();
        AuthorizationService.instance.initialize(user: currentUser, roles: allRoles);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save role: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRole != null;
    final media = MediaQuery.of(context).size;
    final isMobile = media.width < 640;

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: Container(
        width: 760,
        constraints: BoxConstraints(maxHeight: media.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Role' : 'Create Custom Role',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Update role capabilities and permissions'
                                : 'Configure role details and grant module permissions',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.mutedTextGray),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.borderGray),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.criticalRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.criticalRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.criticalRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Main Form Fields & Permission Picker
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Role Info Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Role Name *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  onChanged: _onNameChanged,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Role name required' : null,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Site Supervisor',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Role Code *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _codeController,
                                  readOnly: widget.existingRole?.isSystem == true,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Role code required' : null,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. SITE_SUPERVISOR',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Describe responsibilities and access limits for this role...',
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Permissions Header & Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Role Permissions',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_selectedPermissionIds.length} Selected',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _selectAllFiltered,
                                child: const Text('Select All', style: TextStyle(fontSize: 12, color: AppColors.primaryGreen)),
                              ),
                              TextButton(
                                onPressed: _clearAllFiltered,
                                child: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Search Permissions Bar
                      TextField(
                        controller: _searchPermissionController,
                        onChanged: (val) {
                          setState(() {
                            _permissionSearchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search permissions by name, category, or code...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.mutedTextGray),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: AppColors.backgroundGray,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grouped Permission Categories
                      if (_groupedPermissions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No permissions match your search query',
                              style: TextStyle(color: AppColors.mutedTextGray),
                            ),
                          ),
                        )
                      else
                        for (final entry in _groupedPermissions.entries) ...[
                          _buildPermissionCategoryGroup(entry.key, entry.value),
                          const SizedBox(height: 16),
                        ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 24, color: AppColors.borderGray),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: const BorderSide(color: AppColors.borderGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.deepNavy)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveRole,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Create Role')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCategoryGroup(String categoryName, List<PermissionModel> perms) {
    final categorySelectedCount = perms.where((p) => _selectedPermissionIds.contains(p.id)).length;
    final isAllSelected = categorySelectedCount == perms.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      categoryName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($categorySelectedCount/${perms.length})',
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _toggleCategoryAll(perms, !isAllSelected),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isAllSelected ? 'Deselect All' : 'Select Category',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderGray),

          // Category Permissions Grid / Checkboxes
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: perms.map((perm) {
                final isChecked = _selectedPermissionIds.contains(perm.id);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isChecked) {
                        _selectedPermissionIds.remove(perm.id);
                      } else {
                        _selectedPermissionIds.add(perm.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isChecked ? AppColors.lightGreenBg : AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isChecked ? AppColors.primaryGreen : AppColors.borderGray,
                        width: isChecked ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: isChecked,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPermissionIds.add(perm.id);
                                } else {
                                  _selectedPermissionIds.remove(perm.id);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                perm.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                  color: isChecked ? AppColors.primaryGreen : AppColors.deepNavy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                perm.code,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mutedTextGray,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
