import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_url_gen/transformation/resize/resize.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:flutter/material.dart';
import 'package:cloudinary_flutter/cloudinary_context.dart';

import '../../../main.dart';
import '../../../services/auth_services.dart';

class RiderHomeScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 64),

            // Header with profile image and greeting
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
                        child: CldImageWidget(
                          cloudinary: cloudinary,
                          publicId: 'samples/look-up',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          transformation: Transformation().addTransformation("ar_1.0,c_fill,w_100/r_max/f_png")
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, Iann',
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

            // Prompt text
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What do you want to do?',
                style: theme.textTheme.titleMedium,
              ),
            ),

            const SizedBox(height: 32),

            // Options grid
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _OptionCard(
                        icon: Icons.search,
                        label: 'Look for Passengers',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _OptionCard(
                        icon: Icons.history,
                        label: 'Ride History',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _OptionCard(
                        icon: Icons.feedback_rounded,
                        label: 'Feedback',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _OptionCard(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: theme.primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today’s Trips', style: theme.textTheme.bodyMedium),
                        Text('3 Completed', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Earnings', style: theme.textTheme.bodyMedium),
                        Text('₱750.00', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Activity', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.directions_bike, color: theme.primaryColor),
              title: Text('Completed a ride to SM City', style: theme.textTheme.bodyMedium),
              subtitle: Text('10 mins ago'),
            ),
            ListTile(
              leading: Icon(Icons.attach_money, color: theme.primaryColor),
              title: Text('You received ₱250 from Juan Dela Cruz', style: theme.textTheme.bodyMedium),
              subtitle: Text('30 mins ago'),
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
