// lib/services/rating_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch aggregate stats for a given driverId from the flat 'ratings' collection.
  Future<Map<String,dynamic>> getDriverRatingStats(String driverId) async {
    // 1) fetch all rating docs for driverId
    final qs = await _firestore
        .collection('ratings')
        .where('driverId', isEqualTo: driverId)
        .get();

    final docs = qs.docs;
    final total = docs.length;
    if (total == 0) {
      return {
        'averageRating': 0.0,
        'totalRatings' : 0,
        'ratingCounts' : [0,0,0,0,0],
      };
    }

    double sum = 0;
    // counts[0] -> 5-star count, counts[4] -> 1-star count
    final counts = List<int>.filled(5, 0);

    for (var d in docs) {
      final r = (d['rating'] as num).toInt().clamp(1,5);
      sum += r;
      counts[5 - r] += 1;
    }
    final avg = sum / total;

    return {
      'averageRating': avg,
      'totalRatings' : total,
      'ratingCounts' : counts,
    };
  }

  /// Fetch the most recent rating docs so we can show “Recent Reviews”
  Future<List<DriverRating>> getDriverRatings(String driverId) async {
    final qs = await _firestore
        .collection('ratings')
        .where('driverId', isEqualTo: driverId)
        .orderBy('timestamp', descending: true)
        .get();
    return qs.docs.map((d) => DriverRating.fromMap(d.data())).toList();
  }

  Future<void> submitRating(DriverRating r) async {
    final batch = _firestore.batch();

    // 1) mark the booking as rated
    final bookingRef = _firestore.collection('bookings').doc(r.bookingId);
    batch.update(bookingRef, {
      'rating'      : r.rating,
      'comment'     : r.comment,
      'feedbackTags': r.feedbackTags.isEmpty ? null : r.feedbackTags,
      'ratedAt'     : r.timestamp,
    });

    // 2) add to top-level ratings collection
    final ratingsRef = _firestore.collection('ratings').doc();
    batch.set(ratingsRef, r.toMap());

    // 3) update driver aggregate (simple example: increment count & recalc average)
    final driverRef = _firestore.collection('users').doc(r.driverId);
    final driverSnap = await driverRef.get();
    if (driverSnap.exists) {
      final data = driverSnap.data()!;
      final currentCount  = (data['totalRatings'] as int?)   ?? 0;
      final currentAvg    = (data['rating']       as num?)?.toDouble() ?? 0.0;
      final newCount      = currentCount + 1;
      final newAvg        = (currentAvg*currentCount + r.rating) / newCount;
      batch.update(driverRef, {
        'totalRatings': newCount,
        'rating'      : newAvg,
        'lastRatingUpdate': r.timestamp,
      });
    }

    // commit all writes as one atomic operation
    await batch.commit();
  }
}
