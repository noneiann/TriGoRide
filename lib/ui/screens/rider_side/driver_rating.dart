import 'package:flutter/material.dart';

import 'package:tri_go_ride/services/rating_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/rating.dart';

class DriverRatingDisplay extends StatelessWidget {
  final String driverId;
  final bool showDetailedStats;

  const DriverRatingDisplay({
    Key? key,
    required this.driverId,
    this.showDetailedStats = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final RatingService ratingService = RatingService();

    return FutureBuilder<Map<String, dynamic>>(
      future: ratingService.getDriverRatingStats(driverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          return const Text('No rating data available');
        }

        final stats = snapshot.data!;
        final double averageRating = stats['averageRating'] as double;
        final int totalRatings = stats['totalRatings'] as int;

        if (totalRatings == 0) {
          return const Text('No ratings yet');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'})',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            if (showDetailedStats && totalRatings > 0) ...[
              const SizedBox(height: 16),
              _buildRatingBars(stats),
              const SizedBox(height: 16),
              FutureBuilder<List<DriverRating>>(
                future: ratingService.getDriverRatings(driverId),
                builder: (context, ratingsSnapshot) {
                  if (!ratingsSnapshot.hasData || ratingsSnapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final ratings = ratingsSnapshot.data!;
                  final recentRatings = ratings.take(3).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Reviews',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recentRatings.map((rating) => _buildReviewItem(rating)).toList(),
                      if (ratings.length > 3) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            _showAllReviews(context, ratings);
                          },
                          child: Text(
                            'See all ${ratings.length} reviews',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRatingBars(Map<String, dynamic> stats) {
    final List<int> ratingCounts = List<int>.from(stats['ratingCounts'] as List);
    final int totalRatings = stats['totalRatings'] as int;

    return Column(
      children: [
        for (int i = 5; i >= 1; i--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '$i',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalRatings > 0 ? ratingCounts[i - 1] / totalRatings : 0,
                      backgroundColor: Colors.grey[300],
                      color: Colors.amber,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${ratingCounts[i - 1]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReviewItem(DriverRating rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                      (index) => Icon(
                    index < rating.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FutureBuilder<String>(
                future: _getPassengerName(rating.passengerId),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Anonymous',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
              const Spacer(),
              Text(
                _formatDate(rating.timestamp.toDate()),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rating.comment,
              style: const TextStyle(fontSize: 14),
            ),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }

  Future<String> _getPassengerName(String passengerId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(passengerId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['username'] ?? 'Anonymous';
      }
      return 'Anonymous';
    } catch (e) {
      return 'Anonymous';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 2) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  void _showAllReviews(BuildContext context, List<DriverRating> ratings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'All Reviews (${ratings.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: ratings.length,
                    itemBuilder: (context, index) {
                      return _buildReviewItem(ratings[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}