import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../models/role_model.dart';
import '../../../repositories/user_repository.dart';

/// Modal dialog to Create or Edit a User and assign Roles with live Union Effective Permissions view
class CreateEditUserDialog extends StatefulWidget {
  final UserModel? existingUser;
  final List<RoleModel> availableRoles;
  final UserRepository repository;

  const CreateEditUserDialog({
    super.key,
    this.existingUser,
    required this.availableRoles,
    required this.repository,
  });

  @override
  State<CreateEditUserDialog> createState() => _CreateEditUserDialogState();
}

class _CreateEditUserDialogState extends State<CreateEditUserDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  final Set<String> _selectedRoleCodes = <String>{};
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;

    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _isActive = user?.isActive ?? true;

    if (user != null) {
      if (user.roles.isNotEmpty) {
        _selectedRoleCodes.addAll(user.roles.map((r) => r.toUpperCase()));
      } else if (user.role.isNotEmpty) {
        _selectedRoleCodes.add(user.role.toUpperCase());
      }
    } else {
      if (widget.availableRoles.isNotEmpty) {
        _selectedRoleCodes.add(widget.availableRoles.first.code.toUpperCase());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Dynamic UNION calculation of effective permissions granted by selected roles
  Set<String> get _unionEffectivePermissions {
    final permissions = <String>{};
    for (final roleCode in _selectedRoleCodes) {
      final role = widget.availableRoles.firstWhere(
        (r) => r.code.toUpperCase() == roleCode.toUpperCase() || r.name.toUpperCase() == roleCode.toUpperCase(),
        orElse: () => RoleModel(id: 0, name: roleCode, code: roleCode),
      );
      if (role.permissionCodes.isNotEmpty) {
        permissions.addAll(role.permissionCodes);
      }
    }
    return permissions;
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleCodes.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one role for the user.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final rolesList = _selectedRoleCodes.toList();

      if (widget.existingUser != null) {
        await widget.repository.updateUser(
          id: widget.existingUser!.id,
          name: name,
          username: username,
          email: email,
          roles: rolesList,
          phoneNumber: phone,
          isActive: _isActive,
        );
      } else {
        await widget.repository.createUser(
          name: name,
          username: username,
          email: email,
          roles: rolesList,
          phoneNumber: phone,
          isActive: _isActive,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save user: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingUser != null;
    final media = MediaQuery.of(context).size;
    final isMobile = media.width < 640;
    final unionPerms = _unionEffectivePermissions.toList()..sort();

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: Container(
        width: 680,
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
                          Icons.person_add_alt_1_outlined,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit User Profile' : 'Add Platform User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Update account info and assign system access roles'
                                : 'Create account credentials and select authorization roles',
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

              // Form Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name & Username
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Full Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Full name required' : null,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Rahul Sharma',
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
                                const Text('Username *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _usernameController,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Username required' : null,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. rahul_s',
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

                      // Email & Phone
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Email Address *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailController,
                                  validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                                  decoration: InputDecoration(
                                    hintText: 'rahul@example.com',
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
                                const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(
                                    hintText: '+91 98765 43210',
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

                      // Account Status Switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Account Active Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                              Text('Active users can authenticate and access granted features', style: AppTextStyles.caption),
                            ],
                          ),
                          Switch(
                            value: _isActive,
                            activeThumbColor: AppColors.primaryGreen,
                            onChanged: (val) {
                              setState(() {
                                _isActive = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Roles Selection
                      const Text(
                        'Assigned Roles *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select one or multiple roles. Effective permissions will be calculated dynamically as the union of selected role capabilities.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: widget.availableRoles.map((role) {
                          final isSelected = _selectedRoleCodes.contains(role.code.toUpperCase());

                          return FilterChip(
                            label: Text(role.name),
                            selected: isSelected,
                            selectedColor: AppColors.lightGreenBg,
                            checkmarkColor: AppColors.primaryGreen,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primaryGreen : AppColors.deepNavy,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryGreen : AppColors.borderGray,
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedRoleCodes.add(role.code.toUpperCase());
                                } else {
                                  _selectedRoleCodes.remove(role.code.toUpperCase());
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Effective Permissions Section (Dynamic Union)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGray,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderGray),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primaryGreen),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Effective Permissions (Union)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deepNavy,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${unionPerms.length} Capabilities',
                                    style: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (unionPerms.isEmpty)
                              const Text(
                                'No permissions granted. Please select at least one role above.',
                                style: TextStyle(color: AppColors.mutedTextGray, fontSize: 12),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: unionPerms.map((code) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.borderGray),
                                    ),
                                    child: Text(
                                      code,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: AppColors.deepNavy,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24, color: AppColors.borderGray),

              // Action Buttons
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
                    onPressed: _isSaving ? null : _saveUser,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Save User' : 'Create User')),
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
}
