import 'package:flutter/material.dart';
import 'video_generation_loading_screen.dart';

class JourneyVideoSection extends StatefulWidget {
  final String journeyId;
  final VoidCallback onContinue;
  const JourneyVideoSection(
      {super.key, required this.journeyId, required this.onContinue});

  @override
  State<JourneyVideoSection> createState() => _JourneyVideoSectionState();
}

class _JourneyVideoSectionState extends State<JourneyVideoSection> {
  bool _isProcessing = false;
  String? _localErrorMsg;

  void _handleGenerateVideoPressed() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _localErrorMsg = null;
    });

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) =>
            VideoGenerationLoadingScreen(journeyId: widget.journeyId),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_localErrorMsg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _localErrorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleGenerateVideoPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEA8601),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFEA8601)),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Generate Video',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.auto_awesome, size: 18),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
