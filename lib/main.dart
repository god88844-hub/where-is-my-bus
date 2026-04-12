import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/mobile_only_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_provider.dart';
import 'services/conductor_tracking_service.dart';
import 'services/firestore_service.dart';
import 'utils/app_theme.dart';
import 'utils/platform_support.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isMobilePlatform = isRunningOnSupportedMobilePlatform;

  if (isMobilePlatform) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    unawaited(FirestoreService().cleanupStaleBuses());
    await ConductorTrackingService.instance.init();
  }

  runApp(VizagBusApp(isMobilePlatform: isMobilePlatform));
}

class VizagBusApp extends StatelessWidget {
  final bool isMobilePlatform;

  const VizagBusApp({
    super.key,
    this.isMobilePlatform = true,
  });

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Vizag Bus Live',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MobileAppViewport(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: isMobilePlatform ? const HomeScreen() : const MobileOnlyScreen(),
    );

    if (!isMobilePlatform) {
      return app;
    }

    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: app,
    );
  }
}

class MobileAppViewport extends StatelessWidget {
  final Widget child;

  const MobileAppViewport({
    super.key,
    required this.child,
  });

  static const double maxContentWidth = 480;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= maxContentWidth) {
            return child;
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
