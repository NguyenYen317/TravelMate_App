import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/ai/ai_provider.dart';
import 'features/expense/providers/expense_provider.dart';
import 'features/search/provider/search_provider.dart';
import 'features/social/providers/social_provider.dart';
import 'features/trip/providers/trip_planner_provider.dart';
import 'core/providers/app_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

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
        ChangeNotifierProvider<AIProvider>(create: (_) => AIProvider()),
        ChangeNotifierProvider<TripPlannerProvider>(
          create: (_) => TripPlannerProvider(),
        ),
        ChangeNotifierProvider<SocialProvider>(create: (_) => SocialProvider()),
        ChangeNotifierProvider<ExpenseProvider>(
          create: (_) => ExpenseProvider(),
        ),
      ],
      child: const TravelMateApp(),
    ),
  );
}
