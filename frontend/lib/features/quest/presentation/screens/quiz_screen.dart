import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/question_result.dart'; // Import the new model file
import 'quiz_summary_screen.dart'; // Import the summary screen

// Data class QuestionResult is now in its own file

class QuizScreen extends StatefulWidget {
  final String questId;
  final String locationId;
  final String missionId;
  final String locationName;
  final double latitude;
  final double longitude;

  const QuizScreen({
    Key? key,
    required this.questId,
    required this.locationId,
    required this.missionId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
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
  int _timeLeft = 0; // Initialize, will be set in _initQuiz
  String? _userMissionProgressId;
  Timer? _timer;
  List<QuestionResult> _quizResults = []; // To store results of each question

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  void _startTimer() {
    _timer?.cancel(); // Ensure any existing timer is cancelled
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) {
          setState(() {
            _timeLeft--;
          });
        }
      } else {
        timer.cancel();
        // Quiz time is up for the entire quiz
        if (mounted) {
          _completeQuiz(timedOut: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initQuiz() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final progressResponse = await Supabase.instance.client
          .from('user_mission_progress')
          .select()
          .eq('user_id', user.id)
          .eq('mission_id', widget.missionId)
          .single();
      _userMissionProgressId = progressResponse['id'];

      final locationMission = await Supabase.instance.client
          .from('location_missions')
          .select('questions')
          .eq('location_name', widget.locationName)
          .single();

      final List<dynamic> questionsJson = locationMission['questions'];
      
      if (mounted) {
        _questions = questionsJson.map((q) => {
          'id': '${widget.missionId}_${questionsJson.indexOf(q)}',
          'question': q['question'],
          'correct_answer': q['correct_answer'],
          'options': q['options'],
          'points': q['points'] ?? (questionsJson.indexOf(q) == 0 ? 40 : 30),
          'sequence_number': questionsJson.indexOf(q) + 1,
        }).toList();
        
        for (var question in _questions) {
          final options = List<String>.from(question['options'] ?? []);
          if (!options.contains(question['correct_answer'])) {
            options.add(question['correct_answer']);
          }
          options.shuffle();
          question['shuffled_options'] = options;
        }
        
        setState(() {
          _timeLeft = 60; // Total time for quiz set to 60 seconds
          _isLoading = false;
        });
        
        if (_questions.isNotEmpty) {
          _startTimer(); // Start the timer for the whole quiz
        } else {
          // Handle no questions loaded scenario - perhaps navigate back or show message
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No questions found for this mission.')),
          );
          Navigator.pop(context); // Example: Go back if no questions
        }
      }
    } catch (e) {
      print('Error loading quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load quiz: $e')),
        );
        Navigator.pop(context); // Go back on error
      }
    }
  }

  void _handleAnswer(String answer) {
    if (_hasAnswered) return; // Already answered this question

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

    // Store the result
    _quizResults.add(QuestionResult(
      questionText: currentQuestion['question'],
      selectedAnswer: answer,
      correctAnswer: currentQuestion['correct_answer'],
      isCorrect: isCorrect,
      pointsEarned: isCorrect ? points : 0,
    ));

    _recordAnswer(answer, isCorrect, points);

    // Delay moving to next question
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _hasAnswered = false;
        });
      } else {
        _completeQuiz(); // All questions answered
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
        'question': _questions[_currentQuestionIndex]['question'],
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

  Future<void> _completeQuiz({bool timedOut = false}) async {
    print("[QuizScreen] _completeQuiz called. Timed out: $timedOut. Results count: ${_quizResults.length}");
    if (_userMissionProgressId == null && !timedOut) {
       print("[QuizScreen] Aborting _completeQuiz: _userMissionProgressId is null and not timed out.");
      return;
    }
    _timer?.cancel(); 

    if (_userMissionProgressId != null) {
      try {
        print("[QuizScreen] Updating mission progress for ID: $_userMissionProgressId");
        await Supabase.instance.client
            .from('user_mission_progress')
            .update({
              'status': timedOut ? 'timed_out' : 'completed',
              'points_earned': _score, 
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _userMissionProgressId!);
         print("[QuizScreen] Mission progress update successful.");
      } catch (e) {
        print("[QuizScreen] Error updating mission progress: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving quiz progress: ${e.toString()}')),
          );
        }
      }
    }

    if (!mounted) {
      print("[QuizScreen] Aborting _completeQuiz: not mounted before navigating to summary.");
      return;
    }

    print("[QuizScreen] Navigating to QuizSummaryScreen.");
    final summaryResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSummaryScreen(
          quizResults: _quizResults,
          totalScore: _score,
          questId: widget.questId, 
          locationId: widget.locationId,
          missionId: _userMissionProgressId ?? 'unknown_mission_${DateTime.now().millisecondsSinceEpoch}',
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
        settings: const RouteSettings(name: 'QuizSummaryScreen'),
      ),
    );

    if (mounted && summaryResult == true) {
      print("[QuizScreen] Quiz summary completed, popping self with true.");
      Navigator.pop(context, true); // Pop back to MissionDetailsScreen with success
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF3E0),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      );
    }

    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF3E0),
        body: Center(
          child: Text(_questions.isEmpty ? 'No questions available.' : 'Quiz completed or issue loading question.'),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['shuffled_options']);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
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
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _timeLeft > 10 ? Colors.orange.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer,
                          size: 20,
                          color: _timeLeft > 10 ? Colors.orange.shade900 : Colors.red.shade900,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_timeLeft s',
                          style: TextStyle(
                            color: _timeLeft > 10 ? Colors.orange.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 20, color: Colors.orange.shade900),
                        const SizedBox(width: 8),
                        Text(
                          '$_score pts',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  currentQuestion['question'],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ...options.map((answer) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: (_hasAnswered) ? null : () => _handleAnswer(answer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(answer),
                    foregroundColor: _getTextColor(answer),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    disabledBackgroundColor: _getButtonColor(answer),
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  child: Text(
                    answer,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Color _getButtonColor(String optionText) {
    if (!_hasAnswered) {
      return const Color(0xFFFFE082); // Default yellow
    }

    final correctAnswer = _questions[_currentQuestionIndex]['correct_answer'];
    
    if (optionText == correctAnswer) {
      return Colors.green.shade400; // Correct answer is always green when answered
    } else if (optionText == _selectedAnswer) {
      return Colors.red.shade400; // Selected wrong answer is red
    }
    return Colors.grey.shade300; // Other options greyed out
  }

  Color _getTextColor(String optionText) {
    if (!_hasAnswered) {
      return Colors.black87;
    }

    final correctAnswer = _questions[_currentQuestionIndex]['correct_answer'];
    
    if (optionText == correctAnswer || optionText == _selectedAnswer) {
      return Colors.white;
    }
    return Colors.black54;
  }
} 