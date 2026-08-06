import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Notification Service (Web-safe)
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  // Request permissions in background after frame render (prevents black screen)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PermissionService.requestAllPermissions();
  });

  runApp(const TartheebApp());
}

class TartheebApp extends StatelessWidget {
  const TartheebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tartheeb Madrasa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
