import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a new rating
  Future<void> submitRating(DriverRating rating) async {
    // Store the rating in bookings collection
    await _firestore.collection('bookings').doc(rating.bookingId).update({
      'rating': rating.rating,
      'comment': rating.comment,
      'ratedAt': rating.timestamp,
    });

    // Store the rating in the ratings collection
    await _firestore.collection('ratings').add(rating.toMap());

    // Update driver's rating in their profile
    await _updateDriverAverageRating(rating.driverId, rating.rating);

    // Add to driver's ratings subcollection
    await _firestore
        .collection('users')
        .doc(rating.driverId)
        .collection('ratings')
        .add(rating.toMap());
  }

  // Get all ratings for a driver
  Future<List<DriverRating>> getDriverRatings(String driverId) async {
    final querySnapshot = await _firestore
        .collection('ratings')
        .where('driverId', isEqualTo: driverId)
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => DriverRating.fromMap(doc.data()))
        .toList();
  }

  // Get average rating for a driver
  Future<double> getDriverAverageRating(String driverId) async {
    final driverDoc = await _firestore.collection('users').doc(driverId).get();

    if (!driverDoc.exists) return 0.0;

    final data = driverDoc.data();
    if (data == null) return 0.0;

    final rating = data['rating'];
    if (rating == null) return 0.0;

    return (rating as num).toDouble();
  }

  // Update a driver's average rating
  Future<void> _updateDriverAverageRating(String driverId, int newRating) async {
    // Get the driver document
    final driverDoc = await _firestore.collection('users').doc(driverId).get();

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

    // Update the driver's document
    await _firestore.collection('users').doc(driverId).update({
      'rating': newAverageRating,
      'totalRatings': newTotalRatings,
      'lastRatingUpdate': Timestamp.now(),
    });
  }

  // Get detailed rating stats for a driver
  Future<Map<String, dynamic>> getDriverRatingStats(String driverId) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(driverId)
        .collection('ratings')
        .get();

    if (querySnapshot.docs.isEmpty) {
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingCounts': {
          '5': 0,
          '4': 0,
          '3': 0,
          '2': 0,
          '1': 0,
        }
      };
    }

    int total = 0;
    double sum = 0;
    Map<String, int> ratingCounts = {
      '5': 0,
      '4': 0,
      '3': 0,
      '2': 0,
      '1': 0,
    };

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final rating = data['rating'] as int;

      total++;
      sum += rating;
      ratingCounts[rating.toString()] = (ratingCounts[rating.toString()] ?? 0) + 1;
    }

    return {
      'averageRating': total > 0 ? sum / total : 0.0,
      'totalRatings': total,
      'ratingCounts': ratingCounts,
    };
  }

  // Get a passenger's rating history
  Future<List<DriverRating>> getPassengerRatingHistory(String passengerId) async {
    final querySnapshot = await _firestore
        .collection('ratings')
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => DriverRating.fromMap(doc.data()))
        .toList();
  }
}