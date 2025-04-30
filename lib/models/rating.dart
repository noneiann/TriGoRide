import 'package:cloud_firestore/cloud_firestore.dart';

class DriverRating {
  final int rating;
  final String comment;
  final String driverId;
  final String passengerId;
  final String bookingId;
  final Timestamp timestamp;

  DriverRating({
    required this.rating,
    required this.comment,
    required this.driverId,
    required this.passengerId,
    required this.bookingId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'rating': rating,
      'comment': comment,
      'driverId': driverId,
      'passengerId': passengerId,
      'bookingId': bookingId,
      'timestamp': timestamp,
    };
  }

  factory DriverRating.fromMap(Map<String, dynamic> map) {
    return DriverRating(
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      driverId: map['driverId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      bookingId: map['bookingId'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }


}