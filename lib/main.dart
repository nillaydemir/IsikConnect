import 'dart:async';
import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'routes/app_routes.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'features/admin/providers/admin_approvals_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '',
  );

  runApp(const IsikConnectApp());
}

class IsikConnectApp extends StatefulWidget {
  const IsikConnectApp({super.key});

  @override
  State<IsikConnectApp> createState() => _IsikConnectAppState();
}

class _IsikConnectAppState extends State<IsikConnectApp> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _shouldRedirectToResetPassword = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      debugPrint('Supabase Auth Event: $event');
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Supabase Auth Event: passwordRecovery triggered');
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState?.pushNamed('/reset-password');
        } else {
          debugPrint('Navigator state is null, deferring routing to reset-password');
          setState(() {
            _shouldRedirectToResetPassword = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminApprovalsProvider()),
      ],
      child: MaterialApp(
        title: 'IsikConnect',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.initialRoute,
        routes: AppRoutes.routes,
        builder: (context, child) {
          if (_shouldRedirectToResetPassword) {
            _shouldRedirectToResetPassword = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              debugPrint('Executing deferred routing to reset-password');
              navigatorKey.currentState?.pushNamed('/reset-password');
            });
          }
          return child!;
        },
      ),
    );
  }
}
