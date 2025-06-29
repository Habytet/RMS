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
    final isLoadingUsers = userProvider.isLoadingUsers;

    if (isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter users based on current user's branch if not admin
    final List<AppUser> filteredUsers;
    if (currentUser != null && !currentUser.isAdmin) {
      filteredUsers = userProvider.users
          .where((user) => user.branchId == currentUser.branchId)
          .toList();
    } else {
      filteredUsers = userProvider.users;
    }

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: filteredUsers.map((user) {
        // Find the document ID for the user to pass to EditUserScreen
        // This is a bit inefficient if `userProvider.users` only provides AppUser objects without their Firestore UIDs
        // A better approach would be to fetch (user, docId) pairs in UserProvider or query Firestore directly here.
        // For now, assuming UserProvider.users contains the full list of AppUser objects which we can find by email.
        // A more robust solution might involve passing the Firebase User UID from `AppUser` model directly.
        // For current implementation, let's assume `userProvider.users` returns AppUser with an accessible Firebase UID or query by email.
        // Since `AppUser` doesn't store UID explicitly, let's try to pass email as a proxy for the document ID, assuming it's the doc ID.
        // REVISIT: The current `UserProvider.users` returns `List<AppUser>` where AppUser *doesn't* contain the Firestore UID.
        // The `ExistingUsersList` needs `doc.id` for `EditUserScreen`.
        // The `UserProvider` should preferably expose a `Map<String, AppUser>` where key is UID or `List<MapEntry<String, AppUser>>`.
        // For simplicity *now*, let's query the specific user document ID using their email. This will add extra reads.
        // A better long-term fix is in UserProvider to expose UID.

        // Temporarily, we'll assume the email IS the docId for existing users
        // This is a dangerous assumption if Firebase UIDs are used as document IDs.
        // Reverting to previous StreamBuilder on `users` collection to get doc.id.
        // This means `ExistingUsersList` does *not* directly use `userProvider.users` for the list.
        // It relies on a direct stream from Firestore, which includes doc.id.
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get(),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink(); // Or a shimmer effect
            }
            if (docSnapshot.hasError ||
                !docSnapshot.hasData ||
                docSnapshot.data!.docs.isEmpty) {
              return const SizedBox
                  .shrink(); // Error or user not found, hide this entry
            }
            final docId = docSnapshot.data!.docs.first.id;
            return Card(
              child: ListTile(
                title: Text(user.username.isEmpty ? user.email : user.username),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.edit, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditUserScreen(userId: docId, user: user),
                    ),
                  );
                },
              ),
            );
          },
        );
      }).toList(),
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
  String? _selectedBranchId;
  bool _isLoading = false;
  Map<String, bool> _roles = {
    'podiumEnabled': false,
    'waiterEnabled': false,
    'customerEnabled': false,
    'banquetBookingEnabled': false,
    'banquetReportsEnabled': false,
    'queueReportsEnabled': false,
    'adminDisplayEnabled': false,
    'banquetSetupEnabled': false,
    'userManagementEnabled': false,
    'menuManagementEnabled': false,
    'branchManagementEnabled': false,
    'canViewOwnTasks': false, // NEW: Task-related permission
    'canSubmitTasks': false, // NEW: Task-related permission
    'canViewStaffTasks': false, // NEW: Task-related permission
    'canCreateTasks': false, // NEW: Task-related permission
    'canEditAssignedTasks': false, // NEW: Task-related permission
    'canReassignTasks': false, // NEW: Task-related permission
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
      username: username,
      email: email,
      branchId: _selectedBranchId!,
      podiumEnabled: _roles['podiumEnabled']!,
      waiterEnabled: _roles['waiterEnabled']!,
      customerEnabled: _roles['customerEnabled']!,
      banquetBookingEnabled: _roles['banquetBookingEnabled']!,
      banquetReportsEnabled: _roles['banquetReportsEnabled']!,
      queueReportsEnabled: _roles['queueReportsEnabled']!,
      adminDisplayEnabled: _roles['adminDisplayEnabled']!,
      banquetSetupEnabled: _roles['banquetSetupEnabled']!,
      userManagementEnabled: _roles['userManagementEnabled']!,
      menuManagementEnabled: _roles['menuManagementEnabled']!,
      branchManagementEnabled: _roles['branchManagementEnabled']!,
      // NEW: Assign task-related permissions
      canSubmitTasks: _roles['canSubmitTasks']!,
      canViewStaffTasks: _roles['canViewStaffTasks']!,
      canCreateTasks: _roles['canCreateTasks']!,
      canEditAssignedTasks: _roles['canEditAssignedTasks']!,
      canReassignTasks: _roles['canReassignTasks']!,
    );
    try {
      await context
          .read<UserProvider>()
          .addUser(email, _passwordController.text.trim(), profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User created successfully!'),
            backgroundColor: Colors.green));
        _formKey.currentState!.reset();
        _emailController.clear();
        _passwordController.clear();
        setState(() {
          _selectedBranchId = null;
          _roles.updateAll((key, value) => false); // Reset all toggles
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Watch the provider to get branches AND the loading state
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isLoadingBranches = userProvider.isLoadingBranches;

    final List<DropdownMenuItem<String>> branchItems = [
      const DropdownMenuItem(
          value: 'all', child: Text('All Branches (Corporate)')),
      ...branches.where((branch) => branch.id != 'all').map((branch) =>
          DropdownMenuItem(value: branch.id, child: Text(branch.name))),
    ];

    // --- NEW: Group permissions for better UI ---
    final List<Map<String, dynamic>> permissionGroups = [
      {
        'title': 'Queue & Podium',
        'keys': [
          'podiumEnabled',
          'waiterEnabled',
          'customerEnabled',
          'queueReportsEnabled',
          'adminDisplayEnabled'
        ],
      },
      {
        'title': 'Banquet',
        'keys': [
          'banquetBookingEnabled',
          'banquetReportsEnabled',
          'banquetSetupEnabled'
        ],
      },
      {
        'title': 'Task Management', // NEW: Group for Tasks
        'keys': [
          'canViewOwnTasks',
          'canSubmitTasks',
          'canViewStaffTasks',
          'canCreateTasks',
          'canEditAssignedTasks',
          'canReassignTasks',
        ],
      },
      {
        'title': 'Admin',
        'keys': [
          'userManagementEnabled',
          'menuManagementEnabled',
          'branchManagementEnabled'
        ],
      },
    ];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => v!.isEmpty ? 'Please enter an email' : null),
          TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => v!.length < 6
                  ? 'Password must be at least 6 characters'
                  : null),
          const SizedBox(height: 16),

          // FIX: Show a loading indicator if branches are loading, otherwise show the dropdown
          if (isLoadingBranches)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              hint: const Text('Select Branch'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: branchItems,
              onChanged: (value) => setState(() => _selectedBranchId = value),
              validator: (value) =>
                  value == null ? 'Please select a branch' : null,
            ),

          const SizedBox(height: 20),
          const Text('User Roles & Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          // --- NEW: Grouped switches for permissions ---
          ...permissionGroups.expand((group) => [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(group['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...group['keys'].map<Widget>((key) => SwitchListTile(
                      title: Text(key
                          .replaceAll('Enabled', '')
                          .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
                              (m) => '${m[1]} ${m[2]}')
                          .replaceAll('adminDisplay', 'Admin Display')
                          .replaceAll('banquetSetup', 'Banquet Setup')
                          .replaceAll('userManagement', 'User Management')
                          .replaceAll('menuManagement', 'Menu Management')
                          .replaceAll('branchManagement', 'Branch Management')
                          .replaceAll('banquetBooking', 'Banquet Booking')
                          .replaceAll('banquetReports', 'Banquet Reports')
                          .replaceAll('queueReports', 'Queue Reports')
                          .replaceAll('podium', 'Podium')
                          .replaceAll('waiter', 'Waiter')
                          .replaceAll('customer', 'Customer')
                          // NEW: Task-related permission display names
                          .replaceAll('canViewOwnTasks',
                              'Can be Assigned Tasks (My Tasks)')
                          .replaceAll('canSubmitTasks', 'Can Submit Tasks')
                          .replaceAll(
                              'canViewStaffTasks', 'Can View Staff Tasks')
                          .replaceAll('canCreateTasks', 'Can Create Tasks')
                          .replaceAll(
                              'canEditAssignedTasks', 'Can Edit Assigned Tasks')
                          .replaceAll(
                              'canReassignTasks', 'Can Reassign Tasks')),
                      value: _roles[key]!,
                      onChanged: (v) => setState(() => _roles[key] = v),
                    )),
              ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _createUser,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Create User'),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET: SCREEN FOR EDITING AN EXISTING USER ---
class EditUserScreen extends StatefulWidget {
  final String userId;
  final AppUser user;
  const EditUserScreen({super.key, required this.userId, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late Map<String, bool> _roles;
  late String _selectedBranchId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.user.branchId;
    _roles = {
      'podiumEnabled': widget.user.podiumEnabled,
      'waiterEnabled': widget.user.waiterEnabled,
      'customerEnabled': widget.user.customerEnabled,
      'banquetBookingEnabled': widget.user.banquetBookingEnabled,
      'banquetReportsEnabled': widget.user.banquetReportsEnabled,
      'queueReportsEnabled': widget.user.queueReportsEnabled,
      'adminDisplayEnabled': widget.user.adminDisplayEnabled,
      'banquetSetupEnabled': widget.user.banquetSetupEnabled,
      'userManagementEnabled': widget.user.userManagementEnabled,
      'menuManagementEnabled': widget.user.menuManagementEnabled,
      'branchManagementEnabled': widget.user.branchManagementEnabled,
      // NEW: Initialize task-related permissions from existing user
      'canViewOwnTasks': widget.user.canViewOwnTasks,
      'canSubmitTasks': widget.user.canSubmitTasks,
      'canViewStaffTasks': widget.user.canViewStaffTasks,
      'canCreateTasks': widget.user.canCreateTasks,
      'canEditAssignedTasks': widget.user.canEditAssignedTasks,
      'canReassignTasks': widget.user.canReassignTasks,
    };
  }

  Future<void> _updateUser() async {
    setState(() => _isLoading = true);
    final updatedProfile = AppUser(
      username: widget.user.username,
      email: widget.user.email,
      branchId: _selectedBranchId,
      podiumEnabled: _roles['podiumEnabled']!,
      waiterEnabled: _roles['waiterEnabled']!,
      customerEnabled: _roles['customerEnabled']!,
      banquetBookingEnabled: _roles['banquetBookingEnabled']!,
      banquetReportsEnabled: _roles['banquetReportsEnabled']!,
      queueReportsEnabled: _roles['queueReportsEnabled']!,
      adminDisplayEnabled: _roles['adminDisplayEnabled']!,
      banquetSetupEnabled: _roles['banquetSetupEnabled']!,
      userManagementEnabled: _roles['userManagementEnabled']!,
      menuManagementEnabled: _roles['menuManagementEnabled']!,
      branchManagementEnabled: _roles['branchManagementEnabled']!,
      // NEW: Update task-related permissions
      canSubmitTasks: _roles['canSubmitTasks']!,
      canViewStaffTasks: _roles['canViewStaffTasks']!,
      canCreateTasks: _roles['canCreateTasks']!,
      canEditAssignedTasks: _roles['canEditAssignedTasks']!,
      canReassignTasks: _roles['canReassignTasks']!,
    );
    try {
      await context
          .read<UserProvider>()
          .updateUser(widget.userId, updatedProfile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User updated successfully!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
            'Are you sure you want to delete ${widget.user.email}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red)),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await context.read<UserProvider>().deleteUser(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User profile deleted.'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Watch the provider to get branches AND the loading state
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isLoadingBranches = userProvider.isLoadingBranches;

    final List<DropdownMenuItem<String>> branchItems = [
      const DropdownMenuItem(
          value: 'all', child: Text('All Branches (Corporate)')),
      ...branches.where((branch) => branch.id != 'all').map((branch) =>
          DropdownMenuItem(value: branch.id, child: Text(branch.name))),
    ];

    // --- NEW: Group permissions for better UI ---
    final List<Map<String, dynamic>> permissionGroups = [
      {
        'title': 'Queue & Podium',
        'keys': [
          'podiumEnabled',
          'waiterEnabled',
          'customerEnabled',
          'queueReportsEnabled',
          'adminDisplayEnabled'
        ],
      },
      {
        'title': 'Banquet',
        'keys': [
          'banquetBookingEnabled',
          'banquetReportsEnabled',
          'banquetSetupEnabled'
        ],
      },
      {
        'title': 'Task Management', // NEW: Group for Tasks
        'keys': [
          'canViewOwnTasks',
          'canSubmitTasks',
          'canViewStaffTasks',
          'canCreateTasks',
          'canEditAssignedTasks',
          'canReassignTasks',
        ],
      },
      {
        'title': 'Admin',
        'keys': [
          'userManagementEnabled',
          'menuManagementEnabled',
          'branchManagementEnabled'
        ],
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.user.username}')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Assign to Branch',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // FIX: Show a loading indicator if branches are loading, otherwise show the dropdown
          if (isLoadingBranches)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              items: branchItems,
              onChanged: (value) {
                if (value != null) setState(() => _selectedBranchId = value);
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

          const SizedBox(height: 24),
          const Text('Permissions',
              style: TextStyle(fontWeight: FontWeight.bold)),
          // --- NEW: Grouped switches for permissions ---
          ...permissionGroups.expand((group) => [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(group['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...group['keys'].map<Widget>((key) => SwitchListTile(
                      title: Text(key
                          .replaceAll('Enabled', '')
                          .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
                              (m) => '${m[1]} ${m[2]}')
                          .replaceAll('adminDisplay', 'Admin Display')
                          .replaceAll('banquetSetup', 'Banquet Setup')
                          .replaceAll('userManagement', 'User Management')
                          .replaceAll('menuManagement', 'Menu Management')
                          .replaceAll('branchManagement', 'Branch Management')
                          .replaceAll('banquetBooking', 'Banquet Booking')
                          .replaceAll('banquetReports', 'Banquet Reports')
                          .replaceAll('queueReports', 'Queue Reports')
                          .replaceAll('podium', 'Podium')
                          .replaceAll('waiter', 'Waiter')
                          .replaceAll('customer', 'Customer')
                          // NEW: Task-related permission display names
                          .replaceAll('canViewOwnTasks',
                              'Can be Assigned Tasks (My Tasks)')
                          .replaceAll('canSubmitTasks', 'Can Submit Tasks')
                          .replaceAll(
                              'canViewStaffTasks', 'Can View Staff Tasks')
                          .replaceAll('canCreateTasks', 'Can Create Tasks')
                          .replaceAll(
                              'canEditAssignedTasks', 'Can Edit Assigned Tasks')
                          .replaceAll(
                              'canReassignTasks', 'Can Reassign Tasks')),
                      value: _roles[key]!,
                      onChanged: (v) => setState(() => _roles[key] = v),
                    )),
              ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _updateUser,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Save Changes'),
          ),
          const Divider(height: 40, color: Colors.grey),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete User'),
            onPressed: _isLoading ? null : _deleteUser,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }
}
