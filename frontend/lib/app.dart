import 'package:flutter/material.dart';
import 'package:honeybee/features/auth/presentation/screens/login_screen.dart';
import 'package:honeybee/features/auth/presentation/screens/register_screen.dart';
import 'package:honeybee/features/quest/presentation/screens/quest_completed_screen.dart';
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

        // If user is authenticated, show quest completed screen
        if (session != null) {
          return QuestCompletedScreen(
            areaName: 'Pekan',
            xpEarned: 450,
            questsCompleted: 3,
            highlights: [
              QuestHighlight(
                title: 'Sultan Abu Bakar Museum',
                subtitle: 'Completed Royal Heritage Quest',
                imagePath: 'assets/images/sultan_museum.png',
              ),
              QuestHighlight(
                title: 'Pekan Riverfront',
                subtitle: 'Mastered Local Cuisine Quest',
                imagePath: 'assets/images/pekan_riverfront.png',
              ),
              QuestHighlight(
                title: 'Istana Abu Bakar',
                subtitle: 'Mastered Local Cuisine Quest',
                imagePath: 'assets/images/istana_abubakar.png',
              ),
            ],
            onContinue: () {
              // Handle continue button tap
              print('Continue button pressed');
            },
            onGenerateVideo: () {
              // Handle generate video button tap
              print('Generate video button pressed');
            },
            onLogout: () {
              // Handle logout
              Supabase.instance.client.auth.signOut();
            },
          );
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
