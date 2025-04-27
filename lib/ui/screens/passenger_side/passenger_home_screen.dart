import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/book_ride.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_profile.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_ride_history.dart';
import 'package:tri_go_ride/ui/login_screen.dart';

import '../../../main.dart';
import '../../../services/auth_services.dart';

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

  final Map<String, Widget> screens = {
    'Book A Ride': BookRideScreen(),
    'Ride History': PassengerRideHistory(),
    'Profile': PassengerProfile(),
    'Logout': LoginPage(),
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
    final DateFormat formatter = DateFormat('MMM dd, yyyy h:mm a'); // Example: "Apr 27, 2025 3:30 PM"
    return formatter.format(timestamp);
  }
  void fetchNotifications() {
    _authService.firestore
        .collection("notifs")
        .where("userId", isEqualTo: _authService.getUser()?.email)
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots()  // Listen for real-time changes
        .listen((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        return {
          'message': doc['message'],
          'timestamp': doc['timestamp'].toDate(),
          'type': doc['type'],
        };
      }).toList();

      setState(() {
        recentActivities = notifications.take(3).toList(); // Limit to 3 notifications
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
                              color: theme.textTheme.titleMedium?.color?.withOpacity(0.7),
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
                    onPressed: () {},
                    icon: Icon(Icons.notifications, size: 32, color: theme.iconTheme.color),
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
              physics: NeverScrollableScrollPhysics(),
              children: screens.entries.map((entry) {
                return SizedBox(
                  height: 100,
                  child: _OptionCard(
                    icon: _iconForLabel(entry.key),
                    label: entry.key,
                    onTap: () {
                      final page = screens[entry.key]!;
                      if (entry.key != 'Logout') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => page),
                        );
                      } else {
                        _authService.signOut();
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Activity', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            // Display real-time updates for the notifications
            ...recentActivities.map((activity) {
              return ListTile(
                leading: Icon(_iconForNotificationType(activity['type']), color: theme.primaryColor),
                title: Text(activity['message'], style: theme.textTheme.bodyMedium),
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

IconData _iconForLabel(String label) {
  switch (label) {
    case 'Book A Ride':
      return Icons.location_pin;
    case 'Ride History':
      return Icons.history;
    case 'Profile':
      return Icons.person;
    case 'Logout':
      return Icons.logout;
    default:
      return Icons.help_outline;
  }
}

IconData _iconForNotificationType(String type) {
  switch (type) {
    case 'booking':
      return Icons.directions_bike;
    case 'profile':
      return Icons.person;
    case 'promotion':
      return Icons.local_offer;
    default:
      return Icons.notifications;
  }
}
