import 'package:flutter/material.dart';

class QuestCompletedScreen extends StatelessWidget {
  final String areaName;
  final List<String> completedQuests;
  final String distanceTraveled;
  final String timeSpent;
  final VoidCallback onGenerateVideo;
  final VoidCallback onContinue;

  const QuestCompletedScreen({
    super.key,
    required this.areaName,
    required this.completedQuests,
    required this.distanceTraveled,
    required this.timeSpent,
    required this.onGenerateVideo,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF9E6), Color(0xFFFFF3CC)],
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with confetti animation
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Confetti animation
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 300,
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.5,
                            colors: [
                              Color(0x33FFD700), // 20% opacity
                              Color(0x00FFB800), // 0% opacity
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Celebration icon
                          Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.celebration_rounded,
                              size: 60,
                              color: Color(0xFFFFB800),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Title
                          const Text(
                            'Quest Completed!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3047),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          
                          // Subtitle
                          Text(
                            'You\'ve completed all quests in $areaName!',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Map preview
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.map_outlined,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Your Journey section
                        const Text(
                          'Your Journey',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3047),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Completed quests list
                        ...completedQuests.map((quest) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  quest,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF2D3047),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                        
                        const SizedBox(height: 24),
                        
                        // Stats
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(Icons.directions_walk, distanceTraveled, 'Traveled'),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[200],
                              ),
                              _buildStatColumn(Icons.timer_outlined, timeSpent, 'Time Spent'),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 100), // Extra space for buttons
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Generate Video Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onGenerateVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Generate Journey Video',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onContinue,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2D3047)),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to Next Area',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2D3047),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatColumn(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFB800), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3047),
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
