import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    AuthService.instance.setFirebaseAvailability(true);
  } catch (_) {
    // Allow local auth flow even when Firebase is not configured yet.
    AuthService.instance.setFirebaseAvailability(false);
  }

  await AuthService.instance.init();
  runApp(const TravelMateApp());
}
