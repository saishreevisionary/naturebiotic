import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/features/auth/screens/login_screen.dart';
import 'package:nature_biotic/features/auth/screens/update_password_screen.dart';
import 'package:nature_biotic/features/auth/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://utujkxrobmzlvudpvapc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV0dWpreHJvYm16bHZ1ZHB2YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzA2NjQsImV4cCI6MjA5MDUwNjY2NH0.REckx5fsLJMEJFnQVJdjyfNHC0seokVfPYkhOr5fxCw',
  );

  // Listen for Auth state changes (specifically for password recovery)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    try {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamed('/update-password');
      }
    } catch (e) {
      debugPrint('Auth listener error: $e');
    }
  });
  
  runApp(const NatureBioticApp());
}

class NatureBioticApp extends StatelessWidget {
  const NatureBioticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nature Biotic',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Set the global navigator key
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/update-password': (context) => const UpdatePasswordScreen(),
      },
    );
  }
}
