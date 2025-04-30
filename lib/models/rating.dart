// lib/models/rating.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DriverRating {
  final String bookingId;
  final String driverId;
  final String passengerId;
  final int    rating;
  final String comment;
  final List<String> feedbackTags;
  final Timestamp    timestamp;

  DriverRating({
    required this.bookingId,
    required this.driverId,
    required this.passengerId,
    required this.rating,
    required this.comment,
    required this.feedbackTags,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'bookingId'    : bookingId,
    'driverId'     : driverId,
    'passengerId'  : passengerId,
    'rating'       : rating,
    'comment'      : comment.isEmpty ? null : comment,
    'feedbackTags' : feedbackTags.isEmpty ? null : feedbackTags,
    'timestamp'    : timestamp,
  };

  static DriverRating fromMap(Map<String, dynamic> m) => DriverRating(
    bookingId   : m['bookingId']   as String,
    driverId    : m['driverId']    as String,
    passengerId : m['passengerId'] as String,
    rating      : (m['rating'] as num).toInt(),
    comment     : m['comment'] as String? ?? '',
    feedbackTags: List<String>.from(m['feedbackTags'] ?? []),
    timestamp   : m['timestamp'] as Timestamp,
  );
}
