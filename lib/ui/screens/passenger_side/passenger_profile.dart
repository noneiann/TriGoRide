import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/services/auth_services.dart';

import '../notifs_page.dart';

class PassengerProfile extends StatelessWidget {
  final _users = AuthService().firestore.collection('users');
  final _uid   = AuthService().getUser()?.email;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Personal Details",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage())),
            icon: Icon(Icons.notifications),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: SafeArea(
        child: StreamBuilder< DocumentSnapshot<Map<String, dynamic>> >(
          stream: _users.doc(_uid).snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());
            // snap.data is DocumentSnapshot<Map<String,dynamic>>?
            final docSnap = snap.data;
            final data    = docSnap?.data();
            if (data == null) {
              // no document or empty data
              return Center(child: Text("Profile not found"));
            }

            return ListView(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              children: [
                InfoCard(
                  label: 'Name',
                  content: Text(data['username'] ?? '',
                      style: TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context, 'username', 'Name', data['username']),
                ),
                SizedBox(height: 12),

                InfoCard(
                  label: 'Email',
                  content: Text(data['email'] ?? '',
                      style: TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context, 'email', 'Email', data['email']),
                ),
                SizedBox(height: 12),

                InfoCard(
                  label: 'Mobile number',
                  content: Text(data['phone'] ?? '',
                      style: TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context, 'phone', 'Mobile number', data['phone']),
                ),
                SizedBox(height: 12),
                InfoCard(
                  label: 'Emergency Phone Number',
                  content: Text(data['emergencyNum'] ?? '',
                      style: TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context, 'emergencyNum', 'Emergency Phone Number', data['emergencyNum']),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _navigateToEdit(
      BuildContext context, String fieldKey, String label, String? currentValue) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditFieldPage(
        fieldKey: fieldKey,
        label: label,
        initialValue: currentValue ?? '',
      ),
    ));
  }
}

class InfoCard extends StatelessWidget {
  final String label;
  final Widget content;
  final Widget? badge;
  final VoidCallback? onEdit;

  const InfoCard({
    Key? key,
    required this.label,
    required this.content,
    this.badge,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: Offset(0,2))],
      ),
      child: Stack(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            SizedBox(height: 8),
            content,
            if (badge != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Color(0xFFEAF4FF), borderRadius: BorderRadius.circular(6)),
                child: badge!,
              ),
            ],
          ]),
          if (onEdit != null)
            Positioned(
              top: 0, right: 0,
              child: IconButton(
                icon: Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                splashRadius: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class EditFieldPage extends StatefulWidget {
  final String fieldKey;
  final String label;
  final String initialValue;

  const EditFieldPage({
    Key? key,
    required this.fieldKey,
    required this.label,
    required this.initialValue,
  }) : super(key: key);

  @override
  _EditFieldPageState createState() => _EditFieldPageState();
}

class _EditFieldPageState extends State<EditFieldPage> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = AuthService().getUser()?.email;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({ widget.fieldKey: _controller.text.trim() });
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving ${widget.label}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.label}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(labelText: widget.label),
              validator: (v) => v!.trim().isEmpty ? 'Cannot be empty' : null,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}
