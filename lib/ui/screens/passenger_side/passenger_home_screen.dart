import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/book_ride.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_profile.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_ride_history.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_bookings.dart';
import 'package:tri_go_ride/ui/login_screen.dart';

import '../../../main.dart';
import '../../../services/auth_services.dart';
import '../notifs_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  String name = '';
  List<Map<String, dynamic>> recentActivities = [];
  int _unreadCount = 0;

  final Map<String, Widget> screens = {
    'Book A Ride': BookRideScreen(),
    'Ride History': PassengerRideHistory(),
    'Profile': PassengerProfile(),
    'Current Booking': PassengerBookingsScreen(),
  };

  @override
  void initState() {
    super.initState();
    setName();
    fetchNotifications();
  }

  // Set user name
  void setName() async {
    final doc = await _authService.firestore
        .collection("users")
        .doc(_authService.getUser()?.email)
        .get();

    final fetched = doc.data()?['username'] as String? ?? 'Guest';
    setState(() {
      name = fetched;
      _loading = false;
    });
  }

  String formatTimestamp(DateTime timestamp) {
    final DateFormat formatter =
        DateFormat('MMM dd, yyyy h:mm a'); // Example: "Apr 27, 2025 3:30 PM"
    return formatter.format(timestamp);
  }

  void fetchNotifications() {
    _authService.firestore
        .collection("notifs")
        .where("userId", isEqualTo: _authService.getUser()?.email)
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots() // Listen for real-time changes
        .listen((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        return {
          'message': doc['message'],
          'timestamp': doc['timestamp'].toDate(),
          'type': doc['type'],
          'read': doc['read'] ?? false,
        };
      }).toList();

      final unreadCount = notifications.where((n) => n['read'] == false).length;

      setState(() {
        recentActivities =
            notifications.take(3).toList(); // Limit to 3 notifications
        _unreadCount = unreadCount;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 64),
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
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $name',
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
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsPage())),
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
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: screens.entries.map((entry) {
                return SizedBox(
                  height: 100,
                  child: _OptionCard(
                    iconOrImage: _iconOrImageForLabel(entry.key),
                    label: entry.key,
                    onTap: () {
                      final page = screens[entry.key]!;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      );
                    },
                  ),
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
            // Display real-time updates for the notifications
            ...recentActivities.map((activity) {
              return ListTile(
                leading: _imageForNotificationType(activity['type']),
                title: Text(activity['message'],
                    style: theme.textTheme.bodyMedium),
                subtitle: Text(formatTimestamp(activity['timestamp'])),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final Widget iconOrImage;
  final String label;
  final VoidCallback onTap;

  const _OptionCard({
    required this.iconOrImage,
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
              iconOrImage, // <-- works for both Image and Icon
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _iconOrImageForLabel(String label) {
  switch (label) {
    case 'Book A Ride':
      return Image.asset('assets/p-07.png', width: 40, height: 40);
    case 'Ride History':
      return Image.asset('assets/p-08.png', width: 40, height: 40);
    case 'Profile':
      return Icon(Icons.person, size: 40, color: Colors.orange);
    case 'Current Booking':
      return Icon(Icons.event_note, size: 40, color: Colors.orange);
    default:
      return Icon(Icons.help_outline, size: 40, color: Colors.orange);
  }
}

Widget _imageForNotificationType(String type) {
  switch (type) {
    case 'booking':
      return Image.asset(
        'assets/p-01.png',
        width: 50,
        height: 50,
      );
    case 'profile':
      return const Icon(
        Icons.person_outline,
        size: 50,
        color: Colors.orange,
      );
    case 'promotion':
      return const Icon(
        Icons.local_offer,
        size: 50,
        color: Colors.orange,
      );
    default:
      return const Icon(
        Icons.notifications,
        size: 28,
        color: Colors.orange,
      );
  }
}
