// lib/ui/screens/rider_side/rider_home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_flutter/cloudinary_object.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/notifs_page.dart';
import 'package:tri_go_ride/ui/screens/rider_side/driver_rating.dart';
import 'package:tri_go_ride/ui/screens/rider_side/passenger_search.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_profile.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_ride_history.dart';

final CloudinaryObject cloudinary =
    CloudinaryObject.fromCloudName(cloudName: 'dgu4lwrwn');

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  String _name = '';
  String _profileId = '';

  bool _loadingNotifs = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNameAndNotifs();
  }

  Future<void> _loadNameAndNotifs() async {
    final user = _authService.getUser();
    String fetchedName = 'Guest';
    String fetchedProfileId = '';
    if (user?.email != null) {
      final doc = await _authService.firestore
          .collection('users')
          .doc(user!.email)
          .get();
      fetchedName = doc.data()?['username'] as String? ?? 'Guest';
      final profileImage = doc.data()?['profileImage'] as Map<String, dynamic>?;
      fetchedProfileId = profileImage?['publicId'] as String? ?? '';
    }

    List<Map<String, dynamic>> notifs = [];
    int unreadCount = 0;
    if (user?.email != null) {
      final qs = await _authService.firestore
          .collection('notifs')
          .where('userId', isEqualTo: user!.email)
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();
      notifs = qs.docs.map((doc) {
        final d = doc.data();
        return {
          'message': d['message'] as String? ?? '',
          'type': d['type'] as String? ?? 'system',
          'timestamp': d['timestamp'] as Timestamp?,
          'read': d['read'] ?? false,
        };
      }).toList();

      // Get unread count
      final unreadQuery = await _authService.firestore
          .collection('notifs')
          .where('userId', isEqualTo: user.email)
          .where('read', isEqualTo: false)
          .get();
      unreadCount = unreadQuery.docs.length;
    }

    setState(() {
      _name = fetchedName;
      _profileId = fetchedProfileId;
      _notifications = notifs;
      _unreadCount = unreadCount;
      _loading = false;
      _loadingNotifs = false;
      print("Profile ID: $_profileId");
    });
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('h:mm a').format(ts.toDate());
  }

  Widget _iconForNotificationType(String type) {
    switch (type) {
      case 'booking':
        return Image.asset(
          'assets/p-01.png',
          width: 50,
          height: 50,
        );
      case 'booking_update':
        return Image.asset(
          'assets/p-01.png',
          width: 50,
          height: 50,
        );
      case 'payment':
        return const Icon(
          Icons.payment,
          size: 50,
          color: Colors.orange,
        );
      case 'promo':
        return const Icon(
          Icons.local_offer,
          size: 50,
          color: Colors.orange,
        );
      default:
        return const Icon(
          Icons.notifications,
          size: 50,
          color: Colors.orange,
        );
    }
  }

  IconData _iconForLabel(String label) {
    switch (label) {
      case 'Look for Passengers':
        return Icons.search;
      case 'Ride History':
        return Icons.history;
      case 'Feedback':
        return Icons.feedback_rounded;
      case 'Profile':
        return Icons.person;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    // Build your screens map here, where you can safely reference _authService
    final screens = {
      'Look for Passengers': const PassengerSearchPage(),
      'Ride History': const RideHistoryPage(),
      'Feedback': DriverRatingDisplayPage(
        driverId: _authService.getUser()!.uid,
      ),
      'Profile': RiderProfile(),
    };

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 64),
            // Header
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: _profileId.isEmpty
                            ? Container(
                                width: 80,
                                height: 80,
                                color: theme.primaryColor.withOpacity(0.3),
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: theme.primaryColor,
                                ),
                              )
                            : CldImageWidget(
                                cloudinary: cloudinary,
                                publicId: _profileId,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                transformation: Transformation()
                                  ..addTransformation(
                                      'ar_1.0,c_fill,w_100/r_max/f_png'),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $_name',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.textTheme.titleMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            'Welcome Back!',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsPage()),
                      );
                    },
                    icon: Badge(
                      isLabelVisible: _unreadCount > 0,
                      label: Text(_unreadCount.toString()),
                      child: Icon(Icons.notifications,
                          size: 32, color: theme.iconTheme.color),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What do you want to do?',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),

            // Options grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: screens.entries.map((entry) {
                return _OptionCard(
                  icon: _iconForLabel(entry.key),
                  label: entry.key,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => entry.value),
                    );
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Recent Activity', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),

            if (_loadingNotifs)
              const Center(child: CircularProgressIndicator())
            else if (_notifications.isEmpty)
              Center(
                child: Text(
                  'No recent notifications',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Column(
                children: _notifications.map((n) {
                  final ts = n['timestamp'] as Timestamp?;
                  return ListTile(
                    leading: _iconForNotificationType(n['type'] as String),
                    title: Text(n['message'] as String,
                        style: theme.textTheme.bodyMedium),
                    subtitle: Text(_formatTimestamp(ts)),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: theme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: theme.primaryColor),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
