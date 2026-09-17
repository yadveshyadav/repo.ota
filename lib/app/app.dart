import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_globals.dart';
import '../features/auth/services/auth_storage_service.dart';
import 'routes.dart';

/// Root Application Widget for HERO APP with Lifecycle Activity Observation
class HeroApp extends StatefulWidget {
  const HeroApp({super.key});

  @override
  State<HeroApp> createState() => _HeroAppState();
}

class _HeroAppState extends State<HeroApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuthStorageService().init().then((_) {
        if (AuthStorageService().isLoggedIn) {
          AuthStorageService().touchLastActive();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.setLightSystemUiOverlay();

    return MaterialApp(
      navigatorKey: AppGlobals.navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      routes: AppRoutes.routes,
    );
  }
}
