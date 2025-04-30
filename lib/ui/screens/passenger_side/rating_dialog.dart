import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/services/rating_service.dart';
import '../../../models/rating.dart';

class EnhancedRatingDialog extends StatefulWidget {
  final String driverId;
  final String bookingId;
  final String? driverName;           // e.g. 'Juan'
  final VoidCallback onRatingComplete;

  const EnhancedRatingDialog({
    Key? key,
    required this.driverId,
    required this.bookingId,
    required this.onRatingComplete,
    this.driverName,
  }) : super(key: key);

  @override
  _EnhancedRatingDialogState createState() => _EnhancedRatingDialogState();
}

class _EnhancedRatingDialogState extends State<EnhancedRatingDialog> {
  int    _rating = 5;
  String _comment = '';
  bool   _isSubmitting = false;

  final _authService   = AuthService();
  final _ratingService = RatingService();

  final List<String> _feedbackOptions = [
    'Friendly driver',
    'Clean tricycle',
    'Safe driving',
    'On time',
    'Knows the route well',
  ];
  final List<String> _selectedTags = [];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              widget.driverName != null
                  ? 'Rate Your Ride with ${widget.driverName}'
                  : 'Rate Your Ride',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final idx = i + 1;
                return IconButton(
                  icon: Icon(
                    idx <= _rating ? Icons.star : Icons.star_border,
                    color: idx <= _rating ? Colors.amber : Colors.grey,
                    size: 36,
                  ),
                  onPressed: () => setState(() => _rating = idx),
                );
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _feedbackOptions.map((opt) {
                final sel = _selectedTags.contains(opt);
                return FilterChip(
                  label: Text(opt),
                  selected: sel,
                  onSelected: (yes) {
                    setState(() {
                      if (yes) _selectedTags.add(opt);
                      else     _selectedTags.remove(opt);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Add a comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (txt) => _comment = txt.trim(),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('SKIP'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('SUBMIT'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final user = _authService.getUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to rate.')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final ts = Timestamp.now();
    final rating = DriverRating(
      bookingId   : widget.bookingId,
      driverId    : widget.driverId,
      passengerId : user.uid,
      rating      : _rating,
      comment     : _comment,
      feedbackTags: _selectedTags,
      timestamp   : ts,
    );

    try {
      await _ratingService.submitRating(rating);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
      Navigator.pop(context);
      widget.onRatingComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
      setState(() => _isSubmitting = false);
    }
  }
}
