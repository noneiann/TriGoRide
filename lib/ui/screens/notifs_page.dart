import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../booking_details.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      print(user);
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('notifs')
            .where('userId', isEqualTo: user.email)
            .orderBy('timestamp', descending: true)
            .get();

        setState(() {
          _notifications = querySnapshot.docs
              .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifs')
          .doc(notificationId)
          .update({'read': true});

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['read'] = true;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifs').doc(notificationId).delete();

      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notification: $e')),
      );
    }
  }

  Widget _buildNotificationIcon(String type) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.orange : Colors.deepOrange;

    switch (type) {
      case 'booking':
        return CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(Icons.motorcycle, color: iconColor),
        );
      case 'booking_update':
        return CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(Icons.electric_rickshaw, color: iconColor),
        );
      case 'payment':
        return CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(Icons.payment, color: iconColor),
        );
      case 'promo':
        return CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(Icons.local_offer, color: iconColor),
        );
      case 'system':
        return CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(Icons.notifications, color: iconColor),
        );
      default:
        return CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(Icons.notifications, color: iconColor),
        );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';

    if (timestamp is Timestamp) {
      final dateTime = timestamp.toDate();
      return DateFormat('MMM d, y • h:mm a').format(dateTime);
    } else if (timestamp is String) {
      // Handle string format if needed
      return timestamp;
    }

    return 'Unknown time';
  }
  void _navigateToBookingDetails(String bookingId) {
    // TODO: Replace this with your actual page navigation.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsPage(bookingId: bookingId),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
            tooltip: 'Refresh notifications',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 80,
              color: isDarkMode ? Colors.orange : Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: Theme.of(context).primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            final bool isRead = notification['read'] ?? false;
            final String id = notification['id'] ?? '';
            final String message = notification['message'] ?? 'No message content';
            final String type = notification['type'] ?? 'system';

            return Dismissible(
              key: Key(id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                _deleteNotification(id);
              },
              child: InkWell(
                onTap: () {
                  if (!isRead) {
                    _markAsRead(id);
                  }

                  // Show details or navigate to a detail page
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildNotificationIcon(type),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  type.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            message,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatTimestamp(notification['timestamp']),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white60 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if ((type == 'booking' || type == 'booking_update') && notification['bookingId'] != null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToBookingDetails(notification['bookingId']);
                                },
                                child: const Text('View Ride Details'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: !isRead
                        ? (isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.05))
                        : null,
                    border: Border(
                      bottom: BorderSide(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotificationIcon(type),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  type.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatTimestamp(notification['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (!isRead)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

