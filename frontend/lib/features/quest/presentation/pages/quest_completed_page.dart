import 'package:flutter/material.dart';
import '../screens/quest_completed_screen.dart';

class QuestCompletedPage extends StatelessWidget {
  const QuestCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QuestCompletedScreen(
        areaName: "Chinatown",
        completedQuests: const [
          "Visit the Chinatown Heritage Center",
          "Try the famous chicken rice",
          "Find the hidden mural",
          "Take a photo at the Buddha Tooth Relic Temple",
        ],
        distanceTraveled: "2.5 km",
        timeSpent: "3h 45m",
        onGenerateVideo: () {
          // TODO: Implement video generation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generating your journey video...')),
          );
        },
        onContinue: () {
          // TODO: Navigate to next area
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
