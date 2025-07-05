import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({Key? key}) : super(key: key);

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  late stt.SpeechToText _speech;
  bool _listeningPickup = false;
  bool _listeningDropoff = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _listen({required bool pickup}) async {
    final controller = pickup ? _pickupController : _dropoffController;
    setState(() {
      if (pickup) _listeningPickup = true;
      else _listeningDropoff = true;
    });

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          setState(() {
            _listeningPickup = false;
            _listeningDropoff = false;
          });
        }
      },
    );
    if (!available) return;

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          controller.text = result.recognizedWords;
          _speech.stop();
        }
      },
      listenFor: const Duration(seconds: 5),
      partialResults: false,
      cancelOnError: true,
    );
  }

  void _onContinue() {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields.')),
      );
      return;
    }
    Navigator.pop<Map<String, String>>(context, {
      'pickup': pickup,
      'dropoff': dropoff,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Hail'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Where do you want to be picked up?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                hintText: 'Enter or speak pickup location',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _listeningPickup ? Icons.mic : Icons.mic_none,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => _listen(pickup: true),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Text('Where do you want to be dropped off?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _dropoffController,
              decoration: InputDecoration(
                hintText: 'Enter or speak drop-off location',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _listeningDropoff ? Icons.mic : Icons.mic_none,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => _listen(pickup: false),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _onContinue,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
