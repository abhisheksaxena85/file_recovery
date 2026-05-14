import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/storage_provider.dart';
import 'providers/scanner_provider.dart';
import 'providers/recovery_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class DataReviveApp extends StatelessWidget {
  const DataReviveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StorageProvider()),
        ChangeNotifierProvider(create: (_) => ScannerProvider()),
        ChangeNotifierProvider(create: (_) => RecoveryProvider()),
      ],
      child: MaterialApp(
        title: 'DataRevive — File Recovery',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
