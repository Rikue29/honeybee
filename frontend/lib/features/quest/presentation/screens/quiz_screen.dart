import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizScreen extends StatefulWidget {
  final String questId;
  final String locationId;
  final String missionId;
  final String locationName;

  const QuizScreen({
    Key? key,
    required this.questId,
    required this.locationId,
    required this.missionId,
    required this.locationName,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _questions = [];
  String? _selectedAnswer;
  bool _hasAnswered = false;
  int _timeLeft = 60; // 60 seconds per question
  String? _userMissionProgressId;

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  Future<void> _initQuiz() async {
    try {
      // Start the mission progress
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create or get user mission progress
      final progressResponse = await Supabase.instance.client
          .from('user_mission_progress')
          .upsert({
            'user_id': user.id,
            'mission_id': widget.missionId,
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _userMissionProgressId = progressResponse['id'];

      // Load questions for this mission
      final questionsResponse = await Supabase.instance.client
          .from('mission_questions')
          .select()
          .eq('mission_id', widget.missionId)
          .order('sequence_number');

      if (mounted) {
        setState(() {
          _questions = List<Map<String, dynamic>>.from(questionsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load quiz: $e')),
        );
      }
    }
  }

  void _handleAnswer(String answer) {
    if (_hasAnswered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = answer == currentQuestion['correct_answer'];
    final points = (currentQuestion['points'] as num?)?.toInt() ?? 0;

    setState(() {
      _selectedAnswer = answer;
      _hasAnswered = true;
      
      if (isCorrect) {
        _score += points;
      }
    });

    // Record the answer
    _recordAnswer(answer, isCorrect, points);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _hasAnswered = false;
          _timeLeft = 60;
        });
      } else {
        _completeQuiz();
      }
    });
  }

  Future<void> _recordAnswer(String answer, bool isCorrect, int points) async {
    if (_userMissionProgressId == null) return;

    try {
      final currentAnswers = await Supabase.instance.client
          .from('user_mission_progress')
          .select('answers')
          .eq('id', _userMissionProgressId!)
          .single();

      final List<Map<String, dynamic>> answers = 
          List<Map<String, dynamic>>.from(currentAnswers['answers'] ?? []);

      answers.add({
        'question_id': _questions[_currentQuestionIndex]['id'],
        'answer': answer,
        'is_correct': isCorrect,
        'points_earned': isCorrect ? points : 0,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await Supabase.instance.client
          .from('user_mission_progress')
          .update({
            'answers': answers,
            'points_earned': _score,
          })
          .eq('id', _userMissionProgressId!);
    } catch (e) {
      print('Error recording answer: $e');
    }
  }

  Future<void> _completeQuiz() async {
    if (_userMissionProgressId == null) return;

    try {
      // Update user mission progress
      await Supabase.instance.client
          .from('user_mission_progress')
          .update({
            'status': 'completed',
            'points_earned': _score,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _userMissionProgressId!);

      if (!mounted) return;

      // Navigate back with the score
      Navigator.pop(context, _score);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save quiz results: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text('No questions available for ${widget.locationName}'),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options'] ?? []);
    if (!options.contains(currentQuestion['correct_answer'])) {
      options.add(currentQuestion['correct_answer']);
    }
    options.shuffle();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 4),
                        Text('$_timeLeft'),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 16),
                        const SizedBox(width: 4),
                        Text('$_score'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                currentQuestion['question'],
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ...options.map((answer) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: _hasAnswered ? null : () => _handleAnswer(answer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(answer),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    answer,
                    style: TextStyle(
                      color: _hasAnswered ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Color _getButtonColor(String answer) {
    if (!_hasAnswered) {
      return Colors.white;
    }

    if (answer == _questions[_currentQuestionIndex]['correct_answer']) {
      return Colors.green;
    }

    if (answer == _selectedAnswer) {
      return Colors.red;
    }

    return Colors.white;
  }
} 