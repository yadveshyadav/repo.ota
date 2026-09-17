import 'package:flutter/material.dart';
import 'app/app.dart';
import 'features/auth/services/auth_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStorageService().init();
  runApp(const HeroApp());
}
