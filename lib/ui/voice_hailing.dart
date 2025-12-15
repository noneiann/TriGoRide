import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({Key? key}) : super(key: key);

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  String? _pickup;
  String? _dropoff;

  bool _isListening = false;
  bool _phasePickup = true;
  String _recognizedText = "";
  double _soundLevel = 0.0;

  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _waveController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    try {
      await _speech.stop();
    } catch (_) {}

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          setState(() => _isListening = false);
          _pulseController.stop();
        }
      },
      onError: (error) {
        debugPrint('Speech initialize error: $error');
        _showErrorSnackBar('Failed to initialize speech recognition');
      },
    );

    if (!available) {
      _showErrorSnackBar('Speech recognition not available');
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = "";
      _soundLevel = 0.0;
    });

    _pulseController.repeat();
    _fadeController.forward();

    _speech.listen(
      listenFor: const Duration(seconds: 8),
      partialResults: true,
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
      },
      onResult: (result) {
        setState(() => _recognizedText = result.recognizedWords);
        if (result.finalResult) {
          _isListening = false;
          _pulseController.stop();
          _speech.stop();
          _onSpeechDone(result.recognizedWords);
        }
      },
    );
  }

  void _onSpeechDone(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _showRetryMessage();
      Future.delayed(const Duration(milliseconds: 800), _startListening);
      return;
    }

    if (_phasePickup) {
      _pickup = trimmed;
      setState(() {
        _phasePickup = false;
        _recognizedText = '';
        _soundLevel = 0.0;
      });
      _fadeController.reset();
      _showPhaseTransition();
      Future.delayed(const Duration(milliseconds: 800), _startListening);
    } else {
      _dropoff = trimmed;
      Navigator.pop<Map<String, String>>(context, {
        'pickup': _pickup ?? '',
        'dropoff': _dropoff ?? '',
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRetryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nothing heard. Trying again...'),
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPhaseTransition() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Got it! Now for drop-off location...'),
        backgroundColor: Colors.green[600],
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = _phasePickup
        ? "Where would you like to be picked up?"
        : "Where would you like to be dropped off?";

    final subtitle = _phasePickup
        ? "Speak a location within Oroquieta City only (e.g., 'City Hall', 'Plaza')"
        : "Speak your destination within Oroquieta City only";

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Voice Hailing",
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Header Section
              _buildHeaderSection(theme, title, subtitle),

              const SizedBox(height: 40),

              // Progress Indicator
              _buildProgressIndicator(theme),

              const SizedBox(height: 50),

              // Waveform Visualization
              _buildWaveformSection(theme),

              const Spacer(),

              // Recognition Text
              _buildRecognitionText(theme),

              const SizedBox(height: 30),

              // Microphone Button
              _buildMicrophoneButton(theme, isDark),

              const SizedBox(height: 40),

              // Status Text
              _buildStatusText(theme),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme, String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProgressDot(theme, 0),
        _buildProgressLine(theme),
        _buildProgressDot(theme, 1),
      ],
    );
  }

  Widget _buildProgressDot(ThemeData theme, int index) {
    final isActive =
        (_phasePickup && index == 0) || (!_phasePickup && index == 1);
    final isCompleted = !_phasePickup && index == 0;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.green
            : isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
        border: Border.all(
          color: isActive || isCompleted
              ? Colors.transparent
              : theme.colorScheme.outline.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Icon(
        isCompleted
            ? Icons.check
            : index == 0
                ? Icons.location_on
                : Icons.flag,
        color:
            isCompleted || isActive ? Colors.white : theme.colorScheme.outline,
        size: 16,
      ),
    );
  }

  Widget _buildProgressLine(ThemeData theme) {
    return Container(
      width: 60,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: !_phasePickup
            ? Colors.green
            : theme.colorScheme.outline.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildWaveformSection(ThemeData theme) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return CustomPaint(
              painter: ModernWaveformPainter(
                level: _soundLevel,
                phase: _waveController.value,
                color: theme.colorScheme.primary,
                isActive: _isListening,
              ),
              size: const Size(280, 120),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecognitionText(ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _recognizedText.isNotEmpty
          ? Container(
              key: ValueKey(_recognizedText),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hearing,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _recognizedText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMicrophoneButton(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            if (_isListening) {
              _speech.stop();
              setState(() => _isListening = false);
              _pulseController.stop();
            } else {
              _startListening();
            }
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isListening
                  ? LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        theme.colorScheme.outline.withOpacity(0.3),
                        theme.colorScheme.outline.withOpacity(0.2),
                      ],
                    ),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(
                          0.3 + 0.2 * sin(_pulseController.value * 2 * pi),
                        ),
                        blurRadius:
                            20 + 10 * sin(_pulseController.value * 2 * pi),
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.white : theme.colorScheme.outline,
              size: 36,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(ThemeData theme) {
    String statusText;
    Color statusColor;

    if (_isListening) {
      statusText = "Listening...";
      statusColor = theme.colorScheme.primary;
    } else {
      statusText = "Tap microphone to speak";
      statusColor = theme.colorScheme.onSurface.withOpacity(0.6);
    }

    return Text(
      statusText,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: statusColor,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class ModernWaveformPainter extends CustomPainter {
  final double level;
  final double phase;
  final Color color;
  final bool isActive;

  ModernWaveformPainter({
    required this.level,
    required this.phase,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      _paintInactiveWave(canvas, size);
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barWidth = 4.0;
    final spacing = 3.0;
    final total = (size.width / (barWidth + spacing)).floor();
    if (total <= 0) return;

    final normalizedLevel = (level.clamp(0.0, 60.0) / 60.0).clamp(0.0, 1.0);
    final centerY = size.height / 2;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < total; i++) {
      final x = i * (barWidth + spacing) +
          (size.width - (total * (barWidth + spacing))) / 2;
      final t = i / total;

      // Create multiple wave frequencies for more complex pattern
      final wave1 = sin((t * 4 * pi) + (phase * 2 * pi));
      final wave2 = sin((t * 8 * pi) + (phase * 3 * pi)) * 0.5;
      final combinedWave = (wave1 + wave2) / 1.5;

      // Base height with sound level influence
      final baseHeight = 4.0;
      final dynamicHeight =
          baseHeight + (combinedWave.abs() * normalizedLevel * maxHeight * 0.6);

      final barHeight = dynamicHeight.clamp(baseHeight, maxHeight);

      // Create gradient effect
      final opacity = 0.4 + 0.6 * (1.0 - (i - total / 2).abs() / (total / 2));
      paint.color = color.withOpacity(opacity);

      final rect = Rect.fromLTWH(
        x,
        centerY - barHeight / 2,
        barWidth,
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  void _paintInactiveWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final barWidth = 4.0;
    final spacing = 3.0;
    final total = (size.width / (barWidth + spacing)).floor();
    if (total <= 0) return;

    final centerY = size.height / 2;
    const baseHeight = 8.0;

    for (int i = 0; i < total; i++) {
      final x = i * (barWidth + spacing) +
          (size.width - (total * (barWidth + spacing))) / 2;

      final rect = Rect.fromLTWH(
        x,
        centerY - baseHeight / 2,
        barWidth,
        baseHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ModernWaveformPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.isActive != isActive;
  }
}
