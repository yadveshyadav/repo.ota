import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/app/app.dart';
import 'package:hero_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets(
    'Generate previews for Splash and Login screens',
    (WidgetTester tester) async {
    // Set standard high-density mobile resolution (390 x 844 at 3x pixel ratio)
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;

    final artifactsDir = Directory.systemTemp.createTempSync(
      'hero_screen_previews_',
    );
    addTearDown(() {
      if (artifactsDir.existsSync()) {
        artifactsDir.deleteSync(recursive: true);
      }
    });

    // 1. Capture Splash Screen
    final boundaryKeySplash = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKeySplash,
        child: const HeroApp(),
      ),
    );

    // Advance animation partially to capture active splash state
    await tester.pump(const Duration(milliseconds: 1200));

    final boundarySplash = boundaryKeySplash.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    final imageSplash = await boundarySplash.toImage(pixelRatio: 2.0);
    final byteDataSplash =
        await imageSplash.toByteData(format: ui.ImageByteFormat.png);
    final pngBytesSplash = byteDataSplash!.buffer.asUint8List();

    final splashFile = File('${artifactsDir.path}/splash_screen_preview.png');
    await splashFile.writeAsBytes(pngBytesSplash);

    // 2. Capture Login Screen
    final boundaryKeyLogin = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKeyLogin,
          child: const LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final boundaryLogin = boundaryKeyLogin.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    final imageLogin = await boundaryLogin.toImage(pixelRatio: 2.0);
    final byteDataLogin =
        await imageLogin.toByteData(format: ui.ImageByteFormat.png);
    final pngBytesLogin = byteDataLogin!.buffer.asUint8List();

    final loginFile = File('${artifactsDir.path}/login_screen_preview.png');
    await loginFile.writeAsBytes(pngBytesLogin);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    },
    // This is a screenshot-generation utility, not a functional CI test.
    // Run manually with --dart-define=GENERATE_PREVIEWS=true when needed.
    skip: !const bool.fromEnvironment('GENERATE_PREVIEWS'),
  );
}
