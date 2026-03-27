import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../routes/app_routes.dart';
import '../provider/auth_provider.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeBySession();
    });
  }

  Future<void> _routeBySession() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.loadSession();
    final isLoggedIn = authProvider.isLoggedIn;
    if (!mounted) return;
    final route = isLoggedIn ? AppRoutes.home : AppRoutes.login;

    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
