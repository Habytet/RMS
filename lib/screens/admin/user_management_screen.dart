// lib/screens/admin/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../providers/user_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Existing Users'),
              Tab(text: 'Create New User'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ExistingUsersList(),
            CreateUserForm(),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET FOR THE "EXISTING USERS" TAB ---
class ExistingUsersList extends StatelessWidget {
  const ExistingUsersList({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    Query query = FirebaseFirestore.instance.collection('users');
    if (currentUser != null && !currentUser.isAdmin) {
      query = query.where('branchId', isEqualTo: currentUser.branchId);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots() as Stream<QuerySnapshot<Map<String, dynamic>>>,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No users found.'));

        final docs = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(8),
          children: docs.map((doc) {
            final user = AppUser.fromMap(doc.data());
            return Card(
              child: ListTile(
                title: Text(user.username.isEmpty ? user.email : user.username),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.edit, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditUserScreen(userId: doc.id, user: user),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// --- WIDGET FOR THE "CREATE NEW USER" TAB ---
class CreateUserForm extends StatefulWidget {
  const CreateUserForm({super.key});
  @override
  State<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<CreateUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  Map<String, bool> _roles = {
    'podiumEnabled': false, 'waiterEnabled': false, 'customerEnabled': false,
    'banquetBookingEnabled': false, 'banquetReportsEnabled': false, 'queueReportsEnabled': false,
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final username = email.split('@').first;
    final profile = AppUser(
      username: username, email: email, branchId: context.read<UserProvider>().currentBranchId,
      podiumEnabled: _roles['podiumEnabled']!, waiterEnabled: _roles['waiterEnabled']!,
      customerEnabled: _roles['customerEnabled']!, banquetBookingEnabled: _roles['banquetBookingEnabled']!,
      banquetReportsEnabled: _roles['banquetReportsEnabled']!, queueReportsEnabled: _roles['queueReportsEnabled']!,
    );
    try {
      await context.read<UserProvider>().addUser(email, _passwordController.text.trim(), profile);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully!'), backgroundColor: Colors.green));
        _formKey.currentState!.reset();
        _emailController.clear();
        _passwordController.clear();
        setState(() => _roles.updateAll((key, value) => false));
      }
    } on FirebaseAuthException catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v!.isEmpty ? 'Please enter an email' : null),
          TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null),
          const SizedBox(height: 20),
          const Text('User Roles & Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ..._roles.keys.map((key) => SwitchListTile(title: Text(key.replaceAll('Enabled', '')), value: _roles[key]!, onChanged: (v) => setState(() => _roles[key] = v))).toList(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _createUser,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Create User'),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET: SCREEN FOR EDITING AN EXISTING USER (with DELETE button) ---
class EditUserScreen extends StatefulWidget {
  final String userId;
  final AppUser user;
  const EditUserScreen({super.key, required this.userId, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late Map<String, bool> _roles;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roles = {
      'podiumEnabled': widget.user.podiumEnabled, 'waiterEnabled': widget.user.waiterEnabled,
      'customerEnabled': widget.user.customerEnabled, 'banquetBookingEnabled': widget.user.banquetBookingEnabled,
      'banquetReportsEnabled': widget.user.banquetReportsEnabled, 'queueReportsEnabled': widget.user.queueReportsEnabled,
    };
  }

  Future<void> _updateUser() async {
    setState(() => _isLoading = true);
    final updatedProfile = AppUser(
      username: widget.user.username, email: widget.user.email, branchId: widget.user.branchId,
      podiumEnabled: _roles['podiumEnabled']!, waiterEnabled: _roles['waiterEnabled']!,
      customerEnabled: _roles['customerEnabled']!, banquetBookingEnabled: _roles['banquetBookingEnabled']!,
      banquetReportsEnabled: _roles['banquetReportsEnabled']!, queueReportsEnabled: _roles['queueReportsEnabled']!,
    );
    try {
      await context.read<UserProvider>().updateUser(widget.userId, updatedProfile);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating user: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: Function to handle user deletion ---
  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete ${widget.user.email}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await context.read<UserProvider>().deleteUser(widget.userId);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User profile deleted.'), backgroundColor: Colors.green));
        // Pop back to the user list screen
        Navigator.of(context).pop();
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.user.username}')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ..._roles.keys.map((key) => SwitchListTile(title: Text(key.replaceAll('Enabled', '')), value: _roles[key]!, onChanged: (v) => setState(() => _roles[key] = v))).toList(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _updateUser,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Save Changes'),
          ),
          // --- NEW: Added Divider and Delete Button ---
          const Divider(height: 40, color: Colors.grey),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete User'),
            onPressed: _isLoading ? null : _deleteUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }
}
