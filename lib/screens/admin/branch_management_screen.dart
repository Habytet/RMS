import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// FIX 1: Explicitly import the Branch model.
// The UserProvider now uses this model, so the screen needs to know about it.
import '../../models/branch.dart';
import '../../providers/user_provider.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final _branchNameController = TextEditingController();

  @override
  void dispose() {
    _branchNameController.dispose();
    super.dispose();
  }

  // FIX 2: This function now uses the UserProvider to add a branch.
  // This respects the app's architecture and the Firestore security rules.
  void _addBranch() {
    _branchNameController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Branch'),
        content: TextField(
          controller: _branchNameController,
          decoration: const InputDecoration(labelText: 'Branch Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _branchNameController.text.trim();
              if (name.isNotEmpty) {
                // Use the provider to handle the logic
                await context.read<UserProvider>().addBranch(name);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editBranch(Branch branch) {
    _branchNameController.text = branch.name;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Branch Name'),
        content: TextField(
          controller: _branchNameController,
          decoration: const InputDecoration(labelText: 'Branch Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = _branchNameController.text.trim();
              context.read<UserProvider>().updateBranch(branch.id, newName);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteBranch(Branch branch) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: Text('Are you sure you want to delete the "${branch.name}" branch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<UserProvider>().deleteBranch(branch.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isLoading = userProvider.isLoadingBranches;

    return Scaffold(
      appBar: AppBar(title: const Text('Branch Management')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : branches.isEmpty
          ? const Center(child: Text('No branches found. Tap + to add one.'))
          : ListView.builder(
        itemCount: branches.length,
        itemBuilder: (context, index) {
          final branch = branches[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(branch.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editBranch(branch),
                    tooltip: 'Edit Branch',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBranch(branch),
                    tooltip: 'Delete Branch',
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBranch,
        tooltip: 'Add Branch',
        child: const Icon(Icons.add),
      ),
    );
  }
}