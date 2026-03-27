import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/search/provider/search_provider.dart';
import 'core/providers/app_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    AuthService.instance.setFirebaseAvailability(true);
  } catch (_) {
    AuthService.instance.setFirebaseAvailability(false);
  }

  await AuthService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider()),
      ],
      child: const TravelMateApp(),
    ),
  );
}
