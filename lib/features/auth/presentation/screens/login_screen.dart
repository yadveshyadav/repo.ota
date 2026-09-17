import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/update/services/ota_update_service.dart';
import '../../../../core/update/widgets/ota_update_dialogs.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../shared/widgets/custom_checkbox.dart';
import '../../controller/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/hero_logo.dart';
import '../widgets/primary_button.dart';

/// Professional Industrial Login Screen with real API authentication integration & OTA App Update menu
class LoginScreen extends StatefulWidget {
  final AuthRepository? repository;
  final AuthController? controller;

  const LoginScreen({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthController _authController;

  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _infoMessage;

  String _installedVersionName = AppConstants.appVersion;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _authController = widget.controller ??
        AuthController(
          repository: widget.repository ?? ApiAuthRepository(),
        );
    _authController.addListener(_onAuthStateChanged);
    _loadInstalledVersion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OtaUpdateDialogs.performAppUpdateCheck(context, isManualCheck: false);
      }
    });
  }

  Future<void> _loadInstalledVersion() async {
    final info = await OtaUpdateService().getInstalledAppInfo();
    if (mounted) {
      setState(() {
        _installedVersionName = info.version;
      });
    }
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _authController.removeListener(_onAuthStateChanged);
    if (widget.controller == null) {
      _authController.dispose();
    }
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _onForgotPasswordTapped() {
    setState(() {
      _infoMessage = AppConstants.forgotPasswordNotice;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppConstants.forgotPasswordNotice),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleCheckForUpdates() async {
    OtaUpdateDialogs.performAppUpdateCheck(context, isManualCheck: true);
  }

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _infoMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _authController.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.authFutureNotice),
          backgroundColor: AppColors.darkHeroGreen,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isLoading = _authController.isLoading;
    final errorMessage = _authController.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.horizontalPadding(),
            vertical: 16.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: responsive.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  32,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overflow Menu Bar (Three-dot ⋮)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isCheckingUpdate)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          )
                        else
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: AppColors.deepNavy,
                              size: 24,
                            ),
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              if (value == 'update') {
                                _handleCheckForUpdates();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'update',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.system_update_rounded,
                                      size: 18,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Check for Updates',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deepNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                enabled: false,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: AppColors.mutedTextGray,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'App Version $_installedVersionName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedTextGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    SizedBox(height: responsive.verticalSpacing(0.01)),

                    // Top Branding
                    Center(
                      child: HeroLogo(
                        width: responsive.logoWidth(isCompact: true),
                      ),
                    ),

                    SizedBox(height: responsive.verticalSpacing(0.04)),

                    // Welcome Text
                    const Text(
                      AppConstants.welcomeBack,
                      style: AppTextStyles.headingLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      AppConstants.signInSubtitle,
                      style: AppTextStyles.bodyMedium,
                    ),

                    SizedBox(height: responsive.verticalSpacing(0.03)),

                    // Inline Error / Info Banner
                    if (errorMessage != null) ...[
                      _MessageBanner(
                        message: errorMessage,
                        isError: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_infoMessage != null && errorMessage == null) ...[
                      _MessageBanner(
                        message: _infoMessage!,
                        isError: false,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Username / Email Field
                    AuthTextField(
                      label: AppConstants.emailOrUsernameLabel,
                      hint: AppConstants.emailOrUsernameHint,
                      controller: _usernameController,
                      leadingIcon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppConstants.emailRequired;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password Field
                    AuthTextField(
                      label: AppConstants.passwordLabel,
                      hint: AppConstants.passwordHint,
                      controller: _passwordController,
                      leadingIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      onFieldSubmitted: (_) => _handleSignIn(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.mutedTextGray,
                          size: 22,
                        ),
                        onPressed: _togglePasswordVisibility,
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppConstants.passwordRequired;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Options Row: Remember Me & Forgot Password
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        CustomCheckboxRow(
                          value: _rememberMe,
                          onChanged: isLoading
                              ? (_) {}
                              : (val) {
                                  setState(() {
                                    _rememberMe = val ?? false;
                                  });
                                },
                          label: AppConstants.rememberMe,
                        ),
                        TextButton(
                          onPressed: isLoading ? null : _onForgotPasswordTapped,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(48, 40),
                          ),
                          child: const Text(
                            AppConstants.forgotPassword,
                            style: AppTextStyles.labelMedium,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: responsive.verticalSpacing(0.03)),

                    // Sign In Primary Button
                    PrimaryButton(
                      text: AppConstants.signInButton,
                      isLoading: isLoading,
                      onPressed: _handleSignIn,
                    ),

                    SizedBox(height: responsive.verticalSpacing(0.02)),

                    // Bottom Footer Branding & Version Info
                    Center(
                      child: Text(
                        '${AppConstants.appName} v$_installedVersionName • Heavy Equipment Monitoring',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: responsive.verticalSpacing(0.01)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper banner for displaying inline feedback & error messages
class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isError
        ? AppColors.errorRed.withValues(alpha: 0.08)
        : AppColors.darkHeroGreen.withValues(alpha: 0.08);
    final borderColor = isError ? AppColors.errorRed : AppColors.darkHeroGreen;
    final iconColor = isError ? AppColors.errorRed : AppColors.darkHeroGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isError ? AppColors.errorRed : AppColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
