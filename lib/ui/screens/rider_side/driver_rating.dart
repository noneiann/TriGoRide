// lib/ui/screens/rider_side/driver_rating_display_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/services/rating_service.dart';
import '../../../models/rating.dart';

class DriverRatingDisplayPage extends StatelessWidget {
  final String driverId;
  final bool showDetailedStats;

  const DriverRatingDisplayPage({

    Key? key,
    required this.driverId,
    this.showDetailedStats = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final ratingService = RatingService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Ratings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: ratingService.getDriverRatingStats(driverId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Text('No rating data', style: theme.textTheme.bodyMedium));
            }

            final stats = snap.data!;
            final avg    = stats['averageRating'] as double;
            final total  = stats['totalRatings'] as int;
            final counts = List<int>.from(stats['ratingCounts'] as List<int>);

            if (total == 0) {
              return Center(child: Text('No ratings yet', style: theme.textTheme.bodyMedium));
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overall Rating Card
                  Card(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 32, color: theme.colorScheme.primary),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                avg.toStringAsFixed(1),
                                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$total ${total == 1 ? 'rating' : 'ratings'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Breakdown Bars
                  if (showDetailedStats) _buildRatingBars(context, counts, total),

                  // Recent Reviews
                  FutureBuilder<List<DriverRating>>(
                    future: ratingService.getDriverRatings(driverId),
                    builder: (context, rsnap) {
                      if (rsnap.connectionState != ConnectionState.done) {
                        return const SizedBox();
                      }
                      final reviews = rsnap.data ?? [];
                      if (reviews.isEmpty) {
                        return Center(child: Text('No reviews yet', style: theme.textTheme.bodyMedium));
                      }
                      final recent = reviews.take(3).toList();
                      return Column(
                        children: [
                          for (var r in recent) _buildReviewCard(context, r),
                          if (reviews.length > 3)
                            TextButton(
                              onPressed: () => _showAllReviews(context, reviews),
                              child: Text('See all ${reviews.length} reviews'),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRatingBars(BuildContext context, List<int> counts, int total) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final c = counts[i];
        final pct = total > 0 ? c / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text('$star', style: theme.textTheme.bodySmall),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: theme.dividerColor,
                  color: Colors.amber,
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text('$c', style: theme.textTheme.bodySmall),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(BuildContext context, DriverRating r) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: stars + user + time
            Row(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < r.rating ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: _fetchUsername(r.passengerId),
                  builder: (c, snap) {
                    return Text(
                      snap.data ?? 'Anonymous',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    );
                  },
                ),
                const Spacer(),
                Text(
                  _relativeDate(r.timestamp.toDate()),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

            // Comment
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.comment, style: theme.textTheme.bodyMedium),
            ],

            // Feedback tags
            if (r.feedbackTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: -4,
                children: r.feedbackTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    labelStyle: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String> _fetchUsername(String uid) async {
    final AuthService _authService = AuthService();
    final doc = await FirebaseFirestore.instance.collection('users').doc(_authService.getUser()!.email).get();
    if (doc.exists) {
      return (doc.data()?['username'] as String?) ?? 'Anonymous';
    }
    return 'Anonymous';
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final w = (diff.inDays / 7).floor();
    return '$w ${w == 1 ? 'week' : 'weeks'} ago';
  }

  void _showAllReviews(BuildContext context, List<DriverRating> reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text('All Reviews (${reviews.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              itemBuilder: (_, i) => _buildReviewCard(context, reviews[i]),
            ),
          ),
        ]),
      ),
    );
  }
}
