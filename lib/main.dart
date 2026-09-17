import 'package:flutter/material.dart';
import 'app/app.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStorageService().init();
  if (AuthStorageService().isLoggedIn) {
    AppLocationService.instance.warmUpAccurateLocation(silent: true);
  }
  runApp(const HeroApp());
}
