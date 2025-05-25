import 'package:flutter/material.dart';
import 'package:honeybee/features/auth/presentation/screens/login_screen.dart';
import 'package:honeybee/features/auth/presentation/screens/register_screen.dart';
import 'package:honeybee/features/quest/presentation/screens/quest_completed_screen.dart';
import 'package:honeybee/features/home/presentation/screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // If user is authenticated, show HomeScreen
        if (session != null) {
          return const HomeScreen();
          // To show home screen instead, replace with:
          // return const HomeScreen();
        }

        // Show either login or register screen based on _showRegister flag
        return _showRegister
            ? RegisterScreen(
                onLoginPressed: () => setState(() => _showRegister = false),
                onRegisterSuccess: () {
                  setState(() => _showRegister = false);
                  // Show a success message when registration is successful
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Registration successful! Please check your email to verify your account.'),
                      ),
                    );
                  }
                },
              )
            : LoginScreen(
                onRegisterPressed: () => setState(() => _showRegister = true),
              );
      },
    );
  }
}
