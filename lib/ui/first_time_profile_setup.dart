import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/services/cloudinary_service.dart';
import 'package:tri_go_ride/ui/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';

class FirstTimeProfileSetup extends StatefulWidget {
  const FirstTimeProfileSetup({super.key});

  @override
  State<FirstTimeProfileSetup> createState() => _FirstTimeProfileSetupState();
}

class _FirstTimeProfileSetupState extends State<FirstTimeProfileSetup> {
  final CollectionReference<Map<String, dynamic>> _users =
  AuthService().firestore.collection('users');
  final String _uid = AuthService().getUser()!.uid;
  final ImagePicker _picker = ImagePicker();

  String? _localImageUrl; // temporarily holds uploaded URL

  Future<void> _uploadAndSaveProfilePicture() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Call your reusable CloudinaryService
    final url = await CloudinaryService.uploadImage(File(picked.path));
    if (url == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload failed')));
      return;
    }

    // Update local state to immediately preview
    setState(() => _localImageUrl = url['url']);

    // Persist to Firestore
    final email = AuthService().getUser()?.email;
    if (email != null) {
      await _users.doc(email).update({'profileImage': url});
    }
  }

  void _navigateToEdit(
      BuildContext context, String fieldKey, String label, String currentValue) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditFieldPage(
        fieldKey: fieldKey,
        label: label,
        initialValue: currentValue,
        uid: _uid,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Setup",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => LoginPage()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _users.doc(AuthService().getUser()?.email).snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data?.data();
            if (data == null) return Center(child: Text(_uid));
            final Map<String, dynamic> imageMap;
            final String profileImage;
            if (data['profileImage'] != null) {
              imageMap = data['profileImage'] as Map<String, dynamic>;
              profileImage = _localImageUrl ?? imageMap['url'];
            } else {
              profileImage = "https://res.cloudinary.com/dgu4lwrwn/image/upload/v1747147170/samples/logo.png";
            }



            return ListView(
              padding:
              const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: profileImage != null
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _uploadAndSaveProfilePicture,
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload Profile Picture'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                InfoCard(
                  label: 'Name',
                  content: Text(data['username'] ?? '',
                      style: const TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context, 'username', 'Name', data['username'] ?? ''),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  label: 'Email',
                  content: Text(data['email'] ?? '',
                      style: const TextStyle(fontSize: 16)),
                  onEdit: null,
                ),
                const SizedBox(height: 12),
                InfoCard(
                  label: 'Mobile number',
                  content: Text(data['phone'] ?? '',
                      style: const TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context, 'phone', 'Mobile number', data['phone'] ?? ''),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  label: 'Plate number',
                  content: Text(data['plateNumber'] ?? '',
                      style: const TextStyle(fontSize: 16)),
                  onEdit: () => _navigateToEdit(
                      context,
                      'plateNumber',
                      'Plate Number',
                      data['plateNumber'] ?? ''),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  label: 'Password',
                  content:
                  const Text('••••••••', style: TextStyle(fontSize: 16)),
                  onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String label;
  final Widget content;
  final VoidCallback? onEdit;

  const InfoCard({
    Key? key,
    required this.label,
    required this.content,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Stack(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            content,
          ]),
          if (onEdit != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 20),
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
  final String uid;

  const EditFieldPage({
    Key? key,
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.uid,
  }) : super(key: key);

  @override
  _EditFieldPageState createState() => _EditFieldPageState();
}

class _EditFieldPageState extends State<EditFieldPage> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  final email = AuthService().getUser()?.email;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .update({widget.fieldKey: _controller.text.trim()});
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving ${widget.label}: $e')));
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Reauthenticate
      final cred = EmailAuthProvider.credential(
          email: _auth.currentUser!.email!, password: _currentCtrl.text.trim());
      await _auth.currentUser!.reauthenticateWithCredential(cred);
      // Update
      await _auth.currentUser!.updatePassword(_newCtrl.text.trim());
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error changing password: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _currentCtrl,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
              validator: (v) => v!.isEmpty ? 'Enter current password' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newCtrl,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
              validator: (v) =>
              v!.length < 6 ? 'Password must be at least 6 chars' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _changePassword,
              child: _saving
                  ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}
