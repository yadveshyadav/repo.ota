import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../screens/dashboard/dashboard_screen.dart';
import '../../../../services/authorization_service.dart';
import '../../../../shared/widgets/industrial_machine_graphic.dart';
import '../../services/auth_storage_service.dart';
import '../widgets/hero_logo.dart';
import 'login_screen.dart';

/// Ultra-smooth Industrial Splash Screen with persistent display timing & entrance animations
class SplashScreen extends StatefulWidget {
  final AuthRepository? repository;
  final bool checkForUpdatesOnLaunch;

  const SplashScreen({
    super.key,
    this.repository,
    this.checkForUpdatesOnLaunch = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _machineOpacity;
  late final Animation<Offset> _machineSlide;

  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.repository ?? ApiAuthRepository();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Sequence 1: Logo Fade + Soft Spring Scale + Downward Slide
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutBack),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // Sequence 2: Tagline Fade + Upward Slide
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // Sequence 3: Heavy Machine Graphic Fade + Gentle Upward Glide
    _machineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _machineSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Start background auth check & minimum display timer concurrently
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Guarantees the splash screen remains visible for at least 3.2 seconds
      await Future.wait([
        AuthStorageService().init(),
        Future.delayed(const Duration(milliseconds: AppConstants.splashDurationMs)),
      ]);

      if (!mounted) return;

      if (_authRepository.isLoggedIn()) {
        final currentUser = await _authRepository.getCurrentUser();
        if (currentUser != null) {
          AuthorizationService.instance.initialize(user: currentUser);
          _navigateToRoute(AppRoutes.dashboard);
          return;
        }
      }

      _navigateToRoute(AppRoutes.login);
    } catch (_) {
      _navigateToRoute(AppRoutes.login);
    }
  }

  void _navigateToRoute(String routeName) {
    if (!mounted) return;

    Widget targetScreen;
    if (routeName == AppRoutes.dashboard) {
      targetScreen = const DashboardScreen();
    } else {
      targetScreen = LoginScreen(
        checkForUpdatesOnLaunch: widget.checkForUpdatesOnLaunch,
      );
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Lower Heavy Machine Background Graphic with smooth slide & fade
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: _machineOpacity,
                child: SlideTransition(
                  position: _machineSlide,
                  child: IndustrialMachineGraphic(
                    opacity: 0.95,
                    height: (responsive.height * 0.44).clamp(240.0, 420.0),
                  ),
                ),
              ),
            ),

            // Top / Center Branding Content
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: responsive.height * 0.12),

                  // HERO APP Shield Logo with smooth spring scale & slide
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: SlideTransition(
                          position: _logoSlide,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: const HeroLogo(
                              width: 140.0,
                              useShieldLogo: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Tagline with smooth slide & fade
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Smart Operations.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B3445),
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Stronger Performance.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B3445),
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
