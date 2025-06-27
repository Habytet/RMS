import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/customer.dart';
import '../../models/branch.dart'; // Import Branch model for type safety

class AdminDisplayScreen extends StatefulWidget {
  const AdminDisplayScreen({super.key});

  @override
  State<AdminDisplayScreen> createState() => _AdminDisplayScreenState();
}

class _AdminDisplayScreenState extends State<AdminDisplayScreen> {
  String _selectedBranchFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = context.watch<UserProvider>();
    final TokenProvider tokenProvider = context.watch<TokenProvider>();

    final List<Branch> allBranches = userProvider.branches;
    final List<Customer> queue = tokenProvider.queue;
    final bool isLoading = tokenProvider.isLoading;

    final List<Customer> filteredQueue = _selectedBranchFilter == 'all'
        ? queue
        : queue.where((c) => c.branchName == _selectedBranchFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Queue Display'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedBranchFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by Branch',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Branches')),
                ...allBranches
                    .where((branch) => branch.id != 'all')
                    .map((branch) {
                  return DropdownMenuItem(
                    value: branch.id,
                    child: Text(branch.name),
                  );
                }),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedBranchFilter = value;
                  });
                }
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredQueue.isEmpty
                ? const Center(
                child: Text('No customers in the selected queue(s).'))
                : ListView.builder(
              itemCount: filteredQueue.length,
              itemBuilder: (context, index) {
                final customer = filteredQueue[index];

                // --- THIS IS THE FIX ---
                // 1. Get the Branch ID from the customer data.
                final String branchId = customer.branchName ?? '';

                // 2. Look up the Branch Name from the full list of branches.
                // Provides a fallback text if the branch isn't found.
                final branchName = allBranches
                    .firstWhere((branch) => branch.id == branchId,
                    orElse: () => Branch(id: '', name: 'Unknown'))
                    .name;
                // --- END OF FIX ---

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                      '${customer.name} (${customer.pax} Adults, ${customer.children} Kids)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Token: ${customer.token} | Phone: ${customer.phone}',
                    ),
                    trailing: Chip(
                      // 3. Use the resolved branch name here.
                      label: Text(
                        branchName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}