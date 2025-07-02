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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'User Management',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.people),
                text: 'Existing Users',
              ),
              Tab(
                icon: Icon(Icons.person_add),
                text: 'Create New User',
              ),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade50,
                Colors.white,
              ],
            ),
          ),
          child: const TabBarView(
            children: [
              ExistingUsersList(),
              CreateUserForm(),
            ],
          ),
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
        ),
      );
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first user in the "Create New User" tab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.red.shade400, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Users',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Users List
        ...filteredUsers.map((user) {
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: user.email)
                .limit(1)
                .get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 16,
                              child: LinearProgressIndicator(),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (docSnapshot.hasError ||
                  !docSnapshot.hasData ||
                  docSnapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final docId = docSnapshot.data!.docs.first.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Icon(
                      Icons.person,
                      color: Colors.red.shade600,
                    ),
                  ),
                  title: Text(
                    user.username.isEmpty ? user.email : user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getBranchColor(user.branchId),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getBranchName(user.branchId, userProvider.branches),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditUserScreen(userId: docId, user: user),
                      ),
                    );
                  },
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  Color _getBranchColor(String branchId) {
    switch (branchId) {
      case 'all':
        return Colors.purple.shade600;
      case 'branch1':
        return Colors.blue.shade600;
      case 'branch2':
        return Colors.green.shade600;
      case 'branch3':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getBranchName(String branchId, List<dynamic> branches) {
    if (branchId == 'all') return 'Corporate';
    try {
      final branch = branches.firstWhere(
        (b) => b.id == branchId,
      );
      return branch.name ?? 'Unknown Branch';
    } catch (e) {
      return 'Unknown Branch';
    }
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
    'todaysViewEnabled': false,
    'banquetSetupEnabled': false,
    'chefDisplayEnabled': false,
    'userManagementEnabled': false,
    'menuManagementEnabled': false,
    'branchManagementEnabled': false,
    'canViewOwnTasks': false,
    'canSubmitTasks': false,
    'canViewStaffTasks': false,
    'canCreateTasks': false,
    'canEditAssignedTasks': false,
    'canReassignTasks': false,
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
      todaysViewEnabled: _roles['todaysViewEnabled']!,
      banquetSetupEnabled: _roles['banquetSetupEnabled']!,
      chefDisplayEnabled: _roles['chefDisplayEnabled']!,
      userManagementEnabled: _roles['userManagementEnabled']!,
      menuManagementEnabled: _roles['menuManagementEnabled']!,
      branchManagementEnabled: _roles['branchManagementEnabled']!,
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
          _roles.updateAll((key, value) => false);
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
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isLoadingBranches = userProvider.isLoadingBranches;

    final List<DropdownMenuItem<String>> branchItems = [
      const DropdownMenuItem(
          value: 'all', child: Text('All Branches (Corporate)')),
      ...branches.where((branch) => branch.id != 'all').map((branch) =>
          DropdownMenuItem(value: branch.id, child: Text(branch.name))),
    ];

    final List<Map<String, dynamic>> permissionGroups = [
      {
        'title': 'Queue & Podium',
        'icon': Icons.queue,
        'color': Colors.blue,
        'keys': [
          'podiumEnabled',
          'waiterEnabled',
          'customerEnabled',
          'queueReportsEnabled',
          'adminDisplayEnabled',
          'todaysViewEnabled',
        ],
      },
      {
        'title': 'Banquet',
        'icon': Icons.event,
        'color': Colors.orange,
        'keys': [
          'banquetBookingEnabled',
          'banquetReportsEnabled',
          'banquetSetupEnabled',
          'chefDisplayEnabled',
        ],
      },
      {
        'title': 'Task Management',
        'icon': Icons.assignment,
        'color': Colors.green,
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
        'icon': Icons.admin_panel_settings,
        'color': Colors.purple,
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
          // User Information Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add,
                        color: Colors.red.shade400, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.red.shade400, width: 2),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Please enter an email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.red.shade400, width: 2),
                    ),
                  ),
                  validator: (v) => v!.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                if (isLoadingBranches)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedBranchId,
                    hint: const Text('Select Branch'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.red.shade400, width: 2),
                      ),
                    ),
                    items: branchItems,
                    onChanged: (value) =>
                        setState(() => _selectedBranchId = value),
                    validator: (value) =>
                        value == null ? 'Please select a branch' : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Permissions Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.red.shade400, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'User Roles & Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...permissionGroups
                    .map((group) => _buildPermissionGroup(group)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Create Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGroup(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: group['color'].withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: group['color'].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group['icon'],
                color: group['color'],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                group['title'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: group['color'],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group['keys'].map<Widget>((key) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: Text(
                    _getPermissionDisplayName(key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _roles[key]!,
                  onChanged: (v) => setState(() => _roles[key] = v),
                  activeColor: group['color'],
                ),
              )),
        ],
      ),
    );
  }

  String _getPermissionDisplayName(String key) {
    return key
        .replaceAll('Enabled', '')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
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
        .replaceAll('canViewOwnTasks', 'Can be Assigned Tasks (My Tasks)')
        .replaceAll('canSubmitTasks', 'Can Submit Tasks')
        .replaceAll('canViewStaffTasks', 'Can View Staff Tasks')
        .replaceAll('canCreateTasks', 'Can Create Tasks')
        .replaceAll('canEditAssignedTasks', 'Can Edit Assigned Tasks')
        .replaceAll('canReassignTasks', 'Can Reassign Tasks');
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
      'todaysViewEnabled': widget.user.todaysViewEnabled,
      'banquetSetupEnabled': widget.user.banquetSetupEnabled,
      'chefDisplayEnabled': widget.user.chefDisplayEnabled,
      'userManagementEnabled': widget.user.userManagementEnabled,
      'menuManagementEnabled': widget.user.menuManagementEnabled,
      'branchManagementEnabled': widget.user.branchManagementEnabled,
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
      todaysViewEnabled: _roles['todaysViewEnabled']!,
      banquetSetupEnabled: _roles['banquetSetupEnabled']!,
      chefDisplayEnabled: _roles['chefDisplayEnabled']!,
      userManagementEnabled: _roles['userManagementEnabled']!,
      menuManagementEnabled: _roles['menuManagementEnabled']!,
      branchManagementEnabled: _roles['branchManagementEnabled']!,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isLoadingBranches = userProvider.isLoadingBranches;

    final List<DropdownMenuItem<String>> branchItems = [
      const DropdownMenuItem(
          value: 'all', child: Text('All Branches (Corporate)')),
      ...branches.where((branch) => branch.id != 'all').map((branch) =>
          DropdownMenuItem(value: branch.id, child: Text(branch.name))),
    ];

    final List<Map<String, dynamic>> permissionGroups = [
      {
        'title': 'Queue & Podium',
        'icon': Icons.queue,
        'color': Colors.blue,
        'keys': [
          'podiumEnabled',
          'waiterEnabled',
          'customerEnabled',
          'queueReportsEnabled',
          'adminDisplayEnabled',
          'todaysViewEnabled',
        ],
      },
      {
        'title': 'Banquet',
        'icon': Icons.event,
        'color': Colors.orange,
        'keys': [
          'banquetBookingEnabled',
          'banquetReportsEnabled',
          'banquetSetupEnabled',
          'chefDisplayEnabled',
        ],
      },
      {
        'title': 'Task Management',
        'icon': Icons.assignment,
        'color': Colors.green,
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
        'icon': Icons.admin_panel_settings,
        'color': Colors.purple,
        'keys': [
          'userManagementEnabled',
          'menuManagementEnabled',
          'branchManagementEnabled'
        ],
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Edit ${widget.user.username.isEmpty ? widget.user.email : widget.user.username}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Branch Assignment Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business,
                          color: Colors.red.shade400, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Branch Assignment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingBranches)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedBranchId,
                      items: branchItems,
                      onChanged: (value) {
                        if (value != null)
                          setState(() => _selectedBranchId = value);
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.red.shade400, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Permissions Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security,
                          color: Colors.red.shade400, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Permissions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...permissionGroups
                      .map((group) => _buildPermissionGroup(group)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text(
                  'Delete User',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _isLoading ? null : _deleteUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionGroup(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: group['color'].withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: group['color'].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group['icon'],
                color: group['color'],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                group['title'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: group['color'],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group['keys'].map<Widget>((key) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: Text(
                    _getPermissionDisplayName(key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _roles[key]!,
                  onChanged: (v) => setState(() => _roles[key] = v),
                  activeColor: group['color'],
                ),
              )),
        ],
      ),
    );
  }

  String _getPermissionDisplayName(String key) {
    return key
        .replaceAll('Enabled', '')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
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
        .replaceAll('canViewOwnTasks', 'Can be Assigned Tasks (My Tasks)')
        .replaceAll('canSubmitTasks', 'Can Submit Tasks')
        .replaceAll('canViewStaffTasks', 'Can View Staff Tasks')
        .replaceAll('canCreateTasks', 'Can Create Tasks')
        .replaceAll('canEditAssignedTasks', 'Can Edit Assigned Tasks')
        .replaceAll('canReassignTasks', 'Can Reassign Tasks');
  }
}
