import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/services/rating_service.dart';

import '../../../models/rating.dart';

class EnhancedRatingDialog extends StatefulWidget {
  final String driverId;
  final String bookingId;
  final Function() onRatingComplete;
  final String? driverName; // Optional driver name for personalization

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
  int _rating = 5;
  String _comment = '';
  bool _isSubmitting = false;
  final RatingService _ratingService = RatingService();
  final AuthService _authService = AuthService();

  // Feedback tags
  final List<String> _feedbackOptions = [
    'Friendly driver',
    'Clean tricycle',
    'Safe driving',
    'On time',
    'Knows the route well',
  ];
  final List<String> _selectedFeedback = [];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.driverName != null
                    ? 'Rate Your Ride with ${widget.driverName}'
                    : 'Rate Your Ride',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How was your trip?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: index < _rating ? Colors.amber : Colors.grey,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                _getRatingDescription(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What was good about this ride?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _feedbackOptions.map((option) {
                  final isSelected = _selectedFeedback.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFeedback.add(option);
                        } else {
                          _selectedFeedback.remove(option);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                maxLines: 3,
                onChanged: (value) {
                  _comment = value;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('SKIP'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    child: _isSubmitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('SUBMIT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingDescription() {
    if (_rating == 5) return 'Excellent ride!';
    if (_rating == 4) return 'Good ride';
    if (_rating == 3) return 'Average ride';
    if (_rating == 2) return 'Below average';
    return 'Poor experience';
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create rating object using your existing model
      final rating = DriverRating(
        rating: _rating,
        comment: _comment,
        driverId: widget.driverId,
        passengerId: _authService.getUser()!.uid,
        bookingId: widget.bookingId,
        timestamp: Timestamp.now(),
      );

      // Update the booking with the rating
      await _authService.firestore
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'rating': _rating,
        'comment': _comment,
        'ratedAt': Timestamp.now(),
        'feedbackTags': _selectedFeedback,
      });

      // Update the driver's overall rating
      await _updateDriverRating(widget.driverId, _rating);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.pop(context);
        widget.onRatingComplete();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateDriverRating(String driverId, int newRating) async {
    // Get the driver document
    final driverDoc = await _authService.firestore
        .collection('users')
        .doc(driverId)
        .get();

    if (!driverDoc.exists) return;

    final data = driverDoc.data()!;

    // Calculate the new average rating
    final int totalRatings = (data['totalRatings'] as int?) ?? 0;
    final double currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;

    // Calculate new average
    final double totalRatingPoints = currentRating * totalRatings;
    final double newTotalPoints = totalRatingPoints + newRating;
    final int newTotalRatings = totalRatings + 1;
    final double newAverageRating = newTotalPoints / newTotalRatings;

    // Prepare the update data
    final Map<String, dynamic> updateData = {
      'rating': newAverageRating,
      'totalRatings': newTotalRatings,
      'lastRatingUpdate': Timestamp.now(),
    };

    // Update feedback tag counts
    if (_selectedFeedback.isNotEmpty) {
      for (final tag in _selectedFeedback) {
        final String fieldName = 'feedbackCounts.${tag.replaceAll(' ', '_')}';
        updateData[fieldName] = FieldValue.increment(1);
      }
    }

    // Update the driver's document
    await _authService.firestore
        .collection('users')
        .doc(driverId)
        .update(updateData);

    // Add this rating to driver's ratings subcollection for history
    await _authService.firestore
        .collection('users')
        .doc(driverId)
        .collection('ratings')
        .add({
      'bookingId': widget.bookingId,
      'rating': _rating,
      'passengerId': _authService.getUser()!.uid,
      'comment': _comment.trim().isNotEmpty ? _comment : null,
      'feedbackTags': _selectedFeedback,
      'timestamp': Timestamp.now(),
    });
  }
}