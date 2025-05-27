import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

class NextAreaPromptScreen extends StatefulWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;

  const NextAreaPromptScreen({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  @override
  State<NextAreaPromptScreen> createState() => _NextAreaPromptScreenState();
}

class _NextAreaPromptScreenState extends State<NextAreaPromptScreen>
    with TickerProviderStateMixin {
  static const String fullText = 'Are You Ready For The Next Area?';
  int _currentLength = 0;
  Timer? _timer;
  bool _showButtons = false;
  late AnimationController _beeController; // For wavy motion
  late AnimationController _buttonFadeController;
  late AnimationController _textAppearController;
  late AnimationController _beeFlyInController;

  late Animation<Offset> _textOffsetAnimation;
  late Animation<Offset> _beeFlyInAnimation;

  @override
  void initState() {
    super.initState();

    _textAppearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAppearController,
      curve: Curves.easeOutQuad,
    ));

    _beeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _beeFlyInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _beeFlyInAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0), // Start from right off-screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _beeFlyInController,
      curve: Curves.easeInOutCirc,
    ));

    _buttonFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startTypewriter();
  }

  void _startTypewriter() {
    _textAppearController.forward(); // Start text slide-in
    _timer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (_currentLength < fullText.length) {
        setState(() {
          _currentLength++;
        });
      } else {
        timer.cancel();
        _beeFlyInController.forward().whenComplete(() {
          _beeController.repeat(); // Start wavy motion after fly-in
        });
        setState(() {
          _showButtons = true;
        });
        _buttonFadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _beeController.dispose();
    _buttonFadeController.dispose();
    _textAppearController.dispose();
    _beeFlyInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
        fontSize: 36, // Slightly larger
        fontWeight: FontWeight.bold,
        color: const Color(0xFFD47A00), // Slightly adjusted color
        height: 1.3,
        letterSpacing: 1.1,
        shadows: [
          Shadow(
            blurRadius: 1.0,
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(1, 1),
          ),
        ]);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF9E6), // Main bg
              const Color(0xFFFFF3C0).withOpacity(0.8), // Lighter accent
            ],
          ),
        ),
        child: Stack(
          children: [
            // Faint Honeycomb Pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.04, // Very subtle
                child: Image.asset(
                  'assets/images/honeycomb_pattern.jpg', // Assuming you have this
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SlideTransition(
                      position: _textOffsetAnimation,
                      child: FadeTransition(
                        opacity: _textAppearController, // Fade in text block
                        child: SizedBox(
                          width: 350, // Ensure enough width
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: textStyle,
                              children: [
                                TextSpan(
                                    text:
                                        fullText.substring(0, _currentLength)),
                                if (_currentLength == fullText.length)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: SlideTransition(
                                      position: _beeFlyInAnimation,
                                      child: AnimatedBuilder(
                                        animation: _beeController,
                                        builder: (context, child) {
                                          final t = _beeController.value;
                                          final dx = 10 *
                                              sin(2 *
                                                  pi *
                                                  t *
                                                  2.2); // Adjusted wave
                                          final dy = 10 * sin(2 * pi * t * 1.8);
                                          return Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Opacity(
                                                opacity: 0.5,
                                                child: Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(
                                                                0xFFFFE066)
                                                            .withOpacity(0.7),
                                                        blurRadius: 20,
                                                        spreadRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Transform.translate(
                                                offset: Offset(dx, dy),
                                                child: Image.asset(
                                                  'assets/images/bee-flying.png',
                                                  width:
                                                      40, // Slightly larger bee
                                                  height: 40,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity:
                          _buttonFadeController, // Subtitle fades with buttons
                      child: const Text(
                        'Embark on a new discovery!', // Changed subtitle
                        style: TextStyle(
                          fontSize: 19,
                          color: Color(0xFFB47B00),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 52),
                    FadeTransition(
                      opacity: _buttonFadeController,
                      child: _showButtons
                          ? SizedBox(
                              width: 260, // Slightly wider buttons container
                              child: Column(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 26),
                                    label: const Text(
                                        'Yes, let\'s go!', // More engaging text
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA8601),
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            12), // More rounded
                                      ),
                                      elevation: 4, // Slight elevation for Yes
                                      shadowColor:
                                          Colors.black.withOpacity(0.3),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      widget.onYes();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Expanded(
                                          child: Divider(
                                              color: Color(0x99EA8601))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0),
                                        child: Text('or',
                                            style: TextStyle(
                                                color: const Color(0xFFEA8601)
                                                    .withOpacity(0.9),
                                                fontSize: 15)),
                                      ),
                                      const Expanded(
                                          child: Divider(
                                              color: Color(0x99EA8601))),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined,
                                        color: Color(0xFFEA8601), size: 26),
                                    label: const Text(
                                        'Not now', // Softer text for No
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFEA8601))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFFEA8601), width: 1.5),
                                      minimumSize:
                                          const Size(double.infinity, 52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            12), // More rounded
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      widget.onNo();
                                    },
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
